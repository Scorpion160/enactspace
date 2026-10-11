"""Isolated regression tests: no production connection, no messages sent."""
import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import patch
from fastapi import HTTPException
import test_institutional_pdf_generation as fixtures
from app.models.document import Document
from app.api.routes.documents import (
    can_manage_document, can_validate_document, ensure_document_mutable,
    update_document, validate_document, submit_document, unvalidate_document,
    reject_document, archive_document, delete_document,
)
from app.services.institutional_document_service import get_template_rule, validate_payload, request_flags
from app.services.institutional_pdf_service import build_data_tex
from app.api.routes.files import ensure_file_access


class DocumentIntegrityTests(fixtures.InstitutionalPdfGenerationTests):
    def test_every_public_form_field_reaches_pdf_data(self):
        # All eight registries, including nested sections omitted by shallow audits.
        excluded_types = {'user', 'users', 'date', 'datetime', 'time', 'number'}
        for code, payload in self._payloads().items():
            item = self._request(code, payload, pole_id=self.veille.id, project_id=self.project.id)
            for field in get_template_rule(code).fields:
                if field['type'] in excluded_types or field['name'] == 'internal_notes':
                    continue
                marker = 'MARKER' + field['name'].replace('_', '').upper()
                enriched = dict(payload)
                enriched[field['name']] = ([{'title': marker, 'details': marker}]
                    if field['type'] in {'structured_list', 'decision_list', 'vote_list'}
                    else [{'action': marker}] if field['type'] == 'action_list'
                    else [{'from': marker, 'to': marker}] if field['type'] == 'route_list'
                    else [marker] if field['type'] == 'list' else marker)
                item.payload_json = enriched
                with self.subTest(code=code, field=field['name']):
                    self.assertIn(marker, build_data_tex(self.db, item))

    def test_recipient_letter_excludes_internal_notes_and_keeps_current_fields(self):
        payload = dict(self._payloads()['notification_renvoi'],
            internal_notes='CONFIDENTIALSENTINEL', prior_steps=[{'title': 'PRIORSTEP'}],
            procedure='PROCEDURESENTINEL', decision='DECISIONSENTINEL',
            administrative_consequences='CONSEQUENCESENTINEL')
        item = self._request('notification_renvoi', payload, pole_id=self.veille.id)
        tex = build_data_tex(self.db, item)
        self.assertNotIn('CONFIDENTIALSENTINEL', tex)
        for marker in ('PRIORSTEP', 'PROCEDURESENTINEL', 'DECISIONSENTINEL', 'CONSEQUENCESENTINEL'):
            self.assertIn(marker, tex)
        self.assertEqual(item.payload_json['internal_notes'], 'CONFIDENTIALSENTINEL')

    def test_generated_pdf_is_immutable_even_for_global_managers(self):
        item = self._request('demande_bus', self._payloads()['demande_bus'])
        document = Document(title='Official', file_url='https://example.test/test.pdf',
                            uploaded_by=self.member.id, status='validated', is_official=True)
        self.db.add(document)
        self.db.flush()
        item.generated_document_id = document.id
        self.db.flush()
        for user in (self.member, self.sg, self.tl):
            self.assertFalse(can_manage_document(self.db, user, document))
            self.assertFalse(can_validate_document(self.db, user, document))
        with self.assertRaises(HTTPException) as error:
            ensure_document_mutable(self.db, document)
        self.assertEqual(error.exception.status_code, 409)
        file_id = uuid.uuid4()
        document.file_id = file_id
        self.db.flush()
        with self.assertRaises(HTTPException) as blocked_file:
            ensure_file_access(self.db, SimpleNamespace(id=file_id), self.tl, manage=True)
        self.assertEqual(blocked_file.exception.status_code, 409)
        # Every generic mutation route must enforce the same protection.
        for route in (update_document, validate_document, submit_document,
                      unvalidate_document, reject_document, archive_document, delete_document):
            import inspect
            with patch('app.api.routes.documents.get_visible_document_or_404', return_value=document):
                kwargs = {'document_id': str(document.id), 'db': self.db, 'current_user': self.tl}
                for name in ('request', 'payload'):
                    if name in inspect.signature(route).parameters:
                        kwargs[name] = None
                with self.assertRaises(HTTPException) as blocked:
                    route(**kwargs)
                self.assertEqual(blocked.exception.status_code, 409)

    def test_sg_validator_cannot_also_approve_with_team_leader_role(self):
        self._role(self.sg, 'team_leader')
        item = self._request('demande_bus', self._payloads()['demande_bus'])
        item.status = 'pending_approval'
        self.assertFalse(request_flags(self.db, self.sg, item)['can_approve'])
        self.assertTrue(request_flags(self.db, self.tl, item)['can_approve'])

    def test_invalid_counts_dates_and_whitespace_are_rejected(self):
        rule = get_template_rule('demande_bus')
        base = self._payloads()['demande_bus']
        for change in ({'passenger_count': 'NaN'}, {'passenger_count': 0},
                       {'passenger_count': 1.5}, {'return_at': '2020-01-01T12:00'},
                       {'departure_at': 'not-a-date'}, {'trip_purpose': '   '}):
            with self.subTest(change=change), self.assertRaises(HTTPException):
                validate_payload(rule, dict(base, **change))


if __name__ == '__main__':
    unittest.main()
