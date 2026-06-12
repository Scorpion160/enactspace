import requests


BASE_URL = "http://127.0.0.1:8000/api"

ADMIN_EMAIL = "cheikh@example.com"
ADMIN_PASSWORD = "Admin12345"

AWA_EMAIL = "awa@example.com"
AWA_PASSWORD = "Awa12345"


def login(email, password):
    response = requests.post(
        f"{BASE_URL}/auth/token",
        data={
            "username": email,
            "password": password,
        },
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
        },
        timeout=10,
    )

    if response.status_code != 200:
        print(f"[LOGIN FAIL] {email} -> {response.status_code}")
        print(response.text)
        return None

    return response.json()["access_token"]


def check(method, path, token, expected=(200,), json=None):
    headers = {
        "Authorization": f"Bearer {token}",
    }

    url = f"{BASE_URL}{path}"

    if method == "GET":
        response = requests.get(url, headers=headers, timeout=10)
    elif method == "POST":
        response = requests.post(url, headers=headers, json=json, timeout=10)
    else:
        raise ValueError(f"Méthode non supportée : {method}")

    ok = response.status_code in expected
    status = "OK" if ok else "FAIL"

    print(f"[{status}] {method} {path} -> {response.status_code}")

    if not ok:
        print(response.text)

    return ok


def main():
    print("=== ENACTSPACE BACKEND SMOKE TEST ===")

    admin_token = login(ADMIN_EMAIL, ADMIN_PASSWORD)
    awa_token = login(AWA_EMAIL, AWA_PASSWORD)

    if not admin_token:
        print("Impossible de continuer : login admin échoué.")
        return

    if not awa_token:
        print("Attention : login Awa échoué. Les tests membre seront ignorés.")

    print("")
    print("=== TESTS ADMIN ===")

    admin_tests = [
        ("GET", "/users/me"),
        ("GET", "/users/"),
        ("GET", "/seasons/"),
        ("GET", "/poles/"),
        ("GET", "/projects/"),
        ("GET", "/events/"),
        ("GET", "/tasks/"),
        ("GET", "/documents/"),
        ("GET", "/documents/official"),
        ("GET", "/documents/templates"),
        ("GET", "/posts/"),
        ("GET", "/posts/feed"),
        ("GET", "/posts/official"),
        ("GET", "/recruitment/campaigns"),
        ("GET", "/recruitment/campaigns/public"),
        ("GET", "/recruitment/applications"),
        ("GET", "/notifications/"),
        ("GET", "/notifications/unread-count"),
        ("GET", "/gamification/badges"),
        ("GET", "/gamification/ranking/users?limit=20"),
        ("GET", "/audit/logs?limit=20"),
        ("GET", "/alumni/profiles"),
        ("GET", "/alumni/mentorships"),
    ]

    admin_ok = 0

    for method, path in admin_tests:
        if check(method, path, admin_token):
            admin_ok += 1

    print("")
    print("=== TESTS MEMBRE AWA ===")

    member_ok = 0
    member_tests_count = 0

    if awa_token:
        member_tests = [
            ("GET", "/users/me", (200,)),
            ("GET", "/tasks/my", (200,)),
            ("GET", "/notifications/", (200,)),
            ("GET", "/notifications/unread-count", (200,)),
            ("GET", "/finance/accounts", (403,)),
        ]

        for method, path, expected in member_tests:
            member_tests_count += 1
            if check(method, path, awa_token, expected=expected):
                member_ok += 1

    print("")
    print("=== RÉSUMÉ ===")
    print(f"Tests admin réussis : {admin_ok}/{len(admin_tests)}")

    if awa_token:
        print(f"Tests membre réussis : {member_ok}/{member_tests_count}")

    print("")
    print("Smoke test terminé.")


if __name__ == "__main__":
    main()