"""Role escalation, last administrator and directory regressions."""
import os
os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", "isolated-prelaunch-secret")
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")

import unittest
from unittest.mock import patch
from uuid import uuid4
from fastapi import HTTPException
from starlette.requests import Request
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import app.models.base
from app.db.database import Base
from app.api.routes import users
from app.api.deps import get_user_role_names
from app.models.user import User
from app.models.role import Role, UserRole
from app.schemas.user import UserRoleAssign
from app.services.operational_integrity import lock_user

class RoleIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite://")
        Base.metadata.create_all(self.engine)
        self.db = sessionmaker(bind=self.engine, autoflush=False)()
        self.admin = self.member("Admin", "Tester", {"administrateur", "enacteur"})
        self.other = self.member("Other", "Tester", {"enacteur"})
        self.db.commit()
        self.request = Request({"type":"http","client":("127.0.0.1",1),"headers":[]})
        self.notification = patch.object(users, "notify_user")
        self.notification.start()

    def tearDown(self):
        self.notification.stop()
        self.db.close()
        self.engine.dispose()

    def member(self, first, last, names):
        row = User(first_name=first, last_name=last, email=uuid4().hex+"@example.org",
                   password_hash="unused", status="active", profile_type="enacteur",
                   is_active=True, email_verified=True)
        self.db.add(row); self.db.flush()
        for name in names:
            role = self.db.query(Role).filter(Role.name == name).first()
            if role is None:
                role=Role(name=name); self.db.add(role); self.db.flush()
            self.db.add(UserRole(user_id=row.id,role_id=role.id))
        self.db.flush()
        return row

    def assign(self, target, names, actor=None):
        return users.assign_roles_to_user(str(target.id), UserRoleAssign(role_names=names),
                                         self.request, self.db, actor or self.admin)

    def denied(self, status, callback):
        with self.assertRaises(HTTPException) as caught:
            callback()
        self.assertEqual(caught.exception.status_code,status)

    def test_bulk_update_cannot_remove_last_administrator(self):
        self.denied(409, lambda:self.assign(self.admin, []))
        self.assertIn("administrateur", get_user_role_names(self.db,self.admin.id))

    def test_direct_removal_cannot_remove_last_administrator(self):
        self.denied(409,lambda:users.remove_role_from_user(str(self.admin.id),
                    "administrateur",self.request,self.db,self.admin))
        self.assertIn("administrateur",get_user_role_names(self.db,self.admin.id))

    def test_bulk_removal_allowed_with_another_admin_then_last_is_protected(self):
        second=self.member("Second","Admin",{"administrateur","enacteur"})
        self.db.commit()
        self.assign(second,[])
        self.assertNotIn("administrateur",get_user_role_names(self.db,second.id))
        self.denied(409,lambda:self.assign(self.admin,[]))

    def test_direct_removal_allowed_with_another_administrator(self):
        second=self.member("Second","Admin",{"administrateur","enacteur"})
        self.db.commit()
        users.remove_role_from_user(str(second.id),"administrateur",self.request,self.db,self.admin)
        self.assertNotIn("administrateur",get_user_role_names(self.db,second.id))
        self.assertIn("administrateur",get_user_role_names(self.db,self.admin.id))

    def test_disabled_administrator_does_not_bypass_last_active_admin_guard(self):
        disabled=self.member("Disabled","Admin",{"administrateur","enacteur"})
        disabled.is_active=False;disabled.status="inactive";self.db.commit()
        self.denied(409,lambda:self.assign(self.admin,[]))
        self.denied(409,lambda:users.remove_role_from_user(str(self.admin.id),
                    "administrateur",self.request,self.db,self.admin))

    def test_unverified_administrator_does_not_count_as_available(self):
        unverified=self.member("Unverified","Admin",{"administrateur","enacteur"})
        unverified.email_verified=False;self.db.commit()
        self.denied(409,lambda:self.assign(self.admin,[]))

    def test_member_cannot_grant_self_administrator(self):
        self.denied(403,lambda:self.assign(self.other,["administrateur"],self.other))
        self.assertNotIn("administrateur",get_user_role_names(self.db,self.other.id))

    def test_team_leader_cannot_grant_administrator(self):
        leader=self.member("Team","Leader",{"team_leader","enacteur"});self.db.commit()
        self.denied(403,lambda:self.assign(self.other,["administrateur"],leader))

    def test_secretary_cannot_grant_team_leader(self):
        secretary=self.member("Secretary","Tester",{"secretaire_generale","enacteur"});self.db.commit()
        self.denied(403,lambda:self.assign(self.other,["team_leader"],secretary))

    def test_invalid_user_identifiers_return_not_found(self):
        for value in ["not-a-uuid",None,42]:
            self.denied(404,lambda:users.get_user_or_404(self.db,value))
            self.denied(404,lambda:lock_user(self.db,value))

    def test_directory_orders_last_name_then_first_and_keeps_profile_fields(self):
        self.admin.last_name="Zulu";self.other.last_name="Zulu"
        first=self.member("Zoe","Alpha",{"enacteur"})
        second=self.member("Amy","alpha",{"enacteur"})
        second.username="amy"
        second.cursus="DIC"
        second.specialty="Electronique"
        self.db.commit()
        directory=users.list_user_directory(self.db,self.admin)
        self.assertEqual([row.id for row in directory[:2]],[second.id,first.id])
        data=directory[0]
        self.assertEqual((data.username,data.cursus,data.specialty),
                         ("amy","DIC","Electronique"))

if __name__ == "__main__":
    unittest.main()
