"""Publish a filtered working-tree checkpoint without changing the user's index."""
import argparse, hashlib, json, os, platform, re, shutil, subprocess, sys, time, urllib.request, zipfile
from datetime import datetime, timezone
from pathlib import Path
from generate_firebase_web_worker import parse_existing_worker

EXPECTED = "Scorpion160/enactspace"
VERSION = "8.30.1"
DENIED_DIRS = {".git", ".venv", "venv", ".dart_tool", ".gradle", "build", "node_modules", "__pycache__", "uploads", "private_import", "backups", "exports", "privatebackups", "recoverykeys", "keyescrow"}
DENIED_SUFFIXES = {".pem", ".key", ".p12", ".pfx", ".jks", ".keystore", ".gpg", ".dpapi", ".dump", ".db", ".sqlite", ".sqlite3", ".log", ".csv", ".xlsx", ".xls", ".zip", ".gz", ".tar", ".7z", ".bundle"}
NEW_ROOTS = {"backend", "frontend", "docs", "tools", "scripts", ".github"}
NEW_CODE = {".py", ".dart", ".md", ".json", ".yml", ".yaml", ".toml", ".txt", ".ps1", ".sh", ".sql", ".html", ".css", ".js", ".ts", ".xml", ".gradle", ".kts", ".kt", ".java", ".swift", ".m", ".h", ".service", ".timer", ".tex", ".svg"}
ARCHIVE_ASSETS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".ttf", ".otf", ".woff", ".woff2", ".pdf", ".mp3", ".mp4"}

def eligible(name, tracked):
    if name.replace("\\", "/") == "frontend/web/firebase-messaging-sw.js": return False
    parts = name.replace("\\", "/").split("/")
    lower = [part.lower() for part in parts]
    basename = lower[-1]
    if any(part in DENIED_DIRS for part in lower): return False
    if basename.startswith(".env") or "release-defines" in basename: return False
    if "before-model-registration-fix" in basename or basename.endswith((".bak", ".backup", ".tmp", ".partial")): return False
    if basename in {"credentials.json", "service-account.json", "service_account.json"} or "service-account-key" in basename: return False
    if Path(basename).suffix in DENIED_SUFFIXES: return False
    if tracked or name == ".gitignore": return True
    if parts[0] not in NEW_ROOTS: return False
    if Path(basename).suffix in NEW_CODE: return True
    return name.startswith("frontend/assets/") and Path(basename).suffix in ARCHIVE_ASSETS

def run(args, *, cwd=None, env=None, label="operation", timeout=180, input=None):
    result = subprocess.run([str(x) for x in args], cwd=cwd, env=env, input=input, capture_output=True, timeout=timeout)
    if result.returncode: raise RuntimeError(label + "_failed (aucun contenu sensible affiche)")
    return result.stdout

def private_dir(path):
    path.mkdir(parents=True, exist_ok=True)
    if any(p.is_symlink() or (hasattr(p, "is_junction") and p.is_junction()) for p in [path, *path.parents]):
        raise ValueError("Repertoire prive redirige : arret")
    if os.name == "nt":
        sid = run(["powershell", "-NoProfile", "-NonInteractive", "-Command", "[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value"], label="identite_windows").decode().strip()
        if not re.fullmatch(r"S-\d+(?:-\d+)+", sid): raise ValueError("Identite Windows inattendue")
        run(["icacls", path, "/inheritance:r", "/grant:r", "*"+sid+":(OI)(CI)F", "*S-1-5-18:(OI)(CI)F"], label="permissions_privees")
    else: path.chmod(0o700)

def download(url, destination):
    if not url.startswith("https://github.com/gitleaks/gitleaks/releases/download/v"+VERSION+"/"):
        raise ValueError("Source Gitleaks inattendue")
    request = urllib.request.Request(url, headers={"User-Agent": "EnactSpace-checkpoint"})
    with urllib.request.urlopen(request, timeout=60) as response, destination.open("wb") as target:
        shutil.copyfileobj(response, target)

