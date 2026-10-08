"""Scheduled capture release and concurrency guards with synthetic state."""
import fcntl,io,os,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from app.scripts import prelaunch_scheduled_backup as scheduled
class ScheduledBackupSafetyTests(unittest.TestCase):
    def test_only_approved_release_revisions_are_accepted(self):
        for revision in ("20261006_0025","20261007_0031"):
            self.assertEqual(scheduled.approved_revision(revision),revision)
        for revision in ("20261007_9999",None,"unexpected"):
            with self.assertRaises(ValueError):scheduled.approved_revision(revision)
    def test_existing_capture_lock_prevents_another_capture(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);os.chmod(root,0o700)
            with (root/"capture.lock").open("w") as lock:
                fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
                with patch.object(scheduled,"ROOT",root),patch.object(scheduled.backup,"sql") as sql,patch.object(scheduled.backup,"execute_rehearsal") as execute,patch("sys.stdout",new_callable=io.StringIO):
                    scheduled.execute();sql.assert_not_called();execute.assert_not_called()
    def test_revision_is_checked_before_capture(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);os.chmod(root,0o700)
            with patch.object(scheduled,"ROOT",root),patch.object(scheduled.backup,"sql",return_value="20261007_9999"),patch.object(scheduled.backup,"execute_rehearsal") as execute:
                with self.assertRaises(ValueError):scheduled.execute()
                execute.assert_not_called()
    def test_capture_receives_the_verified_revision(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);os.chmod(root,0o700)
            with patch.object(scheduled,"ROOT",root),patch.object(scheduled.backup,"sql",return_value="20261007_0031"),patch.object(scheduled.backup,"execute_rehearsal") as execute:
                scheduled.execute();execute.assert_called_once_with(expected_revision="20261007_0031")
if __name__=="__main__":unittest.main()
