"""Portable backup-key escrow: user-entered secret, no secret output."""
import argparse,getpass,json,os,re,secrets,shutil,subprocess
from pathlib import Path
import prelaunch_offsite_recovery as windows
GPG=Path(r"C:\Program Files\Git\usr\bin\gpg.exe")
def crypt(value,phrase,root,*,decrypt=False):
    if not phrase or len(phrase)<20 or any(c in phrase for c in "\r\n\0"):
        raise ValueError("Use a single-line recovery passphrase of at least twenty characters")
    work=root/("work-"+secrets.token_hex(6))
    # On Windows, Python 3.12 mode 0700 adds an explicit Administrators
    # rule. Inherit the already-private parent, then verify user/SYSTEM ACLs.
    work.mkdir(mode=0o777 if os.name=="nt" else 0o700,exist_ok=False)
    try:
        windows.private_directory(work)
        home=work/"gpg";windows.private_directory(home)
        passfile=work/"passphrase";passfile.write_bytes(phrase.encode("utf-8"))
        # Windows diagnostic verified this mode. Resolve both paths in the same
        # owned workspace instead of converting Windows drive letters to MSYS.
        args=[str(GPG),"--no-options","--homedir","gpg","--batch","--yes","--no-tty",
            "--no-symkey-cache","--pinentry-mode","loopback","--passphrase-file","passphrase","--output","-"]
        args+=["--decrypt"] if decrypt else ["--cipher-algo","AES256","--symmetric"]
        environment=os.environ.copy();environment["LC_ALL"]="C"
        result=subprocess.run(args,input=value,cwd=work,capture_output=True,env=environment,timeout=60)
        if result.returncode:
            category=""
            diagnostic=result.stderr.decode("utf-8",errors="replace").lower()
            if "agent" in diagnostic and ("failed to start" in diagnostic or "can't connect" in diagnostic or "no agent running" in diagnostic):category=": AGENT_START_OR_CONNECTION_FAILED"
            elif "invalid option" in diagnostic or "unknown option" in diagnostic:category=": UNSUPPORTED_OPTION"
            elif "passphrase" in diagnostic and ("no such file" in diagnostic or "cannot open" in diagnostic):category=": PASSPHRASE_FILE_UNAVAILABLE"
            raise RuntimeError(("portable_key_decryption_failed" if decrypt else "portable_key_encryption_failed")+category)
        return result.stdout
    finally:
        # Stop only the agent associated with this owned home directory.
        configuration=GPG.with_name("gpgconf.exe")
        try:
            if configuration.is_file() and (work/"gpg").is_dir():
                subprocess.run([str(configuration),"--homedir","gpg","--kill","all"],cwd=work,capture_output=True,timeout=10)
        finally:
            shutil.rmtree(work)
def validate_payload(raw,identity):
    value=json.loads(raw)
    if value.get("version")!=1 or value.get("backup_id")!=identity or not re.fullmatch(r"[0-9a-f]{64}",value.get("key","")):
        raise ValueError("Unexpected escrow payload")
    return value["key"].encode()
def execute(identity,*,import_file=None):
    if os.name!="nt" or not re.fullmatch(r"\d{8}T\d{6}Z_[0-9a-f]{6}",identity):raise ValueError("Invalid escrow context")
    base=Path(os.environ["LOCALAPPDATA"])/"EnactSpace"
    keys=base/"RecoveryKeys";root=base/"KeyEscrow"
    windows.private_directory(keys);windows.private_directory(root)
    protected=keys/(identity+".dpapi")
    phrase=getpass.getpass("Phrase secrète de récupération (saisie masquée, au moins 20 caractères) : ")
    if import_file:
        if protected.exists():raise ValueError("Existing protected key must not be overwritten")
        key=validate_payload(crypt(import_file.read_bytes(),phrase,root,decrypt=True),identity)
        with protected.open("xb") as file:file.write(windows.dpapi(key))
        if windows.dpapi(protected.read_bytes(),decrypt=True)!=key:raise RuntimeError("Imported_key_roundtrip_failed")
        print(json.dumps({"backup_id":identity,"key_imported_into_current_windows_profile":True,"secret_printed":False}))
    else:
        if phrase!=getpass.getpass("Confirmez la phrase secrète : "):raise ValueError("Recovery phrases differ")
        if not protected.is_file() or protected.is_symlink():raise ValueError("Existing protected recovery key required")
        target=root/(identity+".key-escrow.gpg")
        if target.exists():raise ValueError("Existing escrow must not be overwritten")
        key=windows.dpapi(protected.read_bytes(),decrypt=True)
        payload=json.dumps({"version":1,"backup_id":identity,"key":key.decode()}).encode()
        encrypted=crypt(payload,phrase,root)
        if validate_payload(crypt(encrypted,phrase,root,decrypt=True),identity)!=key:raise RuntimeError("Escrow_roundtrip_failed")
        with target.open("xb") as file:file.write(encrypted)
        print(json.dumps({"backup_id":identity,"portable_encrypted_key_created":True,"secret_printed":False,
            "external_support_and_second_custodian_verified":False}))
if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute-key-escrow",action="store_true");parser.add_argument("--backup-id",required=True)
    parser.add_argument("--import-file",type=Path)
    args=parser.parse_args()
    if not args.execute_key_escrow:parser.error("Explicit key escrow opt-in required")
    execute(args.backup_id,import_file=args.import_file)
