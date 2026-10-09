import copy
import datetime as dt
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch
import prelaunch_recruitment_cleanup as cleanup

class Tests(unittest.TestCase):
    def fixture(self):
        apps=[{'id':i,'campaign_id':cleanup.CAMPAIGN,'converted_user_id':None} for i in sorted(cleanup.APPLICATIONS)]
        files=[{'id':'file-one','entity_type':'application','entity_id':apps[0]['id'],'storage_path':'recruitment/one'}, {'id':'file-two','entity_type':'application','entity_id':apps[0]['id'],'storage_path':'recruitment/two'}]
        apps[0].update(cv_url='/api/files/file-one/download',motivation_letter_url='/api/files/file-two/download')
        notifications=[{'id':'notification-'+str(i),'related_type':'application','related_id':apps[i%3]['id']} for i in range(9)]
        emails=[{'id':'email-'+str(i),'notification_id':r['id']} for i,r in enumerate(notifications)]
        emails.extend({'id':'submission-'+str(i),'dedupe_key':'recruitment-submission:'+r['id']} for i,r in enumerate(apps))
        data={'recruitment_campaigns':[{'id':cleanup.CAMPAIGN,'title':'Test_recrutement'},{'id':'real-campaign','title':'Real'}], 'applications':apps,'stored_files':files,'notifications':notifications,'email_deliveries':emails,'users':[{'id':'real-member'}], 'audit_logs':[{'id':'test-audit','entity_type':'application','entity_id':apps[0]['id']},{'id':'real-audit','entity_type':'user','entity_id':'real-member'}], 'push_deliveries':[{'id':'push-one','notification_id':'notification-0'}]}
        fks=[('applications','recruitment_campaigns','campaign_id','id'),('email_deliveries','notifications','notification_id','id'),('push_deliveries','notifications','notification_id','id')]
        return data,fks
    def test_selection_excludes_real_objects_and_includes_descendants(self):
        data,fks=self.fixture();s=cleanup.select_rows(data,fks)
        self.assertNotIn('users',s);self.assertEqual(s['recruitment_campaigns'],{cleanup.CAMPAIGN})
        self.assertEqual(s['audit_logs'],{'test-audit'});self.assertEqual(s['push_deliveries'],{'push-one'})
        self.assertEqual(len(s['email_deliveries']),12);self.assertEqual(len(s['stored_files']),2)
    def test_converted_candidate_blocks(self):
        data,fks=self.fixture();data['applications'][0]['converted_user_id']='real-member'
        with self.assertRaisesRegex(RuntimeError,'converted'):cleanup.select_rows(data,fks)
    def test_new_candidate_blocks(self):
        data,fks=self.fixture();data['applications'].append({'id':'new','campaign_id':cleanup.CAMPAIGN})
        with self.assertRaises(RuntimeError):cleanup.select_rows(data,fks)
    def test_unknown_dependent_table_blocks(self):
        data,fks=self.fixture();data['users'][0]['source_application']=next(iter(cleanup.APPLICATIONS))
        fks.append(('users','applications','source_application','id'))
        with self.assertRaisesRegex(RuntimeError,'Unexpected_linked_table'):cleanup.select_rows(data,fks)
    def test_shared_file_in_nested_json_blocks(self):
        data,fks=self.fixture();data['users'][0]['extra']={'file':'file-one'}
        with self.assertRaisesRegex(RuntimeError,'Shared_attachment_reference'):cleanup.select_rows(data,fks)
    def test_unresolved_attachment_blocks(self):
        data,fks=self.fixture();data['applications'][0]['cv_url']='https://external.invalid/missing'
        with self.assertRaisesRegex(RuntimeError,'Attachment_reference'):cleanup.select_rows(data,fks)
    def test_new_notification_blocks(self):
        data,fks=self.fixture();data['notifications'].append({'id':'new','related_type':'application','related_id':next(iter(cleanup.APPLICATIONS))})
        with self.assertRaisesRegex(RuntimeError,'count_changed'):cleanup.select_rows(data,fks)
    def test_fingerprint_detects_review_change(self):
        data,fks=self.fixture();s=cleanup.select_rows(data,fks);digest=cleanup.fingerprint(data,s)
        data['applications'][0]['status']='changed';self.assertNotEqual(digest,cleanup.fingerprint(data,s))
    def test_backup_requires_recent_verified_integrity(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);directory=root/'prelaunch-lot26-test';directory.mkdir(mode=0o700)
            now=dt.datetime.now(dt.timezone.utc)
            report={k:True for k in ('passed','database_content_equal','files_content_equal','owned_test_resources_removed','decrypted_staging_removed')}
            report.update(finished_at=now.isoformat(),production_revision='20261006_0025',backup_id='test',encrypted_archives={})
            for name in ('database.dump.gpg','uploads.tar.gz.gpg','verification.json.gpg'):
                (directory/name).write_bytes(b'synthetic encrypted fixture')
                report['encrypted_archives'][name]={'bytes':27,'sha256':hashlib.sha256((directory/name).read_bytes()).hexdigest()}
                report['encrypted_archives'][name]['bytes']=(directory/name).stat().st_size
            path=directory/'rehearsal.json';path.write_text(json.dumps(report))
            # Simulate the Linux mode only for this fixture on Windows; production
            # verify_backup continues to inspect actual Linux permissions.
            original_stat = Path.stat
            def fixture_stat(path, *args, **kwargs):
                value = original_stat(path, *args, **kwargs)
                if path == directory:
                    return SimpleNamespace(st_mode=(value.st_mode & ~0o777) | 0o700,
                                           st_mtime=value.st_mtime, st_size=value.st_size)
                return value
            with patch.object(Path, 'stat', fixture_stat):
                self.assertEqual(cleanup.verify_backup(root,now)['backup_id'],'test')
                (directory/'database.dump.gpg').write_bytes(b'tampered')
                with self.assertRaisesRegex(RuntimeError,'integrity'):
                    cleanup.verify_backup(root,now)

if __name__=='__main__':unittest.main()
