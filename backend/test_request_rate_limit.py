"""Quotas and proxy-header trust on synthetic HTTP requests."""
import os
os.environ.setdefault("DATABASE_URL","sqlite://")
os.environ.setdefault("APP_ENV","test")
os.environ.setdefault("SECRET_KEY","isolated-prelaunch-secret")
os.environ.setdefault("AUTO_CREATE_TABLES","false")
import unittest
from datetime import timedelta
from unittest.mock import patch
from fastapi import FastAPI,Depends,HTTPException
from fastapi.testclient import TestClient
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware
from app.db.database import get_db
from app.core.time import utc_now
from app.services import request_rate_limit as limiter
from app.models.security_rate_limit import SecurityRateLimit
import test_profile_photo as photo_fixture

class SharedQuotaTests(unittest.TestCase):
    setUp=photo_fixture.ProfilePhotoTests.setUp
    tearDown=photo_fixture.ProfilePhotoTests.tearDown

    def client(self,policy):
        app=FastAPI();app.dependency_overrides[get_db]=lambda:self.db
        @app.post("/api/auth/login",dependencies=[Depends(limiter.protect_public_request)])
        def attempt():raise HTTPException(401,"Identifiant ou mot de passe incorrect")
        return TestClient(app),patch.dict(limiter.POLICIES,{"/api/auth/login":policy})

    def test_form_and_json_login_share_the_same_identity_budget(self):
        from app.api.routes import auth
        app=FastAPI();app.dependency_overrides[get_db]=lambda:self.db
        app.include_router(auth.router,prefix="/api")
        policy=("login",10,60,1,900)
        with patch.dict(limiter.POLICIES,{"/api/auth/login":policy,"/api/auth/token":policy}),TestClient(app) as client:
            response=client.post("/api/auth/token",data={"username":"unknownmember","password":"invalid-test-password"})
            self.assertEqual(response.status_code,401)
            response=client.post("/api/auth/login",json={"identifier":"unknownmember","password":"invalid-test-password"})
            self.assertEqual(response.status_code,429)

    def test_failed_requests_consume_budget_and_report_retry_after(self):
        client,policy=self.client(("login",10,60,2,900))
        with policy,client:
            for _ in range(2):self.assertEqual(client.post("/api/auth/login",json={"identifier":"member"}).status_code,401)
            self.db.rollback()
            response=client.post("/api/auth/login",json={"identifier":"member"})
            self.assertEqual(response.status_code,429)
            self.assertGreater(int(response.headers["retry-after"]),0)

    def test_raw_forwarded_header_cannot_bypass_ip_quota(self):
        client,policy=self.client(("login",2,60,100,900))
        with policy,client:
            for i in range(2):self.assertEqual(client.post("/api/auth/login",json={"identifier":f"user{i}"},headers={"X-Forwarded-For":f"203.0.113.{i}"}).status_code,401)
            self.assertEqual(client.post("/api/auth/login",json={"identifier":"different"},headers={"X-Forwarded-For":"198.51.100.9"}).status_code,429)

    def test_identifiers_are_normalized_and_not_stored_raw(self):
        self.assertEqual(limiter.counter_key("login","identity"," USER@EXAMPLE.ORG "),limiter.counter_key("login","identity","user@example.org"))
        key=limiter.counter_key("login","identity","user@example.org")
        with limiter.Session(bind=self.engine) as db:limiter.consume_limits(db,[(key,2,60)])
        row=self.db.query(SecurityRateLimit).one()
        self.assertEqual(len(row.key),64)
        self.assertNotIn("example",row.key)

    def test_expiry_reopens_budget_and_cleanup_preserves_active_counters(self):
        now=utc_now();key=limiter.counter_key("login","identity","member")
        with limiter.Session(bind=self.engine) as db:
            limiter.consume_limits(db,[(key,1,60)],now=now)
            with self.assertRaises(HTTPException):limiter.consume_limits(db,[(key,1,60)],now=now+timedelta(seconds=1))
            limiter.consume_limits(db,[(key,1,60)],now=now+timedelta(seconds=61))
        self.assertEqual(self.db.query(SecurityRateLimit).one().count,1)

    def test_missing_storage_fails_closed_without_technical_message(self):
        SecurityRateLimit.__table__.drop(self.engine)
        client,policy=self.client(("login",2,60,100,900))
        with policy,client:
            response=client.post("/api/auth/login",json={"identifier":"member"})
            self.assertEqual(response.status_code,503)
            self.assertNotIn("sqlite",response.text.lower())

    def test_only_trusted_proxy_can_supply_client_address(self):
        from fastapi import Request
        from fastapi.responses import PlainTextResponse
        capture=FastAPI()
        @capture.get("/")
        def observed(request:Request):return PlainTextResponse(request.client.host)
        app=ProxyHeadersMiddleware(capture,trusted_hosts=["172.20.0.1"])
        with TestClient(app,client=("198.51.100.9",12345)) as client:
            response=client.get("/",headers={"X-Forwarded-For":"203.0.113.1"})
            self.assertEqual(response.text,"198.51.100.9")
        with TestClient(app,client=("172.20.0.1",12345)) as client:
            response=client.get("/",headers={"X-Forwarded-For":"192.0.2.1, 203.0.113.9"})
            self.assertEqual(response.text,"203.0.113.9")

if __name__=="__main__":unittest.main()
