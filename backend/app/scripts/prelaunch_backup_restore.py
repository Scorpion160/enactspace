"""Encrypted data backup and isolated restore on the authorized Linux Docker host."""
from __future__ import annotations
import argparse,hashlib,hmac,json,os,re,secrets,shutil,subprocess,tarfile,time
from datetime import datetime,timezone
from pathlib import Path,PurePosixPath
PRODUCTION_DB="enactspace_postgres"
UPLOADS=Path("/var/lib/enactspace/uploads")
PREFIX="enactspace_prelaunch_lot26_"
KEY_ROOT=Path("/opt/enactspace/backup-keys")
BACKUP_ROOT=Path("/var/backups/enactspace")
STAGE_ROOT=Path("/opt/enactspace/staging")
SCHEMA_COMPONENTS={"constraints","indexes","columns","enums","views","functions","triggers"}

def run(args,*,timeout=120,label="operation"):
    result=subprocess.run(args,capture_output=True,timeout=timeout)
    if result.returncode:raise RuntimeError(label+"_failed")
    return result.stdout

def quote_identifier(value):
    return '"'+value.replace('"','""')+'"'

def sql(container,statement,*,production=False,database="enactspace_pr2b_test_restore"):
    if production:
        if container!=PRODUCTION_DB:raise ValueError("Unexpected production source")
        args=["docker","exec",container,"sh","-c",
            'exec psql -X -qAt -v ON_ERROR_STOP=1 --username="$POSTGRES_USER" --dbname="$POSTGRES_DB" --command="$1"',
            "readonly-sql","BEGIN READ ONLY; "+statement+"; COMMIT;"]
    else:
        if not container.startswith(PREFIX):raise ValueError("Unsafe restore container")
        if database not in {"enactspace_pr2b_test_restore","enactspace_pr2b_test_schema"}:raise ValueError("Unsafe restore database")
        args=["docker","exec",container,"psql","-X","-qAt","-v","ON_ERROR_STOP=1",
            "-U","prelaunch_restore","-d",database,
            "-c","BEGIN READ ONLY; "+statement+"; COMMIT;"]
    raw=run(args,label="readonly_sql").decode().strip()
    return json.loads(raw) if raw else None

def private_directory(path):
    path.mkdir(mode=0o700,parents=True,exist_ok=False)

def file_manifest(root):
    result={}
    for path in sorted(root.rglob("*")):
        if path.is_symlink():raise ValueError("Storage contains symbolic link")
        if path.is_dir():continue
        if not path.is_file():raise ValueError("Storage contains special file")
        digest=hashlib.sha256()
        with path.open("rb") as source:
            for chunk in iter(lambda:source.read(1024*1024),b""):digest.update(chunk)
        result[path.relative_to(root).as_posix()]={"size":path.stat().st_size,"sha256":digest.hexdigest()}
    return result

def aggregate_manifest(manifest,key):
    value=json.dumps(manifest,sort_keys=True,separators=(",",":")).encode()
    return hmac.new(key,value,hashlib.sha256).hexdigest()

def record_digest(rows,key):
    # Sort only top-level records; order inside a business JSON array remains meaningful.
    records=sorted(json.dumps(row,sort_keys=True,separators=(",",":")) for row in rows)
    return aggregate_manifest(records,key)

def snapshot_difference(source,restored):
    names=set(source["tables"])|set(restored["tables"])
    changed=[name for name in sorted(names) if source["tables"].get(name)!=restored["tables"].get(name)]
    order_only=[name for name in changed if name in source["tables"] and name in restored["tables"]
        and source["tables"][name]["rows"]==restored["tables"][name]["rows"]
        and source["tables"][name]["unordered_hmac"]==restored["tables"][name]["unordered_hmac"]]
    components=[name for name in ("sequences","constraints","indexes","columns","enums","views","functions","triggers","revision") if source.get(name)!=restored.get(name)]
    raw_source=source.get("raw_schema_order",{});raw_restore=restored.get("raw_schema_order",{})
    schema_order_only=[name for name in ("constraints","indexes")
        if name in raw_source and name in raw_restore and raw_source[name]!=raw_restore[name] and source[name]==restored[name]]
    return {"tables_different":len(changed),"tables_order_only":len(order_only),
        "tables_with_content_difference":sorted(set(changed)-set(order_only)),"different_components":components,
        "schema_order_only":schema_order_only}

def comparable_snapshot(snapshot):
    return {name:value for name,value in snapshot.items() if name!="raw_schema_order"}

def owned_resource_names(resources):
    suffixes=set()
    for kind in ("pg","net","volume"):
        value=resources.get(kind,"")
        match=re.fullmatch(re.escape(PREFIX+kind+"_")+r"(\d{8}T\d{6}Z_[0-9a-f]{6})",value)
        if not match:raise ValueError("Unowned cleanup resource")
        suffixes.add(match[1])
    if len(suffixes)!=1:raise ValueError("Mixed cleanup ownership")

def resource_names(kind):
    args={"pg":["docker","container","ls","-a"],"net":["docker","network","ls"],"volume":["docker","volume","ls"]}[kind]
    return set(run(args+["--format","{{.Names}}" if kind=="pg" else "{{.Name}}"],label="resource_inventory").decode().splitlines())

def ensure_resources_absent(resources):
    owned_resource_names(resources)
    for kind in ("pg","net","volume"):
        if resources[kind] in resource_names(kind):raise RuntimeError("Owned resource name already exists")

def cleanup_owned(resources):
    owned_resource_names(resources)
    success=True
    for kind in ("pg","volume","net"):
        if resources[kind] in resource_names(kind):
            args={"pg":["docker","rm","-f"],"volume":["docker","volume","rm"],"net":["docker","network","rm"]}[kind]
            success=(subprocess.run(args+[resources[kind]],capture_output=True).returncode==0) and success
        success=(resources[kind] not in resource_names(kind)) and success
    return success

def safe_extract(archive,destination):
    root=destination.resolve()
    with tarfile.open(archive,"r:gz") as bundle:
        for item in bundle.getmembers():
            name=PurePosixPath(item.name)
            if name.is_absolute() or ".." in name.parts:raise ValueError("Unsafe archive path")
            if not item.isdir() and not item.isfile():raise ValueError("Archive links and special files are refused")
            path=(root/item.name).resolve()
            if path!=root and root not in path.parents:raise ValueError("Archive escapes destination")
        bundle.extractall(root,filter="data")

def database_snapshot(container,key,*,production=False):
    tables=sql(container,"SELECT coalesce(json_agg(tablename ORDER BY tablename),'[]'::json) FROM pg_tables WHERE schemaname='public'",production=production)
    state={}
    for name in tables:
        rows=sql(container,"SELECT coalesce(json_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::json) FROM public."+quote_identifier(name)+" t",production=production)
        state[name]={"rows":len(rows),"hmac":record_digest(rows,key),"unordered_hmac":record_digest(rows,key)}
    sequences=sql(container,"SELECT coalesce(json_agg(sequencename ORDER BY sequencename),'[]'::json) FROM pg_sequences WHERE schemaname='public'",production=production)
    seq={}
    for name in sequences:
        seq[name]=sql(container,"SELECT row_to_json(t) FROM (SELECT last_value,is_called FROM public."+quote_identifier(name)+") t",production=production)
    schema=schema_snapshot(container,key,production=production)
    revision=sql(container,"SELECT to_json(version_num) FROM alembic_version",production=production)
    return {"tables":state,"sequences":aggregate_manifest(seq,key),"revision":revision,
        **schema,"raw_schema_order":{}}

