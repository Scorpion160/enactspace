"""Run locally; synthetic inputs only, never accesses production."""

import copy
import unittest

from verify_vps_compose_alignment import SERVICE_CONTAINERS, validate_alignment


def fixture():
    image = "enactspace-backend:chat41-949575e"
    compose = {"services": {key: {"image": image} for key in SERVICE_CONTAINERS}}
    running = [
        {
            "Name": "/" + container,
            "Config": {"Image": image},
            "Image": "sha256:" + "a" * 64,
            "State": {"Running": True},
        }
        for container in SERVICE_CONTAINERS.values()
    ]
    return compose, running


class DeploymentGuardTests(unittest.TestCase):
    def test_all_four_services_match(self):
        compose, running = fixture()
        self.assertEqual(validate_alignment(compose, running), [])

    def test_default_compose_without_release_override_is_rejected(self):
        compose, running = fixture()
        del compose["services"]["push-worker"]
        compose["services"]["backend"].pop("image")
        compose["services"]["backend"]["build"] = {"context": ".."}
        issues = validate_alignment(compose, running)
        self.assertTrue(any("absent" in x.lower() for x in issues))
        self.assertTrue(any("non épinglée" in x for x in issues))
        self.assertTrue(any("interdite" in x for x in issues))

    def test_previously_deployed_tag_rejected(self):
        compose, running = fixture()
        compose["services"]["email-worker"]["image"] = "enactspace-backend:old"
        issues = validate_alignment(compose, running)
        self.assertTrue(any("Écart" in x for x in issues))
        self.assertTrue(any("même image" in x for x in issues))

    def test_mixed_image_digests_rejected_even_when_tags_match(self):
        compose, running = fixture()
        running[2]["Image"] = "sha256:" + "b" * 64
        self.assertTrue(any("même contenu" in x for x in validate_alignment(compose, running)))

    def test_missing_or_stopped_service_rejected(self):
        compose, running = fixture()
        del running[1]
        running[0]["State"]["Running"] = False
        issues = validate_alignment(compose, running)
        self.assertTrue(any("absent" in x.lower() for x in issues))
        self.assertTrue(any("non démarré" in x for x in issues))


if __name__ == "__main__":
    unittest.main()
