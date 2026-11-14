"""Restore a returned encrypted offsite copy; never accesses production records."""
from __future__ import annotations
import argparse,hashlib,json,os,re,secrets,shutil,subprocess,sys,time
from datetime import datetime,timezone
from pathlib import Path
from app.scripts import prelaunch_backup_restore as backup
ARCHIVES={"database.dump.gpg","schema-reference.dump.gpg","uploads.tar.gz.gpg","verification.json.gpg"}
def validate_archive_set(folder,identity):
    if not re.fullmatch(r"\d{8}T\d{6}Z_[0-9a-f]{6}",identity):raise ValueError("Invalid backup identity")
    if folder.is_symlink() or folder.resolve().parent!=backup.STAGE_ROOT.resolve():raise ValueError("Unowned archive directory")
    if not re.fullmatch(r"prelaunch-lot26-offsite-\d{8}T\d{6}Z_[0-9a-f]{6}",folder.name):raise ValueError("Unowned archive directory")
    if (folder.stat().st_mode & 0o077):raise ValueError("Archive directory must be private")
    receipt=folder/"rehearsal.json"
    if receipt.is_symlink():raise ValueError("Unsafe receipt")
    report=json.loads(receipt.read_text())
    if report.get("backup_id")!=identity or report.get("passed") is not True or set(report.get("encrypted_archives",{}))!=ARCHIVES:
        raise ValueError("Unexpected backup receipt")
    for name in ARCHIVES:
        file=folder/name
        if file.is_symlink() or not file.is_file() or (file.stat().st_mode & 0o077):raise ValueError("Unsafe encrypted archive")
        expected=report["encrypted_archives"][name]
        if file.stat().st_size!=expected["bytes"] or hashlib.sha256(file.read_bytes()).hexdigest()!=expected["sha256"]:
            raise RuntimeError("Offsite_archive_hash_mismatch")
    return report
def execute(folder,identity,key):
    if os.name!="posix" or not re.fullmatch(b"[0-9a-f]{64}",key):raise ValueError("Invalid recovery context")
    receipt=validate_archive_set(folder,identity)
    started=time.monotonic()
    run_id=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")+"_"+secrets.token_hex(3)
    resources={kind:backup.PREFIX+kind+"_"+run_id for kind in ("pg","net","volume")}
    work=folder/"restore-work";backup.private_directory(work)
    result={"backup_id":identity,"production_changed":False,"production_data_queried":False,
        "application_or_workers_started":False,"real_emails_sent":0,"real_push_sent":0,"real_payments":0,
        "original_vps_key_used_for_restore":False,"offsite_archives_hash_verified":True}
    owns=False;failure=None
    try:
        key_file=work/"recovered.key"
        descriptor=os.open(key_file,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
        with os.fdopen(descriptor,"wb") as stream:stream.write(key)
        manifest_file=work/"verification.json"
        backup.decrypt_file(folder/"verification.json.gpg",manifest_file,key_file)
        manifest=json.loads(manifest_file.read_text())
        image=manifest["restore_image_id"]
        if not re.fullmatch(r"sha256:[0-9a-f]{64}",image) or image!=receipt["restore_image_id"]:
            raise ValueError("Unexpected restore image")
        expected=manifest["expected_snapshot"]
        if expected["revision"]!=manifest["production_revision"] or expected["revision"]!=receipt["production_revision"]:
            raise ValueError("Unexpected capture revision")
        backup.run(["docker","image","inspect",image],label="pinned_restore_image")
        backup.ensure_resources_absent(resources);owns=True
        backup.run(["docker","network","create","--internal",resources["net"]],label="offsite_network")
        backup.run(["docker","volume","create",resources["volume"]],label="offsite_volume")
        backup.run(["docker","run","-d","--name",resources["pg"],"--network",resources["net"],
            "--mount","type=volume,src="+resources["volume"]+",dst=/var/lib/postgresql/data",
            "-e","POSTGRES_USER=prelaunch_restore","-e","POSTGRES_PASSWORD=isolated-disposable-test-only",
            "-e","POSTGRES_DB=enactspace_pr2b_test_restore",image],label="offsite_postgres")
        for _ in range(60):
            ready=subprocess.run(["docker","exec",resources["pg"],"pg_isready","-h","127.0.0.1",
                "-U","prelaunch_restore","-d","enactspace_pr2b_test_restore"],capture_output=True)
            if ready.returncode==0:break
            time.sleep(.3)
        else:raise RuntimeError("Offsite_postgres_not_ready")
        dump=work/"database.dump";files=work/"uploads.tar.gz"
        backup.decrypt_file(folder/"database.dump.gpg",dump,key_file)
        backup.decrypt_file(folder/"uploads.tar.gz.gpg",files,key_file)
        backup.restore_dump(resources["pg"],dump)
        target=work/"uploads";backup.private_directory(target);backup.safe_extract(files,target)
        restored=backup.database_snapshot(resources["pg"],key)
        result["comparison_diagnostic"]=backup.snapshot_difference(expected,restored)
        if backup.comparable_snapshot(restored)!=expected:raise RuntimeError("Offsite_database_difference")
        actual_files=backup.file_manifest(target)
        if actual_files!=manifest["files"]:raise RuntimeError("Offsite_file_difference")
        linked=backup.check_stored_files(resources["pg"],target)
        result.update(database_tables=len(restored["tables"]),database_rows=sum(x["rows"] for x in restored["tables"].values()),
            files_count=len(actual_files),files_bytes=sum(x["size"] for x in actual_files.values()),stored_file_check=linked,
            database_schema_and_files_equal=True,production_revision_at_capture=restored["revision"],
            restore_seconds=round(time.monotonic()-started,3))
        result["passed"]=all(linked[name]==0 for name in ("missing","wrong_size","wrong_hash","unsafe_path"))
        if not result["passed"]:raise RuntimeError("Offsite_reference_difference")
    except Exception as exc:
        failure=exc;result["passed"]=False
        result["failure"]=str(exc) if isinstance(exc,RuntimeError) else type(exc).__name__
    finally:
        try:cleaned=backup.cleanup_owned(resources) if owns else True
        except Exception:cleaned=False
        shutil.rmtree(work)
        result["owned_test_resources_removed"]=cleaned
        result["decrypted_staging_removed"]=not work.exists()
        result["finished_at"]=datetime.now(timezone.utc).isoformat()
        print(json.dumps(result),flush=True)
    if failure or not result.get("passed") or not result["owned_test_resources_removed"]:raise SystemExit(1)
if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute-offsite-rehearsal",action="store_true")
    parser.add_argument("--archive-dir",type=Path,required=True)
    parser.add_argument("--backup-id",required=True)
    args=parser.parse_args()
    if not args.execute_offsite_rehearsal:parser.error("Explicit rehearsal opt-in required")
    execute(args.archive_dir,args.backup_id,sys.stdin.buffer.read(65))
