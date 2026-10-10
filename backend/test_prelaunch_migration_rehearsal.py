"""Rehearse 0025->0031, downgrade and replay using synthetic rows only."""
import secrets as _enactspace_fixture_secrets
_ENACTSPACE_EPHEMERAL_PASSWORD_1 = 'Aa9!' + _enactspace_fixture_secrets.token_hex(24)

import os,json,hashlib,subprocess,sys,uuid
from datetime import datetime,timedelta
from sqlalchemy import create_engine,MetaData,inspect,select,text
BASE="20261006_0025";HEAD="20261007_0031"
def main():
    url=os.environ["DATABASE_URL"]
    assert "enactspace_pr2b_test_" in url and "@127.0.0.1/" in url
    engine=create_engine(url)
    results={}
    def migrate(target,direction="upgrade"):
     run=subprocess.run([sys.executable,"-m","alembic",direction,target],capture_output=True,text=True)
     if run.returncode:
      print(run.stdout+run.stderr,flush=True)
      raise RuntimeError("Migration command failed: "+direction+" "+target)
    def snapshot(column_map):
     hashes={}
     with engine.connect() as conn:
      for name,columns in column_map.items():
       rows=conn.execute(text('SELECT '+",".join('"'+c+'"' for c in columns)+' FROM "'+name+'"')).all()
       records=sorted(json.dumps(list(row),default=str,sort_keys=True,ensure_ascii=False) for row in rows)
       hashes[name]=hashlib.sha256("\n".join(records).encode()).hexdigest()
     return hashes
    # The restored production schema has no row data or Alembic version contents.
    with engine.begin() as conn:conn.execute(text("INSERT INTO alembic_version(version_num) VALUES (:version)"),{"version":BASE})
    metadata=MetaData();metadata.reflect(engine)
    now=datetime(2026,10,7,17,30);member=uuid.uuid4();otp=uuid.uuid4();mm=uuid.uuid4()
    def insert(table,**values):
     with engine.begin() as conn:conn.execute(metadata.tables[table].insert().values(**values))
    insert("users",id=member,first_name="Synthetic",last_name="Migration",email="migration@example.test",username="synthetic_migration",
     password_hash="unused",profile_type="enacteur",status="active",email_verified=True,is_active=True,
     created_at=now,updated_at=now,enactus_join_year=2020)
    insert("password_reset_otps",id=otp,user_id=member,otp_hash="synthetic-otp-hash",expires_at=now+timedelta(minutes=10),created_at=now)
    insert("mobile_money_transactions",id=mm,member_id=member,provider="synthetic",
     idempotency_key="synthetic-migration-idempotency",provider_invoice_token="synthetic-invoice",
     amount=1000,currency="XOF",status="pending",created_at=now,updated_at=now,
     metadata_json={"synthetic":True,"message":"Données de test uniquement"})
    insert("auth_sessions",id=uuid.uuid4(),user_id=member,refresh_token_hash="a"*64,
     expires_at=now+timedelta(days=1),created_at=now,platform="android")
    unused=uuid.uuid4();bootstrap=uuid.uuid4();admin_role=uuid.uuid4()
    for uid,mail,username in ((unused,"unused@example.com","synthetic.unused"),(bootstrap,"bootstrap@example.com","synthetic.bootstrap")):
     insert("users",id=uid,first_name="Synthetic",last_name="FirstAccess",email=mail,username=username,
      password_hash="unused",profile_type="enacteur",status="active",email_verified=True,is_active=True,
      created_at=now,updated_at=now)
    insert("roles",id=admin_role,name="administrateur",created_at=now)
    insert("user_roles",id=uuid.uuid4(),user_id=bootstrap,role_id=admin_role,created_at=now)
    ticket_id=uuid.uuid4();message_id=uuid.uuid4();feedback_id=uuid.uuid4()
    insert("support_tickets",id=ticket_id,user_id=member,subject="Synthetic help",category="technical",
     status="open",priority="normal",created_at=now,updated_at=now)
    insert("support_ticket_messages",id=message_id,ticket_id=ticket_id,author_id=member,
     message="Synthetic message",created_at=now)
    insert("product_feedback",id=feedback_id,user_id=member,category="idea",message="Synthetic suggestion",
     status="new",created_at=now,updated_at=now)
    columns={name:[col["name"] for col in inspect(engine).get_columns(name)]
     for name in inspect(engine).get_table_names() if name!="alembic_version"}
    before=snapshot(columns)
    migrate(HEAD)
    assert snapshot(columns)==before
    with engine.connect() as conn:
     assert conn.execute(text("SELECT failed_attempts FROM password_reset_otps")).scalar_one()==0
     assert conn.execute(text("SELECT last_verification_attempt_at FROM mobile_money_transactions")).scalar_one() is None
     assert conn.execute(text("SELECT version_num FROM alembic_version")).scalar_one()==HEAD
     assert conn.execute(text("SELECT COUNT(*) FROM security_rate_limits")).scalar_one()==0
    with engine.connect() as conn:
     signed=conn.execute(text("SELECT credential_setup_required,onboarding_required FROM users WHERE id=:id"),{"id":member}).one()
     waiting=conn.execute(text("SELECT credential_setup_required,onboarding_required FROM users WHERE id=:id"),{"id":unused}).one()
     admin=conn.execute(text("SELECT credential_setup_required,onboarding_required FROM users WHERE id=:id"),{"id":bootstrap}).one()
     assert tuple(signed)==(False,True)
     assert tuple(waiting)==(True,True)
     assert tuple(admin)==(False,False)
     assert inspect(engine).has_table("activation_challenges")
    results["existing_account_activation_backfill"]=True
    results["upgrade_preserves_all_baseline_tables"]=True
    # Current ORM can read upgraded rows and use the new fields.
    import app.models.base
    from sqlalchemy.orm import Session
    from app.models.user import User,PasswordResetOtp
    from app.models.mobile_money import MobileMoneyTransaction
    from app.models.security_rate_limit import SecurityRateLimit
    with Session(engine) as db:
     assert db.get(PasswordResetOtp,otp).failed_attempts==0
     assert db.get(MobileMoneyTransaction,mm).last_verification_attempt_at is None
     completed_user=db.get(User,unused)
     completed_user.credential_setup_required=False
     completed_user.onboarding_required=False
     completed_user.onboarding_completed_at=now
     db.get(PasswordResetOtp,otp).failed_attempts=3
     db.get(MobileMoneyTransaction,mm).last_verification_attempt_at=now
     db.add(SecurityRateLimit(key="b"*64,count=2,expires_at=now+timedelta(minutes=2)))
     db.commit()
    results["orm_reads_and_writes_new_fields"]=True
    from app.models.product_services import SupportTicket,SupportTicketMessage,ProductFeedback
    from sqlalchemy.exc import IntegrityError
    help_key=uuid.uuid4()
    with Session(engine) as db:
     for model,identity in ((SupportTicket,ticket_id),(SupportTicketMessage,message_id),(ProductFeedback,feedback_id)):
      row=db.get(model,identity)
      assert row.client_request_id is None and row.submission_hash is None
      row.client_request_id=help_key;row.submission_hash="c"*64
     db.get(ProductFeedback,feedback_id).public_reply="Synthetic public response"
     db.commit()
    for table,author in (("support_tickets","user_id"),("support_ticket_messages","author_id"),("product_feedback","user_id")):
     metadata31=MetaData();metadata31.reflect(engine)
     model=metadata31.tables[table]
     with engine.connect() as conn:baseline=dict(conn.execute(select(model).where(model.c.id=={"support_tickets":ticket_id,"support_ticket_messages":message_id,"product_feedback":feedback_id}[table])).mappings().one())
     baseline["id"]=uuid.uuid4()
     try:
      with engine.begin() as conn:conn.execute(model.insert().values(**baseline))
     except IntegrityError:pass
     else:raise AssertionError("Duplicate client request accepted: "+table)
    results["help_client_request_uniqueness_enforced"]=3
    def help_saved():
     with engine.connect() as conn:
      row=conn.execute(text("SELECT client_request_id,submission_hash,public_reply FROM product_feedback WHERE id=:id"),{"id":feedback_id}).one()
      assert tuple(row)==(help_key,"c"*64,"Synthetic public response")
    help_saved()
    results["help_followup_reads_writes_and_privacy_fields"]=True
    # Constraints must be enforced by PostgreSQL, including writes outside the ORM.
    for statement in ("UPDATE password_reset_otps SET failed_attempts=6",
                      "UPDATE password_reset_otps SET failed_attempts=-1",
                      "UPDATE security_rate_limits SET count=0"):
     try:
      with engine.begin() as conn:conn.execute(text(statement))
     except Exception as exc:
      from sqlalchemy.exc import IntegrityError
      assert isinstance(exc,IntegrityError),type(exc).__name__
     else:raise AssertionError("Invalid value accepted")
    results["new_constraints_enforced"]=3
    before=snapshot(columns)  # Include legitimate ORM timestamp changes before testing downgrade.
    # Failure injection rolls back the whole PostgreSQL migration transaction.
    from alembic.migration import MigrationContext
    from alembic.operations import Operations
    import importlib.util
    migrate(BASE,"downgrade")
    assert snapshot(columns)==before
    assert not inspect(engine).has_table("security_rate_limits")
    assert "failed_attempts" not in {x["name"] for x in inspect(engine).get_columns("password_reset_otps")}
    assert "last_verification_attempt_at" not in {x["name"] for x in inspect(engine).get_columns("mobile_money_transactions")}
    help_saved()
    results["help_followup_survives_rollback"]=True
    results["downgrade_preserves_baseline_data"]=True
    spec=importlib.util.spec_from_file_location("migration26","alembic/versions/20261007_0026_password_reset_attempts.py")
    revision=importlib.util.module_from_spec(spec);spec.loader.exec_module(revision)
    try:
     with engine.begin() as conn:
      with Operations.context(MigrationContext.configure(conn)):revision.upgrade()
      raise RuntimeError("synthetic injected failure")
    except RuntimeError as exc:assert str(exc)=="synthetic injected failure"
    assert snapshot(columns)==before
    assert "failed_attempts" not in {x["name"] for x in inspect(engine).get_columns("password_reset_otps")}
    results["failed_transaction_rolls_back"]=True
    migrate(HEAD)
    assert snapshot(columns)==before
    with engine.connect() as conn:
     completed=conn.execute(text("SELECT credential_setup_required,onboarding_required,onboarding_completed_at FROM users WHERE id=:id"),{"id":unused}).one()
     assert tuple(completed)==(False,False,now)
    results["completed_onboarding_survives_rollback_and_replay"]=True
    help_saved()
    results["help_followup_survives_replay"]=True
    results["reupgrade_preserves_baseline_data"]=True
    migrate(HEAD)
    assert snapshot(columns)==before
    results["repeat_upgrade_noop"]=True
    results["baseline_tables_checked"]=len(columns)
    results["new_security_fields_reset_after_downgrade"]=True
    # Account creation uses the copied real schema, including username NOT NULL / VARCHAR(50).
    from app.models.user import User
    from app.models.alumni import AlumniProfile
    from app.schemas.user import UserCreate, UserRead
    from app.api.routes.users import create_user
    from app.services.operational_integrity import ensure_user_role, reconcile_user_lifecycle
    from fastapi import HTTPException
    with Session(engine) as db:
     actor=User(first_name="Synthetic",last_name="Admin",email="identity-admin@example.test",
      password_hash="unused",status="active",is_active=True,email_verified=True,profile_type="enacteur")
     db.add(actor);db.flush();ensure_user_role(db,actor.id,"administrateur");db.commit()
     created=create_user(UserCreate(first_name="Aïta",last_name="Dia",email="identity-created@example.test",
      password=_ENACTSPACE_EPHEMERAL_PASSWORD_1,enactus_join_year=2020,cursus="DUT",specialty="Gestion"),db,actor)
     assert created.username.startswith("aita.dia.") and len(created.username)<=50
     assert UserRead.model_validate(created).enactus_join_year==2020
     assert created.cursus=="DUT" and created.specialty=="Gestion"
     identifier=created.username
     try:
      create_user(UserCreate(first_name="Duplicate",last_name="Test",email="identity-duplicate@example.test",
       password=_ENACTSPACE_EPHEMERAL_PASSWORD_1,username=identifier.upper()),db,actor)
     except HTTPException as exc:assert exc.status_code==409
     else:raise AssertionError("Duplicate username accepted")
     created=db.get(User,created.id);created.status="active";created.email_verified=True
     reconcile_user_lifecycle(db,created,"alumni");db.commit()
     assert db.query(AlumniProfile).filter_by(user_id=created.id).one().enactus_join_year==2020
    results["account_creation_on_real_schema"]=True
    results["case_insensitive_username_collision_refused"]=True
    results["join_year_saved_and_preserved_for_alumni"]=True
    engine.dispose()
    # A completely new database is a separate case; no metadata.create_all shortcut in this test.
    fresh=os.environ["FRESH_DATABASE_URL"];assert "enactspace_pr2b_test_" in fresh
    env=dict(os.environ,DATABASE_URL=fresh)
    run=subprocess.run([sys.executable,"-m","alembic","upgrade","head"],capture_output=True,text=True,env=env)
    results["fresh_install_exit"]=run.returncode
    if run.returncode:
     print("FRESH_INSTALL_DIAGNOSTIC\n"+run.stdout+run.stderr,flush=True)
    else:
     with create_engine(fresh).connect() as conn:
      assert conn.execute(text("SELECT version_num FROM alembic_version")).scalar_one()==HEAD
    print("MIGRATION_REHEARSAL_RESULT "+json.dumps(results,sort_keys=True),flush=True)
    raise SystemExit(run.returncode)

if __name__ == "__main__":
    main()
