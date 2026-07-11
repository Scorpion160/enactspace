from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.db.database import ensure_compatibility_columns
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
    files,
    documents,
    posts,
    chat,
    recruitment,
    alumni,
    notifications,
    gamification,
    impact,
    dashboard,
    academy,
    archives,
    audit,
    seed,
    realtime,
)


DEV_CORS_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:5000",
    "http://localhost:5173",
    "http://localhost:51833",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:5000",
    "http://127.0.0.1:5173",
    "http://127.0.0.1:51833",
]

IS_PRODUCTION = settings.APP_ENV.lower() == "production"
CORS_ALLOW_ORIGINS = (
    settings.cors_origins_list
    if IS_PRODUCTION
    else DEV_CORS_ORIGINS + settings.cors_origins_list
)
CORS_ALLOW_ORIGIN_REGEX = (
    None if IS_PRODUCTION else r"http://(localhost|127\.0\.0\.1):\d+"
)

app = FastAPI(
    title=settings.APP_NAME,
    debug=settings.APP_DEBUG,
)


@app.on_event("startup")
def ensure_database_compatibility() -> None:
    ensure_compatibility_columns()

configured_storage_path = Path(settings.FILE_STORAGE_PATH)
UPLOADS_DIR = (
    configured_storage_path
    if configured_storage_path.is_absolute()
    else Path(__file__).resolve().parents[1] / configured_storage_path
)
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(UPLOADS_DIR)), name="uploads")


app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ALLOW_ORIGINS,
    allow_origin_regex=CORS_ALLOW_ORIGIN_REGEX,
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
app.include_router(files.router, prefix="/api")
app.include_router(documents.router, prefix="/api")
app.include_router(posts.router, prefix="/api")
app.include_router(chat.router, prefix="/api")
app.include_router(recruitment.router, prefix="/api")
app.include_router(alumni.router, prefix="/api")
app.include_router(notifications.router, prefix="/api")
app.include_router(gamification.router, prefix="/api")
app.include_router(impact.router, prefix="/api")
app.include_router(dashboard.router, prefix="/api")
app.include_router(academy.router, prefix="/api")
app.include_router(archives.router, prefix="/api")
app.include_router(audit.router, prefix="/api")
app.include_router(seed.router, prefix="/api")
app.include_router(realtime.router, prefix="/api")
