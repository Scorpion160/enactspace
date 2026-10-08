"""Escrow tests use synthetic bytes only; no production key or DPAPI operation."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import prelaunch_key_escrow as escrow


def private(path):
    path.mkdir(mode=0o700,parents=True,exist_ok=True)


class EscrowTests(unittest.TestCase):
    def test_relative_paths_keep_phrase_off_the_command_line(self):
        with tempfile.TemporaryDirectory() as temp,patch.object(escrow.windows,'private_directory',side_effect=private),patch.object(escrow.subprocess,'run',return_value=subprocess.CompletedProcess([],0,b'ciphertext',b'')) as run:
            root=Path(temp);self.assertEqual(escrow.crypt(b'synthetic','synthetic phrase for testing only',root),b'ciphertext')
            args=run.call_args_list[0].args[0]
            self.assertEqual(args[args.index('--homedir')+1],'gpg')
            self.assertEqual(args[args.index('--passphrase-file')+1],'passphrase')
            self.assertNotIn('synthetic phrase for testing only',str(args));self.assertEqual(list(root.iterdir()),[])

    def test_error_is_masked_and_workspace_removed(self):
        with tempfile.TemporaryDirectory() as temp,patch.object(escrow.windows,'private_directory',side_effect=private),patch.object(escrow.subprocess,'run',return_value=subprocess.CompletedProcess([],2,b'',b'private-context')),contextlib.redirect_stdout(io.StringIO()) as output:
            root=Path(temp)
            with self.assertRaisesRegex(RuntimeError,'^portable_key_encryption_failed$'):escrow.crypt(b'synthetic','synthetic phrase for testing only',root)
            self.assertEqual(list(root.iterdir()),[]);self.assertEqual(output.getvalue(),'')

    def test_timeout_removes_workspace(self):
        with tempfile.TemporaryDirectory() as temp,patch.object(escrow.windows,'private_directory',side_effect=private),patch.object(escrow.subprocess,'run',side_effect=subprocess.TimeoutExpired('gpg',60)):
            root=Path(temp)
            with self.assertRaises(subprocess.TimeoutExpired):escrow.crypt(b'synthetic','synthetic phrase for testing only',root)
            self.assertEqual(list(root.iterdir()),[])

    def test_phrase_validation_runs_before_creating_files(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            for phrase in ('short','x'*20+'\n','x'*20+'\r','x'*20+'\0'):
                with self.assertRaises(ValueError):escrow.crypt(b'synthetic',phrase,root)
            self.assertEqual(list(root.iterdir()),[])

    def test_payload_rejects_wrong_backup_or_invalid_key(self):
        identity='20261008T094513Z_fcf746';value={'version':1,'backup_id':identity,'key':'a'*64}
        self.assertEqual(escrow.validate_payload(json.dumps(value).encode(),identity),b'a'*64)
        for changed in (dict(value,backup_id='wrong'),dict(value,key='invalid'),dict(value,version=2)):
            with self.assertRaises(ValueError):escrow.validate_payload(json.dumps(changed).encode(),identity)

    @unittest.skipUnless(os.name=='nt','Real GnuPG and Windows ACL validation must run on Windows')
    def test_windows_real_crypto_rejects_wrong_phrase_and_tampering(self):
        root=Path(os.environ['LOCALAPPDATA'])/'EnactSpace'/('EscrowSelfTest-'+os.urandom(6).hex())
        escrow.windows.private_directory(root)
        try:
            payload=b'synthetic payload; no production key'
            encrypted=escrow.crypt(payload,'synthetic phrase for testing only',root)
            self.assertNotIn(payload,encrypted)
            self.assertEqual(escrow.crypt(encrypted,'synthetic phrase for testing only',root,decrypt=True),payload)
            with self.assertRaises(RuntimeError):escrow.crypt(encrypted,'different synthetic phrase for testing only',root,decrypt=True)
            changed=bytearray(encrypted);changed[-1]^=1
            with self.assertRaises(RuntimeError):escrow.crypt(bytes(changed),'synthetic phrase for testing only',root,decrypt=True)
            self.assertEqual(list(root.iterdir()),[])
        finally:
            import shutil
            shutil.rmtree(root)

if __name__=='__main__':unittest.main()
