"""Scheduled encrypted capture and isolated verification, with a release guard."""
import argparse,fcntl,json,os
from pathlib import Path
from app.scripts import prelaunch_backup_restore as backup
ROOT=Path("/opt/enactspace/operations/backup-lot26")
APPROVED_REVISIONS={"20261006_0025","20261007_0031"}
def approved_revision(revision):
    if revision not in APPROVED_REVISIONS:raise ValueError("Production revision is not approved for scheduled backup")
    return revision
def execute():
    if os.name!="posix":raise ValueError("Linux host required")
    root=ROOT
    if root.is_symlink() or not root.is_dir() or root.stat().st_mode & 0o077:
        raise ValueError("Private operations directory required")
    descriptor=os.open(root/"capture.lock",os.O_WRONLY|os.O_CREAT|os.O_NOFOLLOW,0o600)
    with os.fdopen(descriptor,"w") as lock:
        try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:
            print(json.dumps({"skipped":"another_capture_running","production_changed":False}),flush=True);return
        revision=approved_revision(backup.sql(backup.PRODUCTION_DB,"SELECT to_json(version_num) FROM alembic_version",production=True))
        backup.execute_rehearsal(expected_revision=revision)
if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--execute-scheduled-capture",action="store_true")
    if not parser.parse_args().execute_scheduled_capture:parser.error("Explicit capture opt-in required")
    execute()