def scanner(work):
    if os.name != "nt": raise RuntimeError("Execution de publication prevue sur le PC Windows")
    machine = platform.machine().lower()
    architecture = "arm64" if machine in {"arm64", "aarch64"} else "x64" if machine in {"amd64", "x86_64"} else None
    if not architecture: raise ValueError("Architecture Windows non prise en charge")
    filename = f"gitleaks_{VERSION}_windows_{architecture}.zip"
    base = f"https://github.com/gitleaks/gitleaks/releases/download/v{VERSION}/"
    archive, checksums = work/filename, work/"checksums.txt"
    download(base+filename, archive)
    download(base+f"gitleaks_{VERSION}_checksums.txt", checksums)
    match = next((line.split()[0] for line in checksums.read_text().splitlines() if line.split()[-1].lstrip("*") == filename), None)
    if not match or hashlib.sha256(archive.read_bytes()).hexdigest() != match:
        raise RuntimeError("Empreinte du programme Gitleaks incorrecte")
    with zipfile.ZipFile(archive) as bundle:
        matches = [name for name in bundle.namelist() if Path(name).name == "gitleaks.exe"]
        if len(matches) != 1: raise ValueError("Archive Gitleaks inattendue")
        executable = work/"gitleaks.exe"
        with bundle.open(matches[0]) as source, executable.open("wb") as target: shutil.copyfileobj(source, target)
    return executable

def fingerprint(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024*1024), b""): result.update(chunk)
    return result.hexdigest()

