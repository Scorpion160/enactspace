"""Pre-parsing ASGI protections on ephemeral SQLite and synthetic streams."""
import os
os.environ.setdefault("DATABASE_URL","sqlite://")
os.environ.setdefault("APP_ENV","test")
os.environ.setdefault("SECRET_KEY","isolated-prelaunch-secret")
os.environ.setdefault("AUTO_CREATE_TABLES","false")
import asyncio,unittest
from unittest.mock import patch
from fastapi import FastAPI,File,UploadFile
from fastapi.testclient import TestClient
from app.api.routes import auth
from app.db.database import get_db
from app.models.security_rate_limit import SecurityRateLimit
from app.services import public_request_protection as protection
from app.services import request_rate_limit as limiter
import test_profile_photo as photo_fixture

class EarlyProtectionTests(unittest.TestCase):
    setUp=photo_fixture.ProfilePhotoTests.setUp
    tearDown=photo_fixture.ProfilePhotoTests.tearDown

    def request(self,headers=(),chunks=(b"{}",),path="/api/auth/login"):
        result={"receive_calls":0,"completed":False,"messages":[]}
        queue=[{"type":"http.request","body":chunk,"more_body":i<len(chunks)-1} for i,chunk in enumerate(chunks)]
        async def receive():
            result["receive_calls"]+=1
            return queue.pop(0)
        async def send(message):result["messages"].append(message)
        async def application(scope,receive,send):
            while (await receive()).get("more_body",False):pass
            result["completed"]=True
            await send({"type":"http.response.start","status":200,"headers":[]})
            await send({"type":"http.response.body","body":b"ok"})
        scope={"type":"http","method":"POST","path":path,"headers":list(headers),"client":("203.0.113.1",12345)}
        middleware=protection.PublicRequestProtectionMiddleware(application,database_bind=self.engine)
        asyncio.run(middleware(scope,receive,send))
        result["status"]=next(m["status"] for m in result["messages"] if m["type"]=="http.response.start")
        return result

    def test_declared_oversize_is_rejected_without_reading_body(self):
        with patch.dict(protection.BODY_LIMITS,{"/api/auth/login":16}):
            response=self.request(headers=[(b"content-length",b"17")])
        self.assertEqual(response["status"],413)
        self.assertEqual(response["receive_calls"],0)
        self.assertFalse(response["completed"])

    def test_missing_or_false_length_cannot_bypass_actual_stream_limit(self):
        for headers in [[],[(b"content-length",b"1")]]:
            with patch.dict(protection.BODY_LIMITS,{"/api/auth/login":16}):
                response=self.request(headers=headers,chunks=(b"x"*12,b"x"*12))
            self.assertEqual(response["status"],413)
            self.assertFalse(response["completed"])

    def test_duplicate_or_invalid_lengths_are_rejected_before_reading(self):
        for headers in [[(b"content-length",b"-1")],[(b"content-length",b"1"),(b"content-length",b"2")],[(b"content-length",b"text")]]:
            response=self.request(headers=headers)
            self.assertEqual(response["status"],400)
            self.assertEqual(response["receive_calls"],0)

    def test_exhausted_quota_is_rejected_before_body_receive(self):
        with patch.dict(limiter.POLICIES,{"/api/auth/login":("login",1,60,10,900)}):
            self.assertEqual(self.request()["status"],200)
            response=self.request(chunks=(b"x"*200000,))
        self.assertEqual(response["status"],429)
        self.assertEqual(response["receive_calls"],0)

    def test_multipart_parser_is_not_called_for_declared_oversize(self):
        app=FastAPI()
        @app.post("/api/recruitment/applications/with-files")
        async def upload(file:UploadFile=File(...)):return {"ok":True}
        app.add_middleware(protection.PublicRequestProtectionMiddleware,database_bind=self.engine)
        with patch.dict(protection.BODY_LIMITS,{"/api/recruitment/applications/with-files":16}),patch("starlette.formparsers.MultiPartParser.parse",side_effect=AssertionError("Parser must not run")),TestClient(app) as client:
            response=client.post("/api/recruitment/applications/with-files",files={"file":("cv.pdf",b"%PDF-test")})
            self.assertEqual(response.status_code,413)

    def test_middleware_and_route_dependency_count_network_attempt_once(self):
        app=FastAPI();app.dependency_overrides[get_db]=lambda:self.db
        app.include_router(auth.router,prefix="/api")
        app.add_middleware(protection.PublicRequestProtectionMiddleware,database_bind=self.engine)
        with patch.dict(limiter.POLICIES,{"/api/auth/login":("login",2,60,20,900)}),TestClient(app) as client:
            for _ in range(2):
                self.assertEqual(client.post("/api/auth/login",json={"identifier":"not-a-member","password":"test-only-password"}).status_code,401)
            self.assertEqual(client.post("/api/auth/login",json={"identifier":"different","password":"test-only-password"}).status_code,429)
        key=limiter.counter_key("login","ip","testclient")
        self.assertEqual(self.db.get(SecurityRateLimit,key).count,2)

    def test_multipart_and_json_submission_share_identity_budget(self):
        from fastapi import Form,Depends
        import json
        app=FastAPI();app.dependency_overrides[get_db]=lambda:self.db
        @app.post("/api/recruitment/applications/with-files",dependencies=[Depends(limiter.protect_public_request)])
        def multipart(payload:str=Form(...)):return {"ok":True}
        @app.post("/api/recruitment/applications",dependencies=[Depends(limiter.protect_public_request)])
        def plain(payload:dict):return {"ok":True}
        app.add_middleware(protection.PublicRequestProtectionMiddleware,database_bind=self.engine)
        policy=("application",20,60,1,900)
        policies={"/api/recruitment/applications":policy,"/api/recruitment/applications/with-files":policy}
        with patch.dict(limiter.POLICIES,policies),TestClient(app) as client:
            response=client.post("/api/recruitment/applications/with-files",data={"payload":json.dumps({"email":"candidate@example.org"})},files={"cv":("cv.pdf",b"%PDF-test")})
            self.assertEqual(response.status_code,200,response.text)
            response=client.post("/api/recruitment/applications",json={"email":"candidate@example.org"})
            self.assertEqual(response.status_code,429,response.text)

    def test_legitimate_small_request_is_passed_through(self):
        self.assertEqual(self.request()["status"],200)

    def test_callback_body_limit_applies_before_parser_and_to_real_stream(self):
        path="/api/payments/paydunya/ipn"
        response=self.request(path=path,headers=[(b"content-length",b"65537")])
        self.assertEqual(response["status"],413);self.assertEqual(response["receive_calls"],0)
        response=self.request(path=path,chunks=(b"x"*40000,b"x"*40000))
        self.assertEqual(response["status"],413);self.assertFalse(response["completed"])
    def test_callback_quota_is_shared_and_rejected_before_body_receive(self):
        path="/api/payments/paydunya/ipn"
        with patch.dict(limiter.POLICIES,{path:("paydunya_callback",1,60,0,0)}):
            self.assertEqual(self.request(path=path)["status"],200)
            response=self.request(path=path,chunks=(b"x"*80000,))
        self.assertEqual(response["status"],429);self.assertEqual(response["receive_calls"],0)

if __name__=="__main__":unittest.main()
