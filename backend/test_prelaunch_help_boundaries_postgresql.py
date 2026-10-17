"""Private help authorization and concurrent writes on a disposable PostgreSQL."""
import os,time,threading,unittest,uuid
from concurrent.futures import ThreadPoolExecutor
from sqlalchemy import create_engine,select,text
from sqlalchemy.orm import Session
from fastapi import HTTPException
from app.models.user import User
from app.models.role import UserRole
from app.models.product_services import SupportTicket,SupportTicketMessage
from app.models.audit import AuditLog
from app.schemas.product_services import SupportTicketCreate,SupportTicketMessageCreate,SupportTicketManage
from app.services import help_service as service
import test_prelaunch_help_boundaries as fixture

class HelpPostgreSQLTests(fixture.HelpBoundariesTests):
    def make_engine(self):
        url=os.environ["DATABASE_URL"]
        assert "enactspace_pr2b_test_" in url and "@127.0.0.1/" in url
        return create_engine(url,pool_size=8,max_overflow=2)
    def wait_blocked(self):
        deadline=time.monotonic()+6
        while time.monotonic()<deadline:
            with self.engine.connect() as conn:
                count=conn.execute(text("SELECT count(*) FROM pg_stat_activity WHERE application_name='help-race' AND wait_event_type='Lock'")).scalar_one()
            if count:return
            time.sleep(.03)
        self.fail("The waiting mutation never reached a PostgreSQL row lock.")
    def run_action(self,actor_id,action):
        with Session(self.engine,expire_on_commit=False) as db:
            db.execute(text("SET application_name='help-race'"))
            actor=db.get(User,actor_id)
            try:
                action(db,actor)
                return 200
            except HTTPException as exc:
                db.rollback();return exc.status_code
    def test_two_simultaneous_submissions_record_one_ticket(self):
        key=uuid.uuid4();barrier=threading.Barrier(2)
        payload=SupportTicketCreate(subject="Même envoi",message="Une difficulté à corriger.",client_request_id=key)
        def action(db,actor):
            barrier.wait(8);return service.create_ticket(db,actor,payload)
        with ThreadPoolExecutor(max_workers=2) as pool:
            futures=[pool.submit(self.run_action,self.user.id,action) for _ in range(2)]
            self.assertEqual([f.result(15) for f in futures],[200,200])
        self.db.expire_all()
        self.assertEqual(self.db.query(SupportTicket).count(),1)
        self.assertEqual(self.db.query(AuditLog).filter_by(action="support_ticket_created").count(),1)
    def test_role_withdrawal_wins_against_waiting_management(self):
        item=self.ticket();target=uuid.UUID(item["id"])
        with Session(self.engine) as owner:
            owner.execute(select(User).where(User.id==self.sg.id).with_for_update()).scalar_one()
            owner.query(UserRole).filter_by(user_id=self.sg.id).delete();owner.flush()
            action=lambda db,actor:service.manage_ticket(db,actor,target,SupportTicketManage(status="closed"))
            with ThreadPoolExecutor(max_workers=1) as pool:
                future=pool.submit(self.run_action,self.sg.id,action)
                self.wait_blocked();owner.commit()
                self.assertEqual(future.result(15),403)
        self.db.expire_all()
        self.assertEqual(self.db.get(SupportTicket,target).status,"open")
    def test_suspension_wins_against_waiting_creation(self):
        with Session(self.engine) as owner:
            row=owner.execute(select(User).where(User.id==self.user.id).with_for_update()).scalar_one()
            row.status="suspended";owner.flush()
            action=lambda db,actor:service.create_ticket(db,actor,SupportTicketCreate(subject="Accès",message="Besoin d'aide"))
            with ThreadPoolExecutor(max_workers=1) as pool:
                future=pool.submit(self.run_action,self.user.id,action)
                self.wait_blocked();owner.commit()
                self.assertEqual(future.result(15),403)
        self.assertEqual(self.db.query(SupportTicket).count(),0)
    def test_closure_wins_against_waiting_member_reply(self):
        item=self.ticket();target=uuid.UUID(item["id"])
        with Session(self.engine) as owner:
            row=owner.execute(select(SupportTicket).where(SupportTicket.id==target).with_for_update()).scalar_one()
            row.status="closed";owner.flush()
            action=lambda db,actor:service.reply(db,actor,target,SupportTicketMessageCreate(message="Une précision"))
            with ThreadPoolExecutor(max_workers=1) as pool:
                future=pool.submit(self.run_action,self.user.id,action)
                self.wait_blocked();owner.commit()
                self.assertEqual(future.result(15),409)
        self.assertEqual(self.db.query(SupportTicketMessage).count(),1)
    def test_concurrent_management_cannot_overwrite_same_revision(self):
        item=self.ticket();target=uuid.UUID(item["id"]);barrier=threading.Barrier(2)
        payload=SupportTicketManage(status="in_progress",expected_updated_at=item["updated_at"])
        def action(db,actor):
            barrier.wait(8);return service.manage_ticket(db,actor,target,payload)
        with ThreadPoolExecutor(max_workers=2) as pool:
            futures=[pool.submit(self.run_action,self.sg.id,action) for _ in range(2)]
            self.assertEqual(sorted(f.result(15) for f in futures),[200,409])
        self.db.expire_all()
        self.assertEqual(self.db.query(AuditLog).filter_by(action="support_ticket_managed").count(),1)

if __name__=="__main__":unittest.main()