def execute(repo, publish=False):
    repo = repo.resolve()
    git = shutil.which("git") or r"C:\Program Files\Git\bin\git.exe"
    def gitrun(*args, env=None): return run([git, "-C", repo, *args], env=env, label="git_"+args[0])
    if not (repo/".git").exists(): raise ValueError("Depot Windows introuvable")
    top = Path(gitrun("rev-parse", "--show-toplevel").decode().strip()).resolve()
    if top != repo: raise ValueError("Racine Git inattendue")
    origin = gitrun("remote", "get-url", "origin").decode().strip()
    allowed = {f"https://github.com/{EXPECTED}.git", f"https://github.com/{EXPECTED}", f"git@github.com:{EXPECTED}.git", f"ssh://git@github.com/{EXPECTED}.git"}
    if origin not in allowed: raise ValueError("Origin different de Scorpion160/enactspace : arret sans afficher son contenu")
    generated_worker = repo/"frontend/web/firebase-messaging-sw.js"
    if generated_worker.exists():
        if any(p.is_symlink() or (hasattr(p, "is_junction") and p.is_junction()) for p in [generated_worker, *generated_worker.parents]):
            raise ValueError("Worker genere redirige : arret")
        _, expected_template = parse_existing_worker(generated_worker.read_text(encoding="utf-8-sig"))
        template = repo/"tools/templates/firebase-messaging-sw.template.js"
        if not template.is_file() or template.read_text(encoding="utf-8") != expected_template:
            raise ValueError("Worker genere et modele incoherents : arret")
        if not (repo/"tools/generate_firebase_web_worker.py").is_file():
            raise ValueError("Generateur du worker absent : arret")
    source_head = gitrun("rev-parse", "HEAD").decode().strip()
    source_branch = gitrun("branch", "--show-current").decode().strip()
    if not source_branch: raise ValueError("HEAD detache : verifier le depot avant publication")
    original_index = Path(gitrun("rev-parse", "--git-path", "index").decode().strip())
    if not original_index.is_absolute(): original_index = repo/original_index
    original_index_hash = fingerprint(original_index) if original_index.exists() else None
    identifier = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    work = Path(os.environ["LOCALAPPDATA"])/"EnactSpace"/"GitCheckpoints"/identifier
    if work.exists(): raise ValueError("Repertoire de controle deja present")
    private_dir(work)
    env = os.environ.copy()
    env.update(GIT_INDEX_FILE=str(work/"candidate.index"), GIT_LITERAL_PATHSPECS="1")
    for name in ("GITLEAKS_CONFIG", "GITLEAKS_CONFIG_TOML"): env.pop(name, None)
    tracked = set(gitrun("ls-files", "-c", "-z").decode("utf-8").split("\0")) - {""}
    all_names = set(gitrun("ls-files", "-c", "-o", "--exclude-standard", "-z").decode("utf-8").split("\0")) - {""}
    approved, excluded, unsafe = [], [], []
    for name in sorted(all_names):
        file = repo/name
        if not eligible(name, name in tracked) or not file.exists(): excluded.append(name); continue
        if any(part in {"..", ""} for part in name.split("/")) or not file.is_file() or file.is_symlink(): unsafe.append(name); continue
        if any(p.is_symlink() or (hasattr(p, "is_junction") and p.is_junction()) for p in [file, *file.parents] if p != repo.parent): unsafe.append(name); continue
        approved.append(name)
    if unsafe: raise ValueError("Liens ou fichiers speciaux dans la selection : revue necessaire")
    if not approved: raise ValueError("Selection de code vide")
    stable = {name:fingerprint(repo/name) for name in approved}
    gitrun("read-tree", source_head, env=env)
    removals = sorted(tracked-set(approved))
    if removals:
        remove_file=work/"excluded-paths.bin";remove_file.write_bytes(b"\0".join(n.encode("utf-8") for n in removals)+b"\0")
        gitrun("rm", "--cached", "--ignore-unmatch", "--pathspec-from-file="+str(remove_file), "--pathspec-file-nul", env=env)
    filelist = work/"approved-paths.bin"
    filelist.write_bytes(b"\0".join(n.encode("utf-8") for n in approved)+b"\0")
    gitrun("add", "--pathspec-from-file="+str(filelist), "--pathspec-file-nul", env=env)
    candidate = work/"candidate";private_dir(candidate)
    gitrun("checkout-index", "--all", "--prefix="+candidate.as_posix()+"/", env=env)
    leak_config = work/"scanner.toml";leak_config.write_text('[extend]\nuseDefault = true\n', encoding="utf-8")
    ignore_file = work/"empty-ignore";ignore_file.write_text("", encoding="utf-8")
    executable = scanner(work)
    scan = subprocess.run([str(executable), "dir", str(candidate), "--config", str(leak_config),
        "--gitleaks-ignore-path", str(ignore_file), "--ignore-gitleaks-allow", "--redact=100", "--no-banner", "--no-color",
        "--log-level", "error", "--exit-code", "10", "--report-format", "json", "--report-path", str(work/"redacted-scan.json")],
        cwd=work, env=env, capture_output=True, timeout=180)
    report = {"repository":EXPECTED,"source_head":source_head,"source_branch":source_branch,
        "selected_files":len(approved),"excluded_files":len(excluded),"gitleaks_version":VERSION,
        "source_branch_changed":False,"source_index_changed":False,"build_performed":False,"deployment_performed":False,"generated_deployment_files_excluded":["frontend/web/firebase-messaging-sw.js"] if generated_worker.exists() else [],"firebase_api_restrictions_verified":False}
    if scan.returncode == 10:
        findings=json.loads((work/"redacted-scan.json").read_text(encoding="utf-8"))
        report.update(status="BLOCKED_SECRET_REVIEW", findings=[{"file":f.get("File"),"line":f.get("StartLine"),"rule":f.get("RuleID")} for f in findings])
        (work/"summary.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        print(json.dumps(report,ensure_ascii=False),flush=True)
        raise RuntimeError("Publication bloquee : verifier les fichiers signales, sans copier de secret dans la conversation")
    if scan.returncode != 0: raise RuntimeError("Controle Gitleaks incomplet : aucune publication")
    if any(fingerprint(repo/name) != digest for name,digest in stable.items()): raise RuntimeError("Les sources ont change pendant le controle : relancer")
    if gitrun("rev-parse", "HEAD").decode().strip()!=source_head: raise RuntimeError("HEAD a change pendant le controle")
    if (fingerprint(original_index) if original_index.exists() else None)!=original_index_hash: raise RuntimeError("Index modifie par un autre processus")
    report.update(status="REVIEW_PASSED", secret_scan_passed=True)
    if publish:
        # Parent already public: unpublished local history is not uploaded.
        gitrun("fetch", "origin", "refs/heads/main:refs/enactspace-checkpoint/remote-main")
        parent=gitrun("rev-parse", "refs/enactspace-checkpoint/remote-main").decode().strip()
        tree=gitrun("write-tree", env=env).decode().strip()
        branch="checkpoint/prelaunch-"+identifier
        commit=gitrun("commit-tree", tree, "-p", parent, "-m", "chore: checkpoint EnactSpace prelaunch [skip ci]", env=env).decode().strip()
        gitrun("update-ref", "refs/heads/"+branch, commit, "0"*40)
        gitrun("push", "origin", "refs/heads/"+branch+":refs/heads/"+branch)
        remote=gitrun("ls-remote", "origin", "refs/heads/"+branch).decode().split()
        if not remote or remote[0]!=commit: raise RuntimeError("Verification du commit distant incomplete")
        report.update(status="PUBLISHED",branch=branch,commit=commit,url="https://github.com/"+EXPECTED+"/tree/"+branch)
    (work/"summary.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    shutil.rmtree(candidate)
    print(json.dumps(report,ensure_ascii=False,indent=2),flush=True)
    return report

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--repo",type=Path,required=True);parser.add_argument("--publish",action="store_true")
    args=parser.parse_args()
    try: execute(args.repo,args.publish)
    except Exception as exc:
        print("ARRET: "+(str(exc) if isinstance(exc,(ValueError,RuntimeError)) else type(exc).__name__),file=sys.stderr)
        raise SystemExit(1)
