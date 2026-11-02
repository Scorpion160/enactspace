"""Rehearse nine text updates in a derivative of the pinned production image."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.request import urlopen

MANIFEST_SHA256 = "75622d0a3e776c4c9adce6e194e25cbbea525b4e9746c79f62c1aaebf122ee54"
STAGING = Path("/opt/enactspace/staging")
SERVICES = (
    "enactspace_backend", "enactspace_email_worker",
    "enactspace_push_worker", "enactspace_veille_worker",
)
BACKEND = Path("/app/backend")
IMAGE_PATTERN = r"sha256:[a-f0-9]{64}"

TEST_PROGRAM = '''
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import unittest
from alembic.config import Config
from alembic.script import ScriptDirectory

def run(manifest):
    if os.geteuid() == 0:
        raise RuntimeError("Candidate_test_user_is_root")
    for name, expected in manifest["runtime"].items():
        if hashlib.sha256((Path("/app") / name).read_bytes()).hexdigest() != expected:
            raise RuntimeError("Candidate_runtime_file_incorrect:" + name)
    for name, expected in manifest["tests"].items():
        if hashlib.sha256((Path("/fixtures") / Path(name).name).read_bytes()).hexdigest() != expected:
            raise RuntimeError("Candidate_test_file_incorrect:" + name)
    heads = ScriptDirectory.from_config(Config("alembic.ini")).get_heads()
    if heads != [manifest["schema_head"]]:
        raise RuntimeError("Unexpected_candidate_schema_head")
    root = Path("/tmp/interface-copy-tests")
    root.mkdir()
    for name in ("app", "alembic"):
        (root / name).symlink_to(Path("/app/backend") / name, target_is_directory=True)
    for name in manifest["tests"]:
        fixture = Path(name).name
        shutil.copyfile(Path("/fixtures") / fixture, root / fixture)
    sys.path.insert(0, str(root))
    suite = unittest.defaultTestLoader.loadTestsFromNames(manifest["test_modules"])
    result = unittest.TextTestRunner(verbosity=1).run(suite)
    report = {"tests_run": result.testsRun, "failures": len(result.failures),
              "errors": len(result.errors), "skipped": len(result.skipped),
              "candidate_schema_head": heads[0]}
    print(json.dumps(report), flush=True)
    return (result.wasSuccessful() and not result.skipped
            and result.testsRun == manifest["tests_expected"])
'''


def run(args, *, input_text=None, timeout=30, show_test_failure=False):
    result = subprocess.run(args, input=input_text, text=True, encoding="utf-8",
                            errors="replace", capture_output=True, timeout=timeout)
    if result.returncode:
        if show_test_failure:
            print(result.stderr, end="", file=sys.stderr)
            print(result.stdout, end="", file=sys.stderr)
        raise RuntimeError("Command_failed:" + "_".join(args[:2]))
    return result.stdout


def inspect(kind, *names):
    return json.loads(run(["docker", kind, "inspect", *names]))


def check_baseline(manifest):
    image_id = manifest["base_image_id"]
    services = inspect("container", *SERVICES)
    if len(services) != len(SERVICES) or any(
        row["Name"] != "/" + name or row["Image"] != image_id or not row["State"]["Running"]
        for name, row in zip(SERVICES, services)
    ):
        raise RuntimeError("Production_services_changed")
    with urlopen("http://127.0.0.1:18002/health", timeout=10) as response:
        health = json.load(response)
    if (health.get("ok"), health.get("version"), health.get("environment")) != (
        True, manifest["base_version"], "production"
    ):
        raise RuntimeError("Unexpected_production_health")
    paths = ["/app/" + name for name in manifest["baseline"]]
    lines = run(["docker", "exec", SERVICES[0], "sha256sum", *paths]).splitlines()
    actual = {name.removeprefix("/app/"): digest
              for digest, name in (line.split(maxsplit=1) for line in lines)}
    if actual != manifest["baseline"]:
        raise RuntimeError("Production_source_changed_since_probe")
    return inspect("image", image_id)[0]


def load_manifest(directory):
    payload = directory / "payload"
    data = (directory / "manifest.json").read_bytes()
    if hashlib.sha256(data).hexdigest() != MANIFEST_SHA256:
        raise RuntimeError("Manifest_integrity_failed")
    manifest = json.loads(data)
    for name, expected in (manifest["runtime"] | manifest["tests"]).items():
        path = payload / name
        if path.is_symlink() or not path.resolve().is_relative_to(payload.resolve()):
            raise RuntimeError("Unexpected_payload_path")
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise RuntimeError("Payload_integrity_failed:" + name)
    return manifest


def build_candidate(directory, manifest, owner, base, candidate):
    base_tag = "enactspace-backend:interface-copy-base-" + owner
    lines = [
        "FROM " + base_tag,
        'LABEL net.enactspace.patch_revision="' + manifest["source_commit"] + '"',
        'LABEL net.enactspace.interface_copy_rehearsal="' + owner + '"',
    ]
    with tempfile.TemporaryDirectory(prefix="build-", dir=directory) as temporary:
        context = Path(temporary)
        for name in manifest["runtime"]:
            target = context / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(directory / "payload" / name, target)
            lines.append(f"COPY --chmod=0644 {name} /app/{name}")
        (context / "Dockerfile").write_text("\n".join(lines) + "\n")
        run(["docker", "image", "tag", base["Id"], base_tag])
        try:
            run(["docker", "build", "--pull=false", "--network=none", "-t", candidate, str(context)],
                timeout=180)
        finally:
            run(["docker", "image", "rm", base_tag])
    image = inspect("image", candidate)[0]
    base_layers = base["RootFS"]["Layers"]
    config_keys = ("User", "WorkingDir", "Entrypoint", "Cmd", "Env", "Healthcheck", "Volumes")
    if (not re.fullmatch(IMAGE_PATTERN, image["Id"])
            or image["RootFS"]["Layers"][:len(base_layers)] != base_layers
            or any(image["Config"].get(key) != base["Config"].get(key) for key in config_keys)):
        raise RuntimeError("Candidate_parent_or_configuration_incorrect")
    return image["Id"]


def test_candidate(directory, manifest, owner, image_id):
    fixtures = directory / "fixtures"
    fixtures.mkdir(mode=0o755)
    for name in manifest["tests"]:
        target = fixtures / Path(name).name
        shutil.copyfile(directory / "payload" / name, target)
        target.chmod(0o644)
    fixtures.chmod(0o755)
    environment = {
        "APP_ENV": "test", "APP_DEBUG": "false", "DATABASE_URL": "sqlite://",
        "SECRET_KEY": "interface-copy-isolated-test-only-key-value", "JWT_SECRET_KEY": "",
        "EMAIL_ENABLED": "false", "PUSH_ENABLED": "false", "SMTP_HOST": "smtp.invalid",
        "SMTP_PASSWORD": "", "AUTO_CREATE_TABLES": "false", "ENABLE_SEED": "false",
        "MOBILE_MONEY_ENABLED": "false", "FILE_STORAGE_PATH": "/app/uploads",
        "PYTHONDONTWRITEBYTECODE": "1", "TEST_DATABASE_URL": "", "VEILLE_TEST_POSTGRESQL_URL": "",
    }
    command = [
        "docker", "run", "--rm", "-i", "--name", "enactspace-interface-copy-test-" + owner,
        "--network=none", "--read-only", "--memory=512m", "--cpus=0.5", "--pids-limit=128",
        "--tmpfs", "/tmp:rw,size=192m,mode=1777", "--tmpfs", "/app/uploads:rw,size=64m,mode=1777",
        "--mount", f"type=bind,src={fixtures},dst=/fixtures,readonly",
        "--workdir", str(BACKEND),
    ]
    for name, value in environment.items():
        command.extend(["-e", f"{name}={value}"])
    command.extend(["--entrypoint", "/usr/bin/timeout", image_id, "--kill-after=10s", "240s", "python", "-"])
    program = TEST_PROGRAM + "\nraise SystemExit(0 if run(" + repr(manifest) + ") else 1)\n"
    output = run(command, input_text=program, timeout=265, show_test_failure=True)
    result = json.loads(output.strip().rsplit("\n", 1)[-1])
    if (result.get("tests_run") != manifest["tests_expected"]
            or any(result.get(key) != 0 for key in ("failures", "errors", "skipped"))
            or result.get("candidate_schema_head") != manifest["schema_head"]):
        raise RuntimeError("Candidate_test_report_incorrect")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    directory = parser.parse_args().directory.resolve()
    match = re.fullmatch(r"interface-copy-backend-([a-f0-9]{32})", directory.name)
    if directory.parent != STAGING or not match:
        parser.error("Owned staging directory required")
    owner = match[1]
    candidate = "enactspace-backend:interface-copy-" + owner[:12]
    report = {"status": "INTERFACE_COPY_BACKEND_REHEARSAL_BLOCKED",
              "operation_id": owner, "deployment_performed": False}
    stage = "payload"
    try:
        manifest = load_manifest(directory)
        stage = "production_baseline"
        base = check_baseline(manifest)
        if base["Id"] != manifest["base_image_id"] or base["Config"].get("User") in (None, "", "0", "root"):
            raise RuntimeError("Unexpected_production_base_image")
        docker_root = Path(run(["docker", "info", "--format", "{{.DockerRootDir}}"]).strip())
        if not docker_root.is_absolute() or shutil.disk_usage(docker_root).free < 1024**3:
            raise RuntimeError("Docker_disk_space_below_1_GiB")
        stage = "candidate_build"
        print("CONSTRUCTION_IMAGE_TEXTES_SERVEUR", flush=True)
        image_id = build_candidate(directory, manifest, owner, base, candidate)
        report.update(candidate_image=candidate, candidate_image_id=image_id,
                      base_image_id=base["Id"], source_commit=manifest["source_commit"])
        stage = "isolated_tests"
        print("TESTS_SQLITE_ISOLES_DE_L_IMAGE_CANDIDATE", flush=True)
        report.update(test_candidate(directory, manifest, owner, image_id))
        stage = "production_recheck"
        check_baseline(manifest)
        report["status"] = "INTERFACE_COPY_BACKEND_CANDIDATE_VERIFIED"
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.TimeoutExpired) as error:
        report.update(stage=stage, reason=str(error) if isinstance(error, RuntimeError) else type(error).__name__)
    receipt = json.dumps(report, indent=2)
    (directory / "rehearsal.json").write_text(receipt + "\n")
    print(receipt)
    return 0 if report["status"] == "INTERFACE_COPY_BACKEND_CANDIDATE_VERIFIED" else 1


if __name__ == "__main__":
    raise SystemExit(main())