def schema_snapshot(container,key,*,production=False,database="enactspace_pr2b_test_restore"):
    # Compare complete definitions, reparsed independently by the same isolated server.
    # No SQL regex normalization and no discarded literals, casts or predicates.
    queries={
        "constraints":"SELECT c.conrelid::regclass::text AS rel,c.conname AS name,pg_get_constraintdef(c.oid) AS definition,c.convalidated AS validated FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace WHERE n.nspname='public'",
        "indexes":"SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname='public'",
        "columns":"SELECT c.relname AS rel,a.attname AS name,a.attnum AS position,format_type(a.atttypid,a.atttypmod) AS type,a.attnotnull AS required,a.attidentity AS identity,a.attgenerated AS generated,pg_get_expr(d.adbin,d.adrelid) AS default_expression,coll.collname AS collation FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum LEFT JOIN pg_collation coll ON coll.oid=a.attcollation WHERE n.nspname='public' AND c.relkind IN ('r','p','v','m') AND a.attnum>0 AND NOT a.attisdropped",
        "enums":"SELECT t.typname,e.enumlabel,e.enumsortorder FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace JOIN pg_enum e ON e.enumtypid=t.oid WHERE n.nspname='public'",
        "views":"SELECT c.relname,c.relkind,pg_get_viewdef(c.oid) AS definition FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN ('v','m')",
        "functions":"SELECT p.proname,pg_get_function_identity_arguments(p.oid) AS arguments,pg_get_functiondef(p.oid) AS definition FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind IN ('f','p')",
        "triggers":"SELECT c.relname,t.tgname,t.tgenabled,pg_get_triggerdef(t.oid) AS definition FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND NOT t.tgisinternal",
    }
    return {name:record_digest(sql(container,"SELECT coalesce(json_agg(to_jsonb(t)),'[]'::json) FROM ("+query+") t",
        production=production,database=database),key) for name,query in queries.items()}

def expected_restored_snapshot(source,reference_schema):
    expected=comparable_snapshot(source)
    if set(reference_schema)!=SCHEMA_COMPONENTS or not SCHEMA_COMPONENTS.issubset(expected):
        raise ValueError("Incomplete or unexpected reference schema component")
    expected.update(reference_schema)
    return expected

def reference_sql(container,statement):
    # Writes permitted only to the schema-only reference DB in this rehearsal container.
    if not re.fullmatch(re.escape(PREFIX+"pg_")+r"\d{8}T\d{6}Z_[0-9a-f]{6}",container):
        raise ValueError("Unowned reference container")
    run(["docker","exec",container,"psql","-X","-qAt","-v","ON_ERROR_STOP=1",
        "-U","prelaunch_restore","-d","enactspace_pr2b_test_schema","-c",statement],
        label="isolated_synthetic_schema_check")

def verify_schema_change_detection(container,key):
    table="prelaunch_lot26_synthetic_schema_check"
    reference_sql(container,"CREATE TABLE "+table+" (status varchar NOT NULL, CONSTRAINT prelaunch_synthetic_status CHECK (status IN ('ready','done'))); CREATE UNIQUE INDEX prelaunch_synthetic_index ON "+table+" (status) WHERE status='ready'")
    detected=[]
    try:
        for component,statement in (
            ("constraints","ALTER TABLE "+table+" DROP CONSTRAINT prelaunch_synthetic_status; ALTER TABLE "+table+" ADD CONSTRAINT prelaunch_synthetic_status CHECK (status IN ('ready','changed'))"),
            ("indexes","DROP INDEX prelaunch_synthetic_index; CREATE UNIQUE INDEX prelaunch_synthetic_index ON "+table+" (status) WHERE status='changed'"),
            ("columns","ALTER TABLE "+table+" ALTER COLUMN status DROP NOT NULL"),
        ):
            before=schema_snapshot(container,key,database="enactspace_pr2b_test_schema")
            reference_sql(container,statement)
            after=schema_snapshot(container,key,database="enactspace_pr2b_test_schema")
            if before[component]==after[component]:raise RuntimeError("Schema_change_detection_failed")
            detected.append(component)
    finally:
        reference_sql(container,"DROP TABLE "+table)
    return detected

