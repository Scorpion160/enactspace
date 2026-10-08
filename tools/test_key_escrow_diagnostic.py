import json
from pathlib import Path,PureWindowsPath
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import diagnose_key_escrow_gpg as diagnostic


def private(path):path.mkdir(parents=True,mode=0o700,exist_ok=True)


class DiagnosticTests(unittest.TestCase):
    def test_path_variants_are_explicit(self):
        home=PureWindowsPath('C:/private/gpg');phrase=PureWindowsPath('C:/private/passphrase')
        self.assertEqual(diagnostic.arguments('relative_workspace',home,phrase),('gpg','passphrase'))
        self.assertEqual(diagnostic.arguments('msys_absolute',home,phrase),('/c/private/gpg','/c/private/passphrase'))
        self.assertEqual(diagnostic.arguments('windows_absolute',home,phrase),(str(home),str(phrase)))

    def test_error_classifier_never_returns_raw_diagnostic(self):
        for text in (b"can't connect to the agent private-context",b'cannot open passphrase: no such file',b'private-sensitive-context',b'cannot create socket: Operation not permitted'):
            result=diagnostic.classify(text)
            self.assertNotIn('private',result);self.assertNotIn('sensitive',result)

    def test_failed_encryption_cleans_all_material(self):
        with tempfile.TemporaryDirectory() as temp,patch.object(diagnostic.subprocess,'run',return_value=subprocess.CompletedProcess([],2,b'',b'private-sensitive-context')):
            root=Path(temp);result=diagnostic.attempt('relative_workspace',root,private)
            self.assertFalse(result['roundtrip_passed']);self.assertTrue(result['temporary_workspace_removed'])
            self.assertEqual(list(root.iterdir()),[]);self.assertNotIn('private-sensitive',json.dumps(result))

    def test_success_compares_bytes_and_cleans_workspace(self):
        responses=[subprocess.CompletedProcess([],0,b'synthetic-ciphertext',b''),subprocess.CompletedProcess([],0,diagnostic.PAYLOAD,b'')]
        with tempfile.TemporaryDirectory() as temp,patch.object(diagnostic.subprocess,'run',side_effect=responses) as run:
            root=Path(temp);result=diagnostic.attempt('relative_workspace',root,private)
            self.assertTrue(result['roundtrip_passed']);self.assertTrue(result['temporary_workspace_removed'])
            self.assertNotIn(diagnostic.PHRASE,str(run.call_args_list));self.assertEqual(list(root.iterdir()),[])

    def test_timeout_also_removes_workspace(self):
        with tempfile.TemporaryDirectory() as temp,patch.object(diagnostic.subprocess,'run',side_effect=subprocess.TimeoutExpired('gpg',45)):
            root=Path(temp);result=diagnostic.attempt('relative_workspace',root,private)
            self.assertEqual(result['error'],'GPG_TIMEOUT');self.assertTrue(result['temporary_workspace_removed'])
            self.assertEqual(list(root.iterdir()),[])

if __name__=='__main__':unittest.main()
