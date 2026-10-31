"""500/1000 synthetic dossiers: service/PG volume, not a public HTTP load test."""
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from datetime import timedelta
import os
from pathlib import Path
import secrets
import tempfile
import time
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, text
from sqlalchemy.engine import make_url
from sqlalchemy.orm import Session

import app.models.base
from app.api.deps import get_current_active_validated_user
from app.api.routes import recruitment
from app.core.config import settings
from app.core.time import utc_now
from app.db.database import Base, get_db
from app.models.email_delivery import EmailDelivery
from app.models.recruitment import Application, RecruitmentCampaign
from app.models.role import Role, UserRole
from app.models.stored_file import StoredFile
from app.models.user import User
from app.schemas.recruitment import ApplicationCreate
from app.services import file_storage_service
from app.services.recruitment_questionnaire import effective_questions, questionnaire_version

PDF = b'%PDF-1.4\n' + b'owned synthetic fixture\n' * 350 + b'%%EOF\n'

def guarded_url(value):
    url = make_url(value)
    if (url.get_backend_name() != 'postgresql' or url.host not in {'127.0.0.1', 'localhost', '::1'}
            or not (url.database or '').startswith('enactspace_pr2b_test_')):
        raise RuntimeError('Disposable_local_PostgreSQL_required')
    return url


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int((len(ordered) - 1) * fraction))]


@contextmanager
def isolated_schema(url):
    admin = create_engine(url)
    schema = 'recruitment_volume_' + secrets.token_hex(12)
    engine = None
    try:
        with admin.begin() as connection:
            connection.execute(text(f'CREATE SCHEMA "{schema}"'))
        engine = create_engine(url.update_query_dict({'options': '-csearch_path=' + schema}),
                               pool_size=8, max_overflow=0)
        Base.metadata.create_all(engine)
        yield engine
    finally:
        if engine is not None:
            engine.dispose()
        with admin.begin() as connection:
            connection.execute(text(f'DROP SCHEMA IF EXISTS "{schema}" CASCADE'))
        admin.dispose()


def run(volumes=(500, 1000)):
    url = guarded_url(os.environ.get('TEST_DATABASE_URL', ''))
    if any(n not in (500, 1000) for n in volumes):
        raise RuntimeError('Approved_rehearsal_volumes_only')
    results = []
    with isolated_schema(url) as engine, tempfile.TemporaryDirectory(prefix='owned-recruitment-volume-') as directory:
        with patch.object(file_storage_service, 'UPLOAD_ROOT', Path(directory)), \
             patch.object(settings, 'EMAIL_ENABLED', True), patch.object(settings, 'PUSH_ENABLED', False), \
             patch('smtplib.SMTP', side_effect=RuntimeError('Real_SMTP_forbidden_in_rehearsal')):
            with Session(engine, expire_on_commit=False) as db:
                role = Role(name='administrateur')
                db.add(role)
                db.flush()
                for i in range(4):
                    user = User(first_name='Synthetic', last_name=f'Recruiter {i}',
                                email=f'rehearsal-recruiter-{i}@example.org', password_hash='unused',
                                is_active=True, email_verified=True, status='active')
                    db.add(user)
                    db.flush()
                    db.add(UserRole(user_id=user.id, role_id=role.id))
                    if i == 0:
                        actor = user
                db.commit()
            for count in volumes:
                with Session(engine) as db:
                    campaign = RecruitmentCampaign(title=f'Synthetic rehearsal {count}', is_active=True,
                        start_date=utc_now().date() - timedelta(days=1), end_date=utc_now().date() + timedelta(days=1))
                    db.add(campaign)
                    db.commit()
                    campaign_id = campaign.id

                def submit(index):
                    started = time.monotonic()
                    payload = ApplicationCreate(campaign_id=campaign_id,
                        first_name='Synthetic', last_name=f'Candidate {index}', gender='non_precise',
                        email=f'rehearsal-{count}-{index}@example.org', phone='+221770000000',
                        department='Génie Électrique', study_level='DIC1', class_name='2025-2026',
                        questionnaire_version=questionnaire_version(None),
                        questionnaire_answers={q['id']: 'Synthetic rehearsal response. ' * 8 for q in effective_questions(None)})
                    with Session(engine) as db:
                        body = recruitment.create_application(payload, db, attachments={'cv_url': ('owned-cv.pdf', PDF)})
                        assert body['tracking_code'] and body['cv_url']
                    return time.monotonic() - started

                started = time.monotonic()
                with ThreadPoolExecutor(max_workers=8) as pool:
                    timings = list(pool.map(submit, range(count)))
                elapsed = time.monotonic() - started
                with Session(engine) as db:
                    actual = db.query(Application).filter_by(campaign_id=campaign_id).count()
                    tracking = db.query(func.count(func.distinct(Application.tracking_code))).filter(Application.campaign_id == campaign_id).scalar()
                    files = db.query(StoredFile).join(Application, StoredFile.entity_id == Application.id).filter(Application.campaign_id == campaign_id).count()
                    receipts = db.query(EmailDelivery).filter(EmailDelivery.dedupe_key.like('recruitment-submission:%')).count()
                    assert actual == tracking == files == count
                    assert receipts == sum(volumes[:len(results) + 1])

                app = FastAPI()
                app.include_router(recruitment.router, prefix='/api')

                def db_session():
                    with Session(engine) as db:
                        yield db

                app.dependency_overrides[get_db] = db_session
                app.dependency_overrides[get_current_active_validated_user] = lambda: actor
                with TestClient(app) as client:
                    tick = time.monotonic()
                    listing = client.get('/api/recruitment/applications', params={'campaign_id': str(campaign_id)})
                    listing_seconds = time.monotonic() - tick
                    assert listing.status_code == 200 and len(listing.json()) == count
                    tick = time.monotonic()
                    export = client.get('/api/recruitment/applications/export.csv', params={'campaign_id': str(campaign_id)})
                    export_seconds = time.monotonic() - tick
                    assert export.status_code == 200
                results.append({'dossiers': count, 'writers': 8, 'synthetic_cv_bytes': len(PDF),
                    'dossiers_and_tracking_and_files_match': True, 'elapsed_seconds': round(elapsed, 3),
                    'submission_p50_seconds': round(percentile(timings, .5), 3),
                    'submission_p95_seconds': round(percentile(timings, .95), 3),
                    'list_seconds': round(listing_seconds, 3), 'list_bytes': len(listing.content),
                    'export_seconds': round(export_seconds, 3), 'export_bytes': len(export.content)})
    return {'scope': 'application_service_pg_volume_and_in_process_http_reads',
            'production_database_access': False, 'real_email_sent': False,
            'public_proxy_load_tested': False, 'maximum_size_files_load_tested': False,
            'owned_schema_and_files_removed': True, 'measurements': results}
