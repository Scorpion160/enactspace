"""Portable backup-key escrow: user-entered secret, no secret output."""
import argparse,getpass,json,os,re,secrets,shutil,subprocess
from pathlib import Path
import prelaunch_offsite_recovery as windows
GPG=Path(r"C:\Program Files\Git\usr\bin\gpg.exe")
def crypt(value,phrase,root,*,decrypt=False):
    if not phrase or len(phrase)<20:raise ValueError("Use a recovery passphrase of at least twenty characters")
    work=root/("private-escrow-work-"+secrets.token_hex(6));windows.private_directory(work)
    try:
        home=work/"gpg";windows.private_directory(home)
        passfile=work/"passphrase";passfile.write_bytes(phrase.encode("utf-8"))
        args=[str(GPG),"--homedir","/"+home.drive[0].lower()+home.as_posix()[2:],"--batch","--yes","--no-symkey-cache","--pinentry-mode","loopback",
            "--passphrase-file","/"+passfile.drive[0].lower()+passfile.as_posix()[2:],"--output","-"]
        args+=["--decrypt"] if decrypt else ["--cipher-algo","AES256","--symmetric"]
        output=windows.run(args,input=value,label="portable_key_encryption")
        return output
    finally:
        # All plaintext passphrase material is within the private owned work folder.
        configuration=GPG.with_name("gpgconf.exe")
        if configuration.is_file():subprocess.run([str(configuration),"--homedir","/"+work.drive[0].lower()+(work/"gpg").as_posix()[2:],"--kill","all"],capture_output=True,timeout=10)
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
