"""Database-backed quotas persist after rejected/rolled-back requests."""
import hashlib,hmac,json
from datetime import timedelta
from fastapi import Depends,HTTPException,Request
from starlette.concurrency import run_in_threadpool
from sqlalchemy import case,delete,select,or_
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from app.core.config import settings
from app.core.time import utc_now
from app.db.database import get_db
from app.models.security_rate_limit import SecurityRateLimit

POLICIES={
 "/api/auth/activation/request":("activation_request",20,60,4,900),
 "/api/auth/activation/confirm":("activation_confirm",30,60,20,900),
 "/api/payments/paydunya/ipn":("paydunya_callback",240,60,0,0),
 "/api/auth/login":("login",60,60,20,900),
 "/api/auth/token":("login",60,60,20,900),
 "/api/auth/password-reset/request":("reset_request",20,60,4,900),
 "/api/auth/password-reset/confirm":("reset_confirm",30,60,20,900),
 "/api/auth/join-requests":("join",60,60,4,900),
 "/api/recruitment/applications":("application",60,60,4,900),
 "/api/recruitment/applications/with-files":("application",60,60,4,900),
 "/api/recruitment/applications/track":("tracking",60,60,30,900),
}

def counter_key(scope,kind,identifier):
    normalized=str(identifier).strip().lower()
    return hmac.new(settings.signing_secret.encode(),f"rate-limit:{scope}:{kind}:{normalized}".encode(),hashlib.sha256).hexdigest()

def consume_limits(db,limits,*,now=None):
    now=now or utc_now()
    dialect=db.get_bind().dialect.name
    insert=pg_insert if dialect=="postgresql" else sqlite_insert if dialect=="sqlite" else None
    if insert is None:raise RuntimeError("Unsupported rate-limit database")
    table=SecurityRateLimit
    retry=0
    for key,maximum,seconds in sorted(limits):
        expiry=now+timedelta(seconds=seconds)
        expired=table.expires_at<=now
        statement=insert(table).values(key=key,count=1,expires_at=expiry).on_conflict_do_update(
            index_elements=[table.key],
            set_={"count":case((expired,1),else_=table.count+1),
                  "expires_at":case((expired,expiry),else_=table.expires_at)},
            where=or_(expired,table.count<maximum),
        ).returning(table.count)
        if db.execute(statement).scalar_one_or_none() is None:
            existing=db.execute(select(table.expires_at).where(table.key==key)).scalar_one()
            retry=max(retry,max(1,int((existing-now).total_seconds())+1))
    db.commit()
    # Bounded expiration cleanup after releasing counter locks.
    obsolete=select(table.key).where(table.expires_at<=now).order_by(table.key).limit(100)
    db.execute(delete(table).where(table.expires_at<=now,table.key.in_(obsolete)).execution_options(synchronize_session=False))
    db.commit()
    if retry:
        raise HTTPException(429,"Trop de tentatives. Réessayez dans quelques instants.",headers={"Retry-After":str(retry)})

def _consume_on_bind(bind,limits):
    with Session(bind=bind) as counter_db:
        consume_limits(counter_db,limits)

async def protect_public_request(request:Request,db:Session=Depends(get_db)):
    policy=POLICIES.get(request.url.path.rstrip("/"))
    if request.method!="POST" or policy is None:return
    scope,ip_limit,ip_seconds,id_limit,id_seconds=policy
    # Uvicorn validates trusted proxies; never trust raw forwarded headers here.
    address=request.client.host if request.client else "unknown"
    limits=[(counter_key(scope,"ip",address),ip_limit,ip_seconds)]
    try:
        if not getattr(request.state,"public_ip_quota_checked",False):
            await run_in_threadpool(_consume_on_bind,db.get_bind(),limits)
        if "multipart/form-data" in request.headers.get("content-type","").lower():
            form=await request.form()
            payload=form.get("payload")
            if not isinstance(payload,str):return
            if len(payload.encode("utf-8"))>128*1024:
                raise HTTPException(413,"Cette demande est trop volumineuse.")
            try:data=json.loads(payload)
            except ValueError:return
        elif "application/x-www-form-urlencoded" in request.headers.get("content-type","").lower():
            # FastAPI may already have parsed the form; reuse its cached result.
            data=dict(await request.form())
        else:
            body=await request.body()
            maximum=128*1024 if scope=="application" else 65536 if scope=="join" else 16384
            if len(body)>maximum:raise HTTPException(413,"Cette demande est trop volumineuse.")
            try:data=json.loads(body)
            except (ValueError,UnicodeDecodeError):return
        if not isinstance(data,dict):return
        identity=data.get("identifier") or data.get("email") or data.get("username")
        if not isinstance(identity,str) or not identity.strip():return
        await run_in_threadpool(_consume_on_bind,db.get_bind(),[(counter_key(scope,"identity",identity),id_limit,id_seconds)])
    except SQLAlchemyError:
        raise HTTPException(503,"Le service est momentanément indisponible. Réessayez dans quelques instants.",headers={"Retry-After":"30"})
