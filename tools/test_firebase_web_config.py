import base64
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import generate_firebase_web_worker as m


def fixture_config():
    return {'apiKey':'AIza'+'x'*35,'appId':'1:123456:web:abcdef','messagingSenderId':'123456',
            'projectId':'synthetic-project','authDomain':'synthetic-project.firebaseapp.com',
            'storageBucket':'synthetic-project.appspot.com'}


def fixture_template():
    return m.make_template('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js',
                           'https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js')


class FirebaseWebConfigTests(unittest.TestCase):
    def test_existing_config_and_sdk_round_trip(self):
        config=fixture_config();template=fixture_template();worker=m.render(template,config)
        parsed,model=m.parse_existing_worker(worker)
        self.assertEqual(parsed,config);self.assertEqual(model,template)

    def test_comment_is_not_confused_with_https_sdk_url(self):
        worker=m.render(fixture_template(),fixture_config())
        parsed,_=m.parse_existing_worker('// Notes\n'+worker+'\n/* Other notes */')
        self.assertEqual(parsed,fixture_config())

    def test_foreign_script_and_added_code_are_refused(self):
        worker=m.render(fixture_template(),fixture_config())
        for bad in (worker.replace('www.gstatic.com','foreign.example'), worker+'\nfetch("https://foreign.example/");',worker.replace('firebase.messaging();','firebase.messaging(); self.other = 1;')):
            with self.assertRaises(ValueError):m.parse_existing_worker(bad)

    def test_mismatched_sdk_versions_are_refused(self):
        worker=m.render(fixture_template(),fixture_config())
        worker=worker.replace('/10.13.2/firebase-messaging','/10.13.3/firebase-messaging')
        with self.assertRaises(ValueError):m.parse_existing_worker(worker)

    def test_private_server_fields_and_extra_properties_are_refused(self):
        config=fixture_config();config['private_key']='test-only'
        with self.assertRaises(ValueError):m.validate_config(config)
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'defines.json'
            data={v:fixture_config()[k] for k,v in m.CONFIG_KEYS.items()};data['SMTP_PASSWORD']='test-only'
            path.write_text(json.dumps(data))
            with self.assertRaises(ValueError):m.load_defines(path)

    def test_duplicate_json_property_is_refused(self):
        worker=m.render(fixture_template(),fixture_config())
        worker=worker.replace('"apiKey":', '"apiKey": "duplicate", "apiKey":',1)
        with self.assertRaises(ValueError):m.parse_existing_worker(worker)

    def test_application_and_sender_mismatch_are_refused(self):
        config=fixture_config();config['appId']='1:654321:web:abcdef'
        with self.assertRaises(ValueError):m.validate_config(config)

    def test_render_checks_placeholder_and_injected_template(self):
        for template in ('no placeholder',fixture_template()+'fetch("https://foreign.example");',fixture_template()+m.PLACEHOLDER):
            with self.assertRaises(ValueError):m.render(template,fixture_config())

    def test_release_config_requires_https_api_and_vapid(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'defines.json';defines={v:fixture_config()[k] for k,v in m.CONFIG_KEYS.items()}
            path.write_text(json.dumps(defines))
            with self.assertRaises(ValueError):m.load_defines(path,require_release=True)
            defines['ENACTSPACE_API_URL']='https://api.example.test'
            defines['ENACTSPACE_FIREBASE_VAPID_PUBLIC_KEY']=base64.urlsafe_b64encode(b'\x04'+b'x'*64).decode().rstrip('=')
            path.write_text(json.dumps(defines));self.assertEqual(m.load_defines(path,require_release=True),fixture_config())
            defines['ENACTSPACE_API_URL']='http://api.example.test';path.write_text(json.dumps(defines))
            with self.assertRaises(ValueError):m.load_defines(path,require_release=True)

    def test_atomic_generation_produces_same_config_without_printing_values(self):
        with tempfile.TemporaryDirectory() as temp:
            repo=Path(temp);(repo/'tools/templates').mkdir(parents=True);(repo/'frontend/web').mkdir(parents=True)
            (repo/'tools/templates/firebase-messaging-sw.template.js').write_text(fixture_template())
            defines=repo/'defines.json';defines.write_text(json.dumps({v:fixture_config()[k] for k,v in m.CONFIG_KEYS.items()}))
            result=m.generate(repo,defines)
            self.assertEqual(m.parse_existing_worker((repo/'frontend/web/firebase-messaging-sw.js').read_text())[0],fixture_config())
            self.assertFalse(result['values_printed'])
            self.assertNotIn(fixture_config()['apiKey'],json.dumps(result))

    def test_failed_replace_preserves_previous_worker_and_removes_temporary_file(self):
        with tempfile.TemporaryDirectory() as temp:
            repo=Path(temp);(repo/'tools/templates').mkdir(parents=True);(repo/'frontend/web').mkdir(parents=True)
            (repo/'tools/templates/firebase-messaging-sw.template.js').write_text(fixture_template())
            worker=repo/'frontend/web/firebase-messaging-sw.js';worker.write_text('previous worker')
            defines=repo/'defines.json';defines.write_text(json.dumps({v:fixture_config()[k] for k,v in m.CONFIG_KEYS.items()}))
            with patch.object(m.os,'replace',side_effect=OSError('synthetic failure')):
                with self.assertRaises(OSError):m.generate(repo,defines)
            self.assertEqual(worker.read_text(),'previous worker')
            self.assertEqual(list(worker.parent.glob('.firebase-worker-*')),[])

if __name__=='__main__':unittest.main()
