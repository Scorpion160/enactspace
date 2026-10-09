import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import android_acceptance_adb as runner

class Tests(unittest.TestCase):
    def test_ambiguous_labels_are_not_tapped(self):
        xml = '<hierarchy><node text="Tâches" enabled="true" bounds="[0,0][100,100]"/><node text="Tâches" enabled="true" bounds="[0,200][100,300]"/></hierarchy>'
        device = runner.Device('fake')
        with patch.object(device, 'ui', return_value=xml), patch.object(device, 'adb') as adb:
            self.assertFalse(device.tap_label(['Taches']))
            adb.assert_not_called()
    def test_password_and_disabled_nodes_ignored(self):
        xml = '<hierarchy><node text="secret" password="true" bounds="[0,0][50,50]"/><node text="secret" enabled="false" bounds="[0,0][50,50]"/></hierarchy>'
        self.assertEqual(runner.candidates(xml, ['secret']), [])
    def test_unique_accessible_label_uses_bounds(self):
        xml = '<hierarchy><node content-desc="Tâches" enabled="true" bounds="[20,40][100,80]"/></hierarchy>'
        self.assertEqual(runner.candidates(xml, ['Taches']), [(60,60)])
    def test_crash_filter_rejects_old_or_other_app(self):
        old = 'FATAL EXCEPTION: main\nProcess: ' + runner.PACKAGE + '\nold failure'
        other = '\nFATAL EXCEPTION: main\nProcess: unrelated.package\nfailure'
        self.assertEqual(runner.new_app_crashes(old, old + other), 0)
        new = '\nFATAL EXCEPTION: main\nProcess: ' + runner.PACKAGE + '\nnew failure'
        self.assertEqual(runner.new_app_crashes(old, old + new), 1)
    def test_report_never_passes_skipped_or_failed_cases(self):
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp)
            report = {'results': [{'id':'one','title':'one','status':'PASS','evidence':'observed'}, {'id':'two','title':'two','status':'NOT_VERIFIED','evidence':'not run'}]}
            runner.save_report(report,p)
            self.assertEqual(json.loads((p/'report.json').read_text())['status'],'PARTIAL')
            report['results'][1]['status']='FAIL'
            runner.save_report(report,p)
            self.assertEqual(report['status'],'FAILED')
    def test_abort_keeps_unrun_scenarios(self):
        class Fake:
            def __init__(self, serial): pass
            def adb(self,*args,**kwargs):
                if args == ('get-state',):return 'device'
                if args[:3] == ('shell','dumpsys','package'):return 'versionCode=14\nversionName=1.0.11'
                return '36'
            def crashes(self):return ''
            def launch(self):pass
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)/'report'
            with patch.object(runner,'Device',Fake), patch('builtins.input',return_value='Q'), contextlib.redirect_stdout(io.StringIO()):
                code = runner.main(['--output',str(output)])
            data=json.loads((output/'report.json').read_text())
            self.assertEqual(code,2)
            self.assertTrue(all(x['status']=='NOT_VERIFIED' for x in data['results']))
    def test_wrong_version_prevents_launch(self):
        class Fake:
            def __init__(self, serial):pass
            def adb(self,*args,**kwargs):return 'device' if args==('get-state',) else 'versionCode=13\nversionName=1.0.10'
            def launch(self):raise AssertionError('must not launch')
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(runner,'Device',Fake), contextlib.redirect_stdout(io.StringIO()):
                code=runner.main(['--output',str(Path(temp)/'report')])
            self.assertEqual(code,1)

if __name__=='__main__':unittest.main()
