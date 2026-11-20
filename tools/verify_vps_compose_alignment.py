#!/usr/bin/env python3
"""Read-only check for drift between effective VPS Compose and running containers.

The checked files must be captured separately with:
  docker compose -p enactspace -f <base.yml> -f <release.override.yml> config --format json > effective.json
  docker inspect enactspace_backend enactspace_email_worker enactspace_push_worker enactspace_veille_worker > running.json

This script NEVER calls Docker or changes the VPS. It rejects any missing release
override, implicit build target or mismatch between the intended and active images.
"""

import argparse
import json
from pathlib import Path

SERVICE_CONTAINERS = {
    "backend": "enactspace_backend",
    "email-worker": "enactspace_email_worker",
    "push-worker": "enactspace_push_worker",
    "veille-worker": "enactspace_veille_worker",
}


def validate_alignment(compose: dict, running: list[dict]) -> list[str]:
    errors: list[str] = []
    services = compose.get("services")
    if not isinstance(services, dict):
        return ["La configuration Compose ne contient aucun service exploitable."]

    names = {str(c.get("Name", "")).lstrip("/"): c for c in running}
    configured_images = set()
    running_image_ids = set()

    for service_name, container_name in SERVICE_CONTAINERS.items():
        config = services.get(service_name)
        if not isinstance(config, dict):
            errors.append(f"Service absent de Compose : {service_name}.")
            continue

        image = str(config.get("image") or "").strip()
        if not image:
            errors.append(f"Image non épinglée dans Compose : {service_name}.")
        else:
            configured_images.add(image)

        if config.get("build") is not None:
            errors.append(f"Construction implicite interdite pour : {service_name}.")

        container = names.get(container_name)
        if container is None:
            errors.append(f"Conteneur absent de l'inventaire : {container_name}.")
            continue

        actual = str((container.get("Config") or {}).get("Image") or "").strip()
        if image and image != actual:
            errors.append(
                f"Écart {service_name} : Compose={image}, service actif={actual}."
            )
        image_id = str(container.get("Image") or "").strip()
        if not image_id.startswith("sha256:"):
            errors.append(f"Identifiant d'image indisponible : {container_name}.")
        else:
            running_image_ids.add(image_id)
        if container.get("State", {}).get("Running") is not True:
            errors.append(f"Service non démarré : {container_name}.")

    if len(configured_images) > 1:
        errors.append("Les quatre services ne ciblent pas la même image applicative.")
    if len(running_image_ids) > 1:
        errors.append("Les quatre services actifs n'utilisent pas le même contenu d'image.")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compose-json", required=True, type=Path)
    parser.add_argument("--containers-json", required=True, type=Path)
    args = parser.parse_args()
    compose = json.loads(args.compose_json.read_text(encoding="utf-8-sig"))
    running = json.loads(args.containers_json.read_text(encoding="utf-8-sig"))
    if not isinstance(running, list):
        raise ValueError("Le résultat docker inspect doit être une liste JSON.")
    errors = validate_alignment(compose, running)
    if errors:
        print("BLOQUÉ — risque de divergence de version :")
        for error in errors:
            print(f"  - {error}")
        return 1
    image = compose["services"]["backend"]["image"]
    print(f"CONFORME — quatre services alignés sur {image}. Aucune modification effectuée.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
