"""Windows-only encrypted offsite backup and isolated recovery rehearsal."""
from __future__ import annotations
import argparse,base64,ctypes,hashlib,json,os,re,secrets,subprocess,sys,tarfile,time
from ctypes import wintypes
from datetime import datetime,timezone
from pathlib import Path
ARCHIVES={"database.dump.gpg","schema-reference.dump.gpg","uploads.tar.gz.gpg","verification.json.gpg"}
SSH=Path(r"C:\Program Files\Git\usr\bin\ssh.exe")
SCP=Path(r"C:\Program Files\Git\usr\bin\scp.exe")
def run(args,*,input=None,timeout=60,label="operation"):
    result=subprocess.run([str(x) for x in args],input=input,capture_output=True,timeout=timeout)
    if result.returncode:raise RuntimeError(label+"_failed")
    return result.stdout
def powershell(script):
    encoded=base64.b64encode(script.encode("utf-16le")).decode()
    return run(["powershell","-NoProfile","-NonInteractive","-EncodedCommand",encoded],label="private_windows_access")
def private_directory(path):
    path.mkdir(parents=True,exist_ok=True)
    if any(parent.is_symlink() or parent.is_junction() for parent in [path,*path.parents]):raise ValueError("Private directory cannot be a link")
    sid=powershell("[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value").decode().strip()
    if not re.fullmatch(r"S-\d+(?:-\d+)+",sid):raise ValueError("Unexpected Windows identity")
    run(["icacls",path,"/inheritance:r","/grant:r","*"+sid+":(OI)(CI)F","*S-1-5-18:(OI)(CI)F"],label="restrict_windows_directory")
    escaped=str(path).replace("'","''")
    check=powershell("$a=Get-Acl -LiteralPath '"+escaped+"'; $rules=$a.GetAccessRules($true,$true,[System.Security.Principal.SecurityIdentifier]); $bad=@($rules | Where-Object { $_.IdentityReference.Value -notin @('"+sid+"','S-1-5-18') -or $_.AccessControlType -ne 'Allow' }); ($a.AreAccessRulesProtected -and $bad.Count -eq 0) | ConvertTo-Json -Compress")
    if json.loads(check)!=True:raise RuntimeError("Private_windows_acl_verification_failed")
def dpapi(value,*,decrypt=False):
    if os.name!="nt":raise ValueError("Windows profile protection required")
    class Blob(ctypes.Structure):
        _fields_=[("size",wintypes.DWORD),("data",ctypes.POINTER(ctypes.c_ubyte))]
    def make(data):
        buffer=(ctypes.c_ubyte*len(data)).from_buffer_copy(data)
        return Blob(len(data),ctypes.cast(buffer,ctypes.POINTER(ctypes.c_ubyte))),buffer
    source,source_buffer=make(value);entropy,entropy_buffer=make(b"EnactSpace backup recovery v1")
    output=Blob();description=ctypes.c_wchar_p()
    crypto=ctypes.WinDLL("crypt32",use_last_error=True);kernel=ctypes.WinDLL("kernel32",use_last_error=True)
    kernel.LocalFree.argtypes=[ctypes.c_void_p];kernel.LocalFree.restype=ctypes.c_void_p
    if decrypt:
        operation=crypto.CryptUnprotectData
        operation.argtypes=[ctypes.POINTER(Blob),ctypes.POINTER(ctypes.c_wchar_p),ctypes.POINTER(Blob),ctypes.c_void_p,ctypes.c_void_p,wintypes.DWORD,ctypes.POINTER(Blob)]
        second=ctypes.byref(description)
    else:
        operation=crypto.CryptProtectData
        operation.argtypes=[ctypes.POINTER(Blob),ctypes.c_wchar_p,ctypes.POINTER(Blob),ctypes.c_void_p,ctypes.c_void_p,wintypes.DWORD,ctypes.POINTER(Blob)]
        second="EnactSpace recovery key"
    operation.restype=wintypes.BOOL
    if not operation(ctypes.byref(source),second,ctypes.byref(entropy),None,None,1,ctypes.byref(output)):
        raise RuntimeError("Windows_profile_key_protection_failed")
    try:return ctypes.string_at(output.data,output.size)
    finally:
        kernel.LocalFree(ctypes.cast(output.data,ctypes.c_void_p))
        if decrypt and description:kernel.LocalFree(ctypes.cast(description,ctypes.c_void_p))
def execute(identity,repo,*,restore_existing=False):
    if os.name!="nt" or not re.fullmatch(r"\d{8}T\d{6}Z_[0-9a-f]{6}",identity):raise ValueError("Invalid recovery context")
    base=Path(os.environ["LOCALAPPDATA"])/"EnactSpace"
    archive_root=base/"PrivateBackups";key_root=base/"RecoveryKeys"
    private_directory(archive_root);private_directory(key_root)
    local=archive_root/identity
    protected_key=key_root/(identity+".dpapi")
    source="/var/backups/enactspace/prelaunch-lot26-"+identity
    if restore_existing:
        if not local.is_dir() or local.is_symlink() or local.is_junction() or not protected_key.is_file() or protected_key.is_symlink():
            raise ValueError("Existing private recovery copy required")
    else:
        if local.exists() or protected_key.exists():raise ValueError("Offsite copy already exists; use explicit restore-existing")
        private_directory(local)
        for name in sorted(ARCHIVES|{"rehearsal.json"}):
            partial=local/(name+".partial")
            run([SCP,"-S",SSH,"-o","BatchMode=yes","vps:"+source+"/"+name,partial],label="offsite_encrypted_copy")
            partial.replace(local/name)
    receipt=json.loads((local/"rehearsal.json").read_text(encoding="utf-8"))
    if receipt.get("backup_id")!=identity or receipt.get("passed") is not True or set(receipt.get("encrypted_archives",{}))!=ARCHIVES:
        raise ValueError("Unexpected source receipt")
    for name in ARCHIVES:
        raw=(local/name).read_bytes();expected=receipt["encrypted_archives"][name]
        if len(raw)!=expected["bytes"] or hashlib.sha256(raw).hexdigest()!=expected["sha256"]:
            raise RuntimeError("Offsite_copy_checksum_mismatch")
    if restore_existing:
        recovered=dpapi(protected_key.read_bytes(),decrypt=True)
        if not re.fullmatch(b"[0-9a-f]{64}",recovered):raise ValueError("Invalid recovered key")
    else:
        raw_key=run([SSH,"-o","BatchMode=yes","vps","cat /opt/enactspace/backup-keys/"+identity+".key"],label="private_key_transfer")
        if not re.fullmatch(b"[0-9a-f]{64}",raw_key):raise ValueError("Unexpected recovery key")
        with protected_key.open("xb") as file:file.write(dpapi(raw_key))
        recovered=dpapi(protected_key.read_bytes(),decrypt=True)
        if recovered!=raw_key:raise RuntimeError("Windows_key_recovery_mismatch")
        del raw_key
    sid=powershell("[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value").decode().strip()
    paths=[local/name for name in sorted(ARCHIVES|{"rehearsal.json"})]+[protected_key]
    literals=",".join("'"+str(path).replace("'","''")+"'" for path in paths)
    checked=powershell("$ok=$true; foreach($p in @("+literals+")) { $a=Get-Acl -LiteralPath $p; $bad=@($a.GetAccessRules($true,$true,[System.Security.Principal.SecurityIdentifier]) | Where-Object { $_.IdentityReference.Value -notin @('"+sid+"','S-1-5-18') -or $_.AccessControlType -ne 'Allow' }); if($bad.Count -ne 0) {$ok=$false} }; $ok | ConvertTo-Json -Compress")
    if json.loads(checked)!=True:raise RuntimeError("Private_windows_file_acl_verification_failed")
    result={"backup_id":identity,"offsite_copy_verified":True,"offsite_location":"authorized Windows PC",
        "restored_existing_copy":restore_existing,"original_vps_key_read_this_run":not restore_existing,
        "windows_file_acls_verified":True,"windows_archive_acl_verified":True,"windows_key_directory_acl_verified":True,
        "windows_profile_key_roundtrip_verified":True,"key_protection":"Windows DPAPI CurrentUser",
        "second_key_custodian_verified":False,"production_changed":False,"build_performed":False,"deployment_performed":False}
    attempt=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")+"_"+secrets.token_hex(3)
    stage="/opt/enactspace/staging/prelaunch-lot26-offsite-"+attempt
    created=False;failure=None
    try:
        run([SSH,"-o","BatchMode=yes","vps","umask 077; mkdir -m 700 "+stage],label="private_return_staging")
        created=True
        for name in sorted(ARCHIVES|{"rehearsal.json"}):
            run([SCP,"-S",SSH,"-o","BatchMode=yes",local/name,"vps:"+stage+"/"+name],label="return_offsite_archive")
        backend=repo/"backend"
        tools=local/"source-tools.tar.gz"
        with tarfile.open(tools,"w:gz") as bundle:
            for name in ("app/scripts/prelaunch_backup_restore.py","app/scripts/prelaunch_offsite_restore.py"):
                code=(backend/name).read_text(encoding="utf-8");compile(code,name,"exec")
                bundle.add(backend/name,arcname=name)
        run([SCP,"-S",SSH,"-o","BatchMode=yes",tools,"vps:"+stage+"/source-tools.tar.gz"],label="return_recovery_tools")
        command="umask 077; cd "+stage+" && chmod 600 *.gpg rehearsal.json source-tools.tar.gz && tar -xzf source-tools.tar.gz && python3 -m app.scripts.prelaunch_offsite_restore --execute-offsite-rehearsal --backup-id "+identity+" --archive-dir "+stage
        output=run([SSH,"-o","BatchMode=yes","vps",command],input=recovered,timeout=240,label="offsite_restore")
        restored=json.loads(output)
        result["restoration"]=restored
        if not restored.get("passed"):raise RuntimeError("Offsite_restore_not_verified")
        result["offsite_restore_verified"]=True
    except Exception as exc:
        failure=exc;result["offsite_restore_verified"]=False
        result["failure"]=str(exc) if isinstance(exc,RuntimeError) else type(exc).__name__
    finally:
        del recovered
        removed=False
        if created:
            cleanup=subprocess.run([str(SSH),"-o","BatchMode=yes","vps","rm -rf -- "+stage+" && test ! -e "+stage],capture_output=True,timeout=45)
            removed=cleanup.returncode==0
        result["private_return_staging_removed"]=removed
        result["finished_at"]=datetime.now(timezone.utc).isoformat()
        (local/"offsite-rehearsal.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
        print(json.dumps(result),flush=True)
    if failure or not result.get("offsite_restore_verified") or not result["private_return_staging_removed"]:raise SystemExit(1)
if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute-offsite-rehearsal",action="store_true")
    parser.add_argument("--restore-existing",action="store_true")
    parser.add_argument("--backup-id",required=True)
    parser.add_argument("--repo",type=Path,required=True)
    args=parser.parse_args()
    if not args.execute_offsite_rehearsal:parser.error("Explicit rehearsal opt-in required")
    execute(args.backup_id,args.repo,restore_existing=args.restore_existing)
