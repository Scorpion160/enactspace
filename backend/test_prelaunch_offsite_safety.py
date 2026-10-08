"""Synthetic offsite archive safety checks; no production access."""
import hashlib,json,os,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from app.scripts import prelaunch_offsite_restore as offsite
class OffsiteSafetyTests(unittest.TestCase):
    identity="20261008T094513Z_fcf746"
    def sample(self,root):
        folder=root/("prelaunch-lot26-offsite-"+self.identity);folder.mkdir(mode=0o700)
        metadata={}
        for name in offsite.ARCHIVES:
            path=folder/name;path.write_bytes(b"synthetic ciphertext");os.chmod(path,0o600)
            metadata[name]={"bytes":path.stat().st_size,"sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
        receipt={"backup_id":self.identity,"passed":True,"encrypted_archives":metadata}
        path=folder/"rehearsal.json";path.write_text(json.dumps(receipt));os.chmod(path,0o600)
        return folder
    def test_complete_copy_is_accepted(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);folder=self.sample(root)
            with patch.object(offsite.backup,"STAGE_ROOT",root):
                self.assertTrue(offsite.validate_archive_set(folder,self.identity)["passed"])
    def test_changed_ciphertext_is_rejected_before_decryption(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);folder=self.sample(root)
            (folder/"database.dump.gpg").write_bytes(b"changed ciphertext")
            with patch.object(offsite.backup,"STAGE_ROOT",root):
                with self.assertRaises(RuntimeError):offsite.validate_archive_set(folder,self.identity)
    def test_links_permissions_and_wrong_receipt_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);folder=self.sample(root)
            with patch.object(offsite.backup,"STAGE_ROOT",root):
                path=folder/"database.dump.gpg";data=path.read_bytes()
                path.unlink();outside=root/"outside";outside.write_bytes(data);path.symlink_to(outside)
                with self.assertRaises(ValueError):offsite.validate_archive_set(folder,self.identity)
                path.unlink();path.write_bytes(data);os.chmod(path,0o644)
                with self.assertRaises(ValueError):offsite.validate_archive_set(folder,self.identity)
                os.chmod(path,0o600)
                receipt=json.loads((folder/"rehearsal.json").read_text());receipt["backup_id"]="different"
                (folder/"rehearsal.json").write_text(json.dumps(receipt))
                with self.assertRaises(ValueError):offsite.validate_archive_set(folder,self.identity)
    def test_unowned_paths_and_invalid_key_do_not_start_commands(self):
        with patch.object(offsite.backup,"run") as call:
            with self.assertRaises(ValueError):offsite.validate_archive_set(Path("/var/lib/enactspace/uploads"),self.identity)
            with self.assertRaises(ValueError):offsite.execute(Path("/unused"),self.identity,b"invalid")
            call.assert_not_called()
if __name__=="__main__":unittest.main()