def restore_dump(container,source,database="enactspace_pr2b_test_restore"):
    if not container.startswith(PREFIX) or database not in {"enactspace_pr2b_test_restore","enactspace_pr2b_test_schema"}:
        raise ValueError("Unsafe restore target")
    with source.open("rb") as stream:
        restored=subprocess.run(["docker","exec","-i",container,"pg_restore","--exit-on-error",
            "--no-owner","--no-privileges","-U","prelaunch_restore","-d",database],
            stdin=stream,capture_output=True,timeout=120)
    if restored.returncode:raise RuntimeError("isolated_database_restore_failed")

def encrypt_stream(command,target,key):
    temporary=target.with_suffix(target.suffix+".partial")
    producer=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
    try:
        encrypted=subprocess.run(["gpg","--batch","--yes","--no-symkey-cache","--pinentry-mode","loopback",
            "--passphrase-file",str(key),"--cipher-algo","AES256","--symmetric","--output",str(temporary)],
            stdin=producer.stdout,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=180)
        producer.stdout.close()
        if producer.wait(timeout=30) or encrypted.returncode:raise RuntimeError("encrypted_backup_failed")
        os.chmod(temporary,0o600);temporary.replace(target)
    finally:
        if producer.poll() is None:producer.kill();producer.wait()
        temporary.unlink(missing_ok=True)

def decrypt_file(source,destination,key):
    result=subprocess.run(["gpg","--batch","--yes","--no-symkey-cache","--pinentry-mode","loopback",
        "--passphrase-file",str(key),"--output",str(destination),"--decrypt",str(source)],
        stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=180)
    if result.returncode:
        destination.unlink(missing_ok=True)
        raise RuntimeError("backup_integrity_failed")
    os.chmod(destination,0o600)

def check_stored_files(container,restored):
    rows=sql(container,"SELECT coalesce(json_agg(json_build_object('path',storage_path,'size',file_size,'checksum',checksum)),'[]'::json) FROM stored_files")
    counts={"records":len(rows),"missing":0,"wrong_size":0,"wrong_hash":0,"unsafe_path":0}
    root=(restored/"files").resolve()
    for item in rows:
        path=(root/item["path"]).resolve()
        if path==root or root not in path.parents:counts["unsafe_path"]+=1;continue
        if not path.is_file():counts["missing"]+=1;continue
        if path.stat().st_size!=item["size"]:counts["wrong_size"]+=1
        if item["checksum"] and hashlib.sha256(path.read_bytes()).hexdigest()!=item["checksum"]:counts["wrong_hash"]+=1
    return counts

