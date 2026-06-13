from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.api.routes import (
    auth,
    users,
    seasons,
    poles,
    projects,
    events,
    attendance,
    finance,
    tasks,
    documents,
    posts,
    recruitment,
    alumni,
    notifications,
    gamification,
    audit,
    seed,
)


app = FastAPI(
    title=settings.APP_NAME,
    debug=settings.APP_DEBUG,
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:5000",
        "http://localhost:5173",
        "http://localhost:51833",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5000",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:51833",
    ],
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1):\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    return {
        "ok": True,
        "app": settings.APP_NAME,
        "env": settings.APP_ENV,
    }


@app.get("/health")
def health():
    return {
        "ok": True,
        "service": settings.APP_NAME,
    }


app.include_router(auth.router, prefix="/api")
app.include_router(users.router, prefix="/api")
app.include_router(seasons.router, prefix="/api")
app.include_router(poles.router, prefix="/api")
app.include_router(projects.router, prefix="/api")
app.include_router(events.router, prefix="/api")
app.include_router(attendance.router, prefix="/api")
app.include_router(finance.router, prefix="/api")
app.include_router(tasks.router, prefix="/api")
app.include_router(documents.router, prefix="/api")
app.include_router(posts.router, prefix="/api")
app.include_router(recruitment.router, prefix="/api")
app.include_router(alumni.router, prefix="/api")
app.include_router(notifications.router, prefix="/api")
app.include_router(gamification.router, prefix="/api")
app.include_router(audit.router, prefix="/api")
app.include_router(seed.router, prefix="/api")