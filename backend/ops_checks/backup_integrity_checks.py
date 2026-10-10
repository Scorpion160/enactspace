"""Host-only GPG integrity checks with synthetic data."""
import subprocess,tempfile,unittest
from pathlib import Path
from test_prelaunch_backup_restore import backup

class BackupIntegrityChecks(unittest.TestCase):
    def test_encryption_integrity_and_wrong_key_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);key=root/"key";wrong=root/"wrong"
            key.write_bytes(b"synthetic-only-test-passphrase");wrong.write_bytes(b"other-test-passphrase")
            original=root/"input";original.write_bytes(b"synthetic backup content"*500)
            encrypted=root/"archive.gpg";restored=root/"restored"
            backup.encrypt_stream(["cat",str(original)],encrypted,key)
            backup.decrypt_file(encrypted,restored,key)
            self.assertEqual(restored.read_bytes(),original.read_bytes())
            restored.unlink()
            with self.assertRaises(RuntimeError):backup.decrypt_file(encrypted,restored,wrong)
            self.assertFalse(restored.exists())
            damaged=bytearray(encrypted.read_bytes());damaged[-12]^=1;encrypted.write_bytes(damaged)
            with self.assertRaises(RuntimeError):backup.decrypt_file(encrypted,restored,key)
            self.assertFalse(restored.exists())

if __name__=="__main__":unittest.main()