def execute_rehearsal(expected_revision="20261006_0025"):
    if not re.fullmatch(r"\d{8}_\d{4}",expected_revision):raise ValueError("Invalid expected revision")
    if os.name!="posix":raise RuntimeError("Linux Docker host required")
    started=time.monotonic()
    identifier=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")+"_"+secrets.token_hex(3)
    resources={name:PREFIX+name+"_"+identifier for name in ("pg","net","volume")}
    stage=STAGE_ROOT/("prelaunch-lot26-"+identifier);backup=BACKUP_ROOT/("prelaunch-lot26-"+identifier)
    KEY_ROOT.mkdir(mode=0o700,parents=True,exist_ok=True)
    if KEY_ROOT.is_symlink() or (KEY_ROOT.stat().st_mode & 0o077):raise RuntimeError("Backup key directory must be private")
    private_directory(stage);private_directory(backup)
    key_file=KEY_ROOT/(identifier+".key")
    fd=os.open(key_file,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,"wb") as key:key.write(secrets.token_hex(32).encode())
    verification_key=key_file.read_bytes()
    result={"backup_id":identifier,"production_changed":False,"application_or_workers_started":False,
        "real_emails_sent":0,"real_push_sent":0,"real_payments":0,
        "backup_scope":"PostgreSQL and persistent application uploads; not full VPS or release artifacts",
        "encrypted":True,"offsite_copy_verified":False,"key_recovery_offsite_verified":False}
    failure=None;owns_resources=False
    try:
        ensure_resources_absent(resources)
        owns_resources=True
        mounts=json.loads(run(["docker","inspect","enactspace_backend"],label="storage_inspection"))[0]["Mounts"]
        if not any(m["Destination"]=="/app/uploads" and Path(m["Source"])==UPLOADS for m in mounts):raise RuntimeError("Storage mount mismatch")
        initial_files=file_manifest(UPLOADS)
        if shutil.disk_usage(STAGE_ROOT).free<=sum(x["size"] for x in initial_files.values())*4+1024**3:raise RuntimeError("Insufficient private staging storage")
        initial_db=database_snapshot(PRODUCTION_DB,verification_key,production=True)
        if initial_db["revision"]!=expected_revision:raise RuntimeError("Unexpected production revision")
        encrypt_stream(["docker","exec",PRODUCTION_DB,"sh","-c",
            'exec pg_dump -Fc --no-owner --no-privileges --username="$POSTGRES_USER" --dbname="$POSTGRES_DB"'],
            backup/"database.dump.gpg",key_file)
        encrypt_stream(["docker","exec",PRODUCTION_DB,"sh","-c",
            'exec pg_dump -Fc --schema-only --no-owner --no-privileges --username="$POSTGRES_USER" --dbname="$POSTGRES_DB"'],
            backup/"schema-reference.dump.gpg",key_file)
        encrypt_stream(["tar","-C",str(UPLOADS),"-czf","-","."],backup/"uploads.tar.gz.gpg",key_file)
        if database_snapshot(PRODUCTION_DB,verification_key,production=True)!=initial_db or file_manifest(UPLOADS)!=initial_files:
            raise RuntimeError("Source_changed_during_capture_rehearsal_not_accepted")
        result["source_stable_during_capture"]=True
        run(["docker","network","create","--internal",resources["net"]],label="isolated_network")
        run(["docker","volume","create",resources["volume"]],label="isolated_volume")
        run(["docker","run","-d","--name",resources["pg"],"--network",resources["net"],
            "--mount","type=volume,src="+resources["volume"]+",dst=/var/lib/postgresql/data",
            "-e","POSTGRES_USER=prelaunch_restore","-e","POSTGRES_PASSWORD=isolated-disposable-test-only",
            "-e","POSTGRES_DB=enactspace_pr2b_test_restore","postgres:16-alpine"],label="isolated_postgres")
        for _ in range(45):
            ready=subprocess.run(["docker","exec",resources["pg"],"pg_isready","-h","127.0.0.1",
                "-U","prelaunch_restore","-d","enactspace_pr2b_test_restore"],capture_output=True)
            if ready.returncode==0:break
            time.sleep(.3)
        else:raise RuntimeError("isolated_postgres_not_ready")
        plain_dump=stage/"database.dump";plain_files=stage/"uploads.tar.gz"
        decrypt_file(backup/"database.dump.gpg",plain_dump,key_file);decrypt_file(backup/"uploads.tar.gz.gpg",plain_files,key_file)
        restore_dump(resources["pg"],plain_dump)
        reference_dump=stage/"schema-reference.dump"
        decrypt_file(backup/"schema-reference.dump.gpg",reference_dump,key_file)
        run(["docker","exec",resources["pg"],"createdb","-U","prelaunch_restore",
            "enactspace_pr2b_test_schema"],label="isolated_reference_database")
        restore_dump(resources["pg"],reference_dump,"enactspace_pr2b_test_schema")
        result["synthetic_schema_changes_detected"]=verify_schema_change_detection(resources["pg"],verification_key)
        reference_schema=schema_snapshot(resources["pg"],verification_key,database="enactspace_pr2b_test_schema")
        expected_db=expected_restored_snapshot(initial_db,reference_schema)
        result["schema_comparison_method"]="Independent source schema-only capture reparsed by the same isolated PostgreSQL server"
        result["restore_image_id"]=run(["docker","inspect","--format","{{.Image}}",resources["pg"]],
            label="isolated_image_identity").decode().strip()
        verification=stage/"verification.json"
        verification.write_text(json.dumps({"expected_snapshot":expected_db,"files":initial_files,
            "production_revision":initial_db["revision"],"restore_image_id":result["restore_image_id"],
            "schema_comparison_method":result["schema_comparison_method"]},sort_keys=True)+"\n")
        os.chmod(verification,0o600)
        encrypt_stream(["cat",str(verification)],backup/"verification.json.gpg",key_file)
        verified_manifest=stage/"verification-readback.json"
        decrypt_file(backup/"verification.json.gpg",verified_manifest,key_file)
        if verified_manifest.read_bytes()!=verification.read_bytes():raise RuntimeError("Verification_manifest_roundtrip_failed")
        result["encrypted_point_in_time_verification_manifest"]=True

        target=stage/"uploads";private_directory(target);safe_extract(plain_files,target)
        restored_db=database_snapshot(resources["pg"],verification_key)
        result["comparison_diagnostic"]=snapshot_difference(expected_db,restored_db)
        if comparable_snapshot(restored_db)!=expected_db:raise RuntimeError("Restored database differs")
        if file_manifest(target)!=initial_files:raise RuntimeError("Restored uploads differ")
        linked=check_stored_files(resources["pg"],target)
        result.update(database_tables=len(initial_db["tables"]),database_rows=sum(x["rows"] for x in initial_db["tables"].values()),
            database_content_equal=True,sequences_equal=True,constraints_equal=True,indexes_equal=True,
            columns_equal=True,enums_equal=True,views_equal=True,functions_equal=True,triggers_equal=True,
            files_count=len(initial_files),files_bytes=sum(x["size"] for x in initial_files.values()),files_content_equal=True,
            stored_file_check=linked,production_revision=initial_db["revision"],schema_backup_restored=True,
            restore_seconds=round(time.monotonic()-started,3))
        result["passed"]=all(linked[x]==0 for x in ("missing","wrong_size","wrong_hash","unsafe_path"))
        for name in ("database.dump.gpg","schema-reference.dump.gpg","uploads.tar.gz.gpg","verification.json.gpg"):
            result.setdefault("encrypted_archives",{})[name]={"bytes":(backup/name).stat().st_size,
                "sha256":hashlib.sha256((backup/name).read_bytes()).hexdigest()}
        if not result["passed"]:raise RuntimeError("Restored_reference_consistency_failed")
    except Exception as exc:
        failure=exc;result["passed"]=False
        result["failure"]=str(exc) if isinstance(exc,(RuntimeError,AssertionError)) else type(exc).__name__
    finally:
        try:cleaned=cleanup_owned(resources) if owns_resources else True
        except Exception:cleaned=False
        if stage.exists():shutil.rmtree(stage)
        result["owned_test_resources_removed"]=cleaned;result["decrypted_staging_removed"]=not stage.exists()
        result["finished_at"]=datetime.now(timezone.utc).isoformat()
        (backup/"rehearsal.json").write_text(json.dumps(result,indent=2)+"\n");os.chmod(backup/"rehearsal.json",0o600)
        print(json.dumps(result),flush=True)
    if failure or not result.get("passed") or not result["owned_test_resources_removed"]:raise SystemExit(1)

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--execute-rehearsal",action="store_true")
    parser.add_argument("--expected-revision",default="20261006_0025")
    args=parser.parse_args()
    if not args.execute_rehearsal:parser.error("Explicit --execute-rehearsal is required")
    execute_rehearsal(args.expected_revision)
