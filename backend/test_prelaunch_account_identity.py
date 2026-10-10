"""Account identity and historical join-year regression cases."""
import secrets as _enactspace_fixture_secrets
_ENACTSPACE_EPHEMERAL_PASSWORD_1 = 'Aa9!' + _enactspace_fixture_secrets.token_hex(24)

from datetime import datetime, timezone
from app.models.user import User
from app.models.alumni import AlumniProfile
import test_prelaunch_account_lifecycle as lifecycle
import unittest

class AccountIdentityTests(lifecycle.AccountLifecycleTests):
    def create(self, **values):
        self.as_user("sg")
        body = dict(first_name="Aïta", last_name="Dia", email="identity@example.test", password=_ENACTSPACE_EPHEMERAL_PASSWORD_1)
        body.update(values)
        return self.call("POST", "users/", body)
    def test_secretariat_edits_identity_and_email_requires_verification(self):
        target = self.users["a"]
        self.as_user("sg")
        self.call("PATCH", f"users/{target.id}/admin", {
            "first_name": "Prénom corrigé", "last_name": "Nom corrigé",
            "phone": "+221770000000", "email": "corrected@example.com",
            "cursus": "DIC", "specialty": "Électronique", "email_verified": True,
        })
        self.db.expire_all()
        self.assertEqual(target.first_name, "Prénom corrigé")
        self.assertEqual(target.cursus, "DIC")
        self.assertEqual(target.email, "corrected@example.com")
        self.assertFalse(target.email_verified)
        self.users["sg"].email = "secretary@example.com"
        self.db.commit()
        self.call("PATCH", f"users/{target.id}/admin", {"email": self.users["sg"].email}, 409)
        self.call("PATCH", f"users/{target.id}/admin", {"first_name": " "}, 422)

    def test_username_is_generated_and_academic_fields_are_saved(self):
        data = self.create(cursus="DUT", specialty="Gestion", enactus_join_year=2020).json()
        self.assertTrue(data["username"].startswith("aita.dia."))
        self.assertLessEqual(len(data["username"]), 50)
        self.assertEqual((data["cursus"], data["specialty"], data["enactus_join_year"]), ("DUT", "Gestion", 2020))
        self.db.expire_all()
        self.assertEqual(self.db.get(User, data["id"]).enactus_join_year, 2020)
    def test_explicit_username_is_normalized_and_case_collision_is_refused(self):
        self.assertEqual(self.create(username="  Aita.Dia  ").json()["username"], "aita.dia")
        self.as_user("sg")
        self.call("POST", "users/", dict(first_name="Other", last_name="Test", email="other@example.test",
            password=_ENACTSPACE_EPHEMERAL_PASSWORD_1, username="AITA.DIA"), 409)
    def test_invalid_usernames_and_join_years_are_rejected(self):
        self.as_user("sg")
        body=dict(first_name="New",last_name="Test",email="invalid@example.test",password=_ENACTSPACE_EPHEMERAL_PASSWORD_1)
        for value in (" ", "x"*51, "abc\u0001"):
            self.call("POST", "users/", dict(body,username=value),422)
        for value in (1899,datetime.now(timezone.utc).year+1):
            self.call("POST", "users/", dict(body,enactus_join_year=value),422)
    def test_year_survives_conversion_and_can_be_corrected(self):
        target=self.users["a"];target.enactus_join_year=2020;self.db.commit()
        self.as_user("tl");self.call("POST",f"users/{target.id}/make-alumni")
        self.db.expire_all()
        profile=self.db.query(AlumniProfile).filter_by(user_id=target.id).one()
        self.assertEqual(profile.enactus_join_year,2020)
        self.as_user("a");self.call("PATCH","users/me",{"enactus_join_year":2019})
        self.db.expire_all();self.assertEqual(target.enactus_join_year,2019)
        self.assertEqual(profile.enactus_join_year,2019)
        self.as_user("sg");self.call("PATCH",f"users/{target.id}/admin",{"enactus_join_year":2018})
        self.db.expire_all();self.assertEqual((target.enactus_join_year,profile.enactus_join_year),(2018,2018))
    def test_implicit_identifiers_do_not_collide_for_equal_names(self):
        first=self.create().json()["username"]
        second=self.create(email="second@example.test").json()["username"]
        self.assertNotEqual(first,second)
    def test_enactrice_account_can_be_created(self):
        self.assertEqual(self.create(profile_type="enactrice").json()["profile_type"],"enactrice")
if __name__=="__main__":unittest.main()
