from __future__ import annotations

import os
from pathlib import Path

import firebase_admin
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from firebase_admin import credentials

from app.config import get_settings
from app.routes.sessions import router as sessions_router

# Flutter web build output copied here before Cloud Run deploy.
_STATIC_DIR = Path(__file__).resolve().parent / "static"


def _init_firebase() -> None:
    if firebase_admin._apps:
        return
    settings = get_settings()
    # Prefer ADC / Cloud Run default SA. Optional GOOGLE_APPLICATION_CREDENTIALS for local.
    try:
        firebase_admin.initialize_app(
            options={"projectId": settings.firebase_project_id}
        )
    except Exception:
        cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        if cred_path and os.path.exists(cred_path):
            firebase_admin.initialize_app(
                credentials.Certificate(cred_path),
                options={"projectId": settings.firebase_project_id},
            )
        else:
            firebase_admin.initialize_app(
                credentials.ApplicationDefault(),
                options={"projectId": settings.firebase_project_id},
            )


def _mount_web_app(app: FastAPI) -> None:
    """Serve Flutter web (SPA) from app/static when present."""
    if not _STATIC_DIR.is_dir() or not (_STATIC_DIR / "index.html").is_file():
        return

    assets_dir = _STATIC_DIR / "assets"
    if assets_dir.is_dir():
        app.mount("/assets", StaticFiles(directory=assets_dir), name="assets")

    canvaskit_dir = _STATIC_DIR / "canvaskit"
    if canvaskit_dir.is_dir():
        app.mount(
            "/canvaskit",
            StaticFiles(directory=canvaskit_dir),
            name="canvaskit",
        )

    @app.get("/")
    async def web_index() -> FileResponse:
        return FileResponse(_STATIC_DIR / "index.html")

    @app.get("/{full_path:path}")
    async def web_spa(full_path: str) -> FileResponse:
        # Never shadow API / health (registered earlier).
        candidate = _STATIC_DIR / full_path
        if candidate.is_file():
            return FileResponse(candidate)
        return FileResponse(_STATIC_DIR / "index.html")


def create_app() -> FastAPI:
    settings = get_settings()
    _init_firebase()

    app = FastAPI(
        title="Tomorrow Planter API",
        version="0.1.0",
        description="Night reflection → multi-agent discussion → tomorrow plan",
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(sessions_router)

    @app.get("/health")
    async def health() -> dict:
        return {
            "status": "ok",
            "project": settings.gcp_project_id,
            "location": settings.gcp_location,
        }

    _mount_web_app(app)
    return app


app = create_app()
