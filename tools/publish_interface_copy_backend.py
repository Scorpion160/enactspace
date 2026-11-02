"""Switch four services to the verified interface-copy image without a migration."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import sys

import publish_recruitment_campaign_backend as ops

REHEARSAL = "09775840a54d4fee88a1fbb1108d598d"
IMAGE = "sha256:c39192c6670c08b4a1c1552061b95fb0290d974e01e0e5cef248c6689a72866d"
VERSION = "1.0.22"
MANIFEST_SHA256 = "75622d0a3e776c4c9adce6e194e25cbbea525b4e9746c79f62c1aaebf122ee54"
REHEARSAL_RECEIPT = (
    Path("/opt/enactspace/staging") / ("interface-copy-backend-" + REHEARSAL) / "rehearsal.json"
)
RECREATE = ("up", "-d", "--no-deps", "--no-build", "--pull", "never", "--force-recreate", *ops.SERVICES)
SCHEMA_PROBE = '''
import json
from sqlalchemy import text
from app.db.database import engine
assert engine.dialect.name == "postgresql"
with engine.begin() as connection:
    connection.execute(text("SET TRANSACTION READ ONLY"))
    connection.execute(text("SET LOCAL statement_timeout = '10s'"))
    if connection.execute(text("SHOW transaction_read_only")).scalar_one() != "on":
        raise RuntimeError("Read_only_transaction_required")
    schema = connection.execute(text("SELECT version_num FROM alembic_version")).scalars().all()
print(json.dumps(schema))
'''


def validate_rehearsal(receipt, manifest):
    expected = {
        "status": "INTERFACE_COPY_BACKEND_CANDIDATE_VERIFIED",
        "operation_id": REHEARSAL,
        "deployment_performed": False,
        "candidate_image": "enactspace-backend:interface-copy-" + REHEARSAL[:12],
        "candidate_image_id": IMAGE,
        "base_image_id": manifest["base_image_id"],
        "source_commit": manifest["source_commit"],
        "tests_run": manifest["tests_expected"],
        "failures": 0, "errors": 0, "skipped": 0,
        "candidate_schema_head": manifest["schema_head"],
    }
    ops.require(receipt == expected, "Rehearsal_receipt_incorrect")


def updated_compose(original, manifest):
    old_image = "    image: " + manifest["base_image_id"] + "\n"
    new_image = "    image: " + IMAGE + "\n"
    old_version = '      APP_VERSION: "' + manifest["base_version"] + '"\n'
    new_version = '      APP_VERSION: "' + VERSION + '"\n'
    ops.require(original.count(old_image) == 4 and original.count(old_version) == 1
                and new_image not in original, "Unexpected_current_compose")
    return original.replace(old_image, new_image).replace(old_version, new_version)


def validate_plan(before, after, manifest):
    expected = json.loads(json.dumps(before))
    for name in ops.SERVICES:
        service = expected["services"][name]
        ops.require(service["image"] == manifest["base_image_id"], "Unexpected_resolved_image")
        service["image"] = IMAGE
    backend = expected["services"]["backend"]["environment"]
    ops.require(backend["APP_VERSION"] == manifest["base_version"], "Unexpected_resolved_version")
    backend["APP_VERSION"] = VERSION
    ops.require(expected == after, "Unexpected_resolved_configuration_change")


class Host(ops.Host):
    def verify_plan(self, updated, manifest):
        plan = self.directory / "compose.candidate.yml"
        plan.write_text(updated)
        plan.chmod(0o600)
        before = json.loads(self.compose("config", "--format", "json"))
        after = json.loads(self.run(["docker", "compose", "-p", "enactspace",
            "--project-directory", str(ops.BASE.parent), "-f", str(plan), "config", "--format", "json"]))
        validate_plan(before, after, manifest)

    def verify_schema(self, expected):
        result = self.run(["docker", "exec", "-i", ops.NAMES[0], "python", "-"],
                          input=SCHEMA_PROBE, timeout=25)
        ops.require(json.loads(result) == [expected], "Unexpected_database_schema")

    def verify_sources(self, expected, *, isolated=False):
        if isolated:
            command = ["docker", "run", "--rm", "--network=none", "--read-only",
                       "--entrypoint", "sha256sum", IMAGE]
        else:
            command = ["docker", "exec", ops.NAMES[0], "sha256sum"]
        paths = ["/app/" + name for name in expected]
        result = self.run(command + paths, timeout=30)
        actual = {name.removeprefix("/app/"): digest
                  for digest, name in (line.split(maxsplit=1) for line in result.splitlines())}
        ops.require(actual == expected, "Runtime_source_hashes_incorrect")

    def verify_image(self, manifest):
        base, candidate = json.loads(self.run(
            ["docker", "image", "inspect", manifest["base_image_id"], IMAGE], timeout=30))
        labels = candidate["Config"].get("Labels") or {}
        layers = base["RootFS"]["Layers"]
        ops.require(base["Id"] == manifest["base_image_id"] and candidate["Id"] == IMAGE
                    and candidate["RootFS"]["Layers"][:len(layers)] == layers
                    and labels.get("net.enactspace.interface_copy_rehearsal") == REHEARSAL
                    and labels.get("net.enactspace.patch_revision") == manifest["source_commit"],
                    "Candidate_image_provenance_incorrect")
        self.verify_sources(manifest["runtime"], isolated=True)


def verify_live(host, version, image, manifest, file_group):
    host.healthy(version, image)
    host.verify_sources(manifest[file_group])
    host.configuration()
    host.verify_schema(manifest["schema_head"])
    host.timeline()


def perform_release(host, original, manifest, execute):
    report = {"status": "INTERFACE_COPY_BACKEND_DEPLOYMENT_BLOCKED",
              "deployment_performed": False, "migration_performed": False}
    stage = "preflight"
    switch_started = False
    try:
        host.verify_image(manifest)
        current_target_lines = original.count("    image: " + IMAGE + "\n")
        if current_target_lines == 4 and original.count('      APP_VERSION: "' + VERSION + '"\n') == 1:
            verify_live(host, VERSION, IMAGE, manifest, "runtime")
            return {**report, "status": "INTERFACE_COPY_BACKEND_ALREADY_DEPLOYED",
                    "version": VERSION, "image_id": IMAGE, "schema": manifest["schema_head"]}

        updated = updated_compose(original, manifest)
        verify_live(host, manifest["base_version"], manifest["base_image_id"], manifest, "baseline")
        host.verify_plan(updated, manifest)
        if not execute:
            return {**report, "status": "INTERFACE_COPY_BACKEND_PREFLIGHT_PASSED",
                    "version": VERSION, "image_id": IMAGE, "schema": manifest["schema_head"]}

        previous = host.directory / "compose.previous.yml"
        previous.write_text(original)
        previous.chmod(0o600)
        report["rollback_configuration"] = str(previous)
        stage = "verified_backup"
        report["backup_id"] = host.verified_backup()
        print("SAUVEGARDE_SERVEUR_VERIFIEE", flush=True)
        stage = "pre_switch_recheck"
        verify_live(host, manifest["base_version"], manifest["base_image_id"], manifest, "baseline")
        host.verify_plan(updated, manifest)

        stage = "configuration_switch"
        switch_started = True
        host.replace(original, updated)
        stage = "service_recreation"
        host.compose("config", "--quiet")
        host.compose(*RECREATE)
        stage = "post_switch_checks"
        verify_live(host, VERSION, IMAGE, manifest, "runtime")
        report.update(status="INTERFACE_COPY_BACKEND_DEPLOYED", deployment_performed=True,
                      image_id=IMAGE, version=VERSION, schema=manifest["schema_head"],
                      all_four_services_verified=True, timeline_verified=True)
    except BaseException as error:
        report.update(stage=stage, error_type=type(error).__name__)
        if isinstance(error, ops.ReleaseError):
            report["reason"] = str(error)
        if host.failed_configuration_checks:
            report["failed_configuration_checks"] = host.failed_configuration_checks
        if switch_started:
            try:
                current = ops.BASE.read_text()
                if current == updated:
                    host.replace(updated, original)
                    host.compose(*RECREATE)
                else:
                    ops.require(current == original, "Compose_changed_during_rollback")
                verify_live(host, manifest["base_version"], manifest["base_image_id"], manifest, "baseline")
                report["previous_services_restored"] = True
            except BaseException:
                report["previous_services_restored"] = False
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    directory = args.directory.resolve()
    ops.require(directory.parent == ops.OPERATIONS
                and re.fullmatch(r"publish-interface-copy-[a-f0-9]{32}", directory.name)
                and not args.directory.is_symlink(), "Owned_operation_directory_required")
    os.umask(0o077)
    report = {"status": "INTERFACE_COPY_BACKEND_PREPARATION_BLOCKED",
              "deployment_performed": False, "migration_performed": False}
    try:
        data = (directory / "manifest.json").read_bytes()
        ops.require(hashlib.sha256(data).hexdigest() == MANIFEST_SHA256, "Manifest_integrity_incorrect")
        manifest = json.loads(data)
        ops.require(not REHEARSAL_RECEIPT.is_symlink(), "Unexpected_rehearsal_receipt_link")
        validate_rehearsal(json.loads(REHEARSAL_RECEIPT.read_text()), manifest)
        with (ops.OPERATIONS / "backend-publication.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            ops.require(not ops.BASE.is_symlink(), "Unexpected_compose_symlink")
            report = perform_release(Host(directory), ops.BASE.read_text(), manifest, args.execute)
    except BaseException as error:
        report["error_type"] = type(error).__name__
        if isinstance(error, ops.ReleaseError):
            report["reason"] = str(error)
    name = "deployment.json" if args.execute else "preflight.json"
    temporary = directory / (name + ".tmp")
    temporary.write_text(json.dumps(report, indent=2))
    temporary.replace(directory / name)
    print(json.dumps(report, indent=2), flush=True)
    return 0 if report["status"] in {
        "INTERFACE_COPY_BACKEND_PREFLIGHT_PASSED",
        "INTERFACE_COPY_BACKEND_DEPLOYED",
        "INTERFACE_COPY_BACKEND_ALREADY_DEPLOYED",
    } else 1


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, ops.interrupt_release)
    sys.exit(main())
