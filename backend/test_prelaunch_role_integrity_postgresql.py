"""Concurrent administrator removal against a disposable PostgreSQL database."""
import unittest
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from unittest.mock import patch
from uuid import uuid4
from fastapi import HTTPException
from starlette.requests import Request
from app.api.routes import users
from app.models.user import User
from app.models.role import Role, UserRole
from app.schemas.user import UserRoleAssign
import test_password_reset_guard_postgresql as pg_fixture

class PostgreSQLRoleIntegrityTests(unittest.TestCase):
    setUpClass=classmethod(pg_fixture.PostgreSQLResetGuardTests.setUpClass.__func__)
    tearDownClass=classmethod(pg_fixture.PostgreSQLResetGuardTests.tearDownClass.__func__)

    def test_bulk_and_direct_removal_race_retains_one_administrator(self):
        with self.Session() as db:
            role=db.query(Role).filter(Role.name=="administrateur").first()
            if role is None:
                role=Role(name="administrateur");db.add(role);db.flush()
            base=db.query(Role).filter(Role.name=="enacteur").first()
            if base is None:
                base=Role(name="enacteur");db.add(base);db.flush()
            ids=[]
            for _ in range(2):
                row=User(first_name="Role",last_name="Test",email=uuid4().hex+"@example.org",
                         password_hash="unused",status="active",is_active=True,email_verified=True)
                db.add(row);db.flush();ids.append(row.id)
                db.add(UserRole(user_id=row.id,role_id=role.id))
                db.add(UserRole(user_id=row.id,role_id=base.id))
            db.commit()
        barrier=Barrier(2)
        original=users.ensure_admin_removal_allowed
        def synchronized(db, member_id):
            barrier.wait(timeout=10)
            return original(db,member_id)
        def remove(index):
            with self.Session() as db:
                member=db.get(User,ids[index])
                request=Request({"type":"http","client":("127.0.0.1",1),"headers":[]})
                try:
                    if index==0:
                        users.assign_roles_to_user(str(member.id),UserRoleAssign(role_names=[]),request,db,member)
                    else:
                        users.remove_role_from_user(str(member.id),"administrateur",request,db,member)
                    return 200
                except HTTPException as error:
                    db.rollback();return error.status_code
        with patch.object(users,"ensure_admin_removal_allowed",synchronized), patch.object(users,"notify_user"):
            with ThreadPoolExecutor(max_workers=2) as workers:
                outcomes=list(workers.map(remove,[0,1]))
        self.assertEqual(sorted(outcomes),[200,409])
        with self.Session() as db:
            self.assertEqual(db.query(UserRole).join(Role).filter(Role.name=="administrateur").count(),1)

if __name__=="__main__":
    unittest.main()
