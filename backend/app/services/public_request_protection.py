"""Bound request streams and public IP quotas before FastAPI body parsing."""
from fastapi import HTTPException
from starlette.responses import JSONResponse
from starlette.concurrency import run_in_threadpool
from sqlalchemy.exc import SQLAlchemyError
from app.db.database import engine
from app.services.request_rate_limit import POLICIES,counter_key,_consume_on_bind

DEFAULT_BODY_LIMIT=501*1024*1024
BODY_LIMITS={
 "/api/payments/paydunya/ipn":65536,
 "/api/auth/login":16384,
 "/api/auth/token":16384,
 "/api/auth/password-reset/request":16384,
 "/api/auth/password-reset/confirm":16384,
 "/api/auth/join-requests":65536,
 "/api/recruitment/applications":128*1024,
 "/api/recruitment/applications/with-files":32*1024*1024,
 "/api/recruitment/applications/track":16384,
}

class PublicRequestProtectionMiddleware:
    def __init__(self,app,database_bind=None):
        self.app=app
        self.bind=database_bind if database_bind is not None else engine

    async def __call__(self,scope,receive,send):
        if scope["type"]!="http" or scope.get("method") not in {"POST","PUT","PATCH"}:
            await self.app(scope,receive,send)
            return
        path=scope.get("path","").rstrip("/")
        response_started=False
        async def tracked_send(message):
            nonlocal response_started
            if message["type"]=="http.response.start":
                response_started=True
            await send(message)
        try:
            policy=POLICIES.get(path) if scope["method"]=="POST" else None
            if policy:
                name,maximum,seconds,_,_=policy
                client=scope.get("client")
                address=client[0] if client else "unknown"
                await run_in_threadpool(_consume_on_bind,self.bind,[(counter_key(name,"ip",address),maximum,seconds)])
                scope.setdefault("state",{})["public_ip_quota_checked"]=True
            maximum=BODY_LIMITS.get(path,DEFAULT_BODY_LIMIT)
            lengths=[value for key,value in scope.get("headers",[]) if key.lower()==b"content-length"]
            if lengths:
                if len(lengths)!=1 or not lengths[0].isdigit():
                    raise HTTPException(400,"La demande envoyée est invalide.")
                if int(lengths[0])>maximum:
                    raise HTTPException(413,"La demande dépasse la taille autorisée.")
            consumed=0
            async def bounded_receive():
                nonlocal consumed
                message=await receive()
                if message["type"]=="http.request":
                    consumed+=len(message.get("body",b""))
                    if consumed>maximum:
                        raise HTTPException(413,"La demande dépasse la taille autorisée.")
                return message
            await self.app(scope,bounded_receive,tracked_send)
        except SQLAlchemyError:
            if response_started:raise
            await JSONResponse({"detail":"Le service est momentanément indisponible. Réessayez dans quelques instants."},status_code=503,headers={"Retry-After":"30"})(scope,receive,send)
        except HTTPException as error:
            if response_started:raise
            await JSONResponse({"detail":error.detail},status_code=error.status_code,headers=error.headers)(scope,receive,send)
