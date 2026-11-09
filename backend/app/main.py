"""FastAPI アプリの組み立て。設定に応じて本物と「代わり」を選び、app.state に置く。"""

import logging
import time
from collections.abc import Callable
from datetime import datetime

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .auth import DevTokenVerifier, FirebaseTokenVerifier, TokenVerifier
from .config import Settings, load_settings
from .dates import now_utc
from .errors import install_error_handlers
from .routers import friends, me, protein, shakes
from .schemas import HealthResponse
from .services.gemini import FakeGemini, Gemini, VertexGemini
from .services.storage import AvatarStorage, FakeAvatarStorage, GcsAvatarStorage
from .store.base import Store
from .store.memory import MemoryStore

# Cloud Run は標準エラー出力をそのまま Cloud Logging に取り込む
logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")


def create_app(
    settings: Settings | None = None,
    *,
    store: Store | None = None,
    token_verifier: TokenVerifier | None = None,
    gemini: Gemini | None = None,
    avatar_storage: AvatarStorage | None = None,
    clock: Callable[[], datetime] | None = None,
    sleep: Callable[[float], None] | None = None,
) -> FastAPI:
    settings = settings or load_settings()
    app = FastAPI(title="プロテインで乾杯 API", version="0.1.0", docs_url=None, redoc_url=None)
    app.state.settings = settings
    app.state.store = store or build_store(settings)
    app.state.token_verifier = token_verifier or build_token_verifier(settings)
    app.state.gemini = gemini or build_gemini(settings)
    app.state.avatar_storage = avatar_storage or build_avatar_storage(settings)
    app.state.clock = clock or now_utc
    app.state.sleep = sleep or time.sleep

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origin_list,
        allow_origin_regex=settings.allowed_origin_regex,
        allow_methods=["GET", "POST", "PUT", "DELETE"],
        allow_headers=["Authorization", "Content-Type"],
        max_age=600,
    )
    install_error_handlers(app)

    prefix = settings.api_prefix
    app.include_router(me.router, prefix=prefix)
    app.include_router(shakes.router, prefix=prefix)
    app.include_router(friends.router, prefix=prefix)
    app.include_router(protein.router, prefix=prefix)

    @app.get(f"{prefix}/healthz", response_model=HealthResponse)
    def healthz():
        return HealthResponse(ok=True)

    return app


def build_store(settings: Settings) -> Store:
    if settings.store == "firestore":
        from .store.firestore import FirestoreStore

        return FirestoreStore(
            project=settings.google_cloud_project, database=settings.firestore_database
        )
    return MemoryStore()


def build_token_verifier(settings: Settings) -> TokenVerifier:
    if settings.auth_mode == "firebase":
        return FirebaseTokenVerifier(settings.resolved_firebase_project_id)
    return DevTokenVerifier()


def build_gemini(settings: Settings) -> Gemini:
    if settings.gemini == "vertex":
        return VertexGemini(
            settings.google_cloud_project, settings.gemini_location, settings.gemini_model
        )
    return FakeGemini()


def build_avatar_storage(settings: Settings) -> AvatarStorage:
    if settings.storage == "gcs":
        if not settings.avatar_bucket:
            raise RuntimeError("STORAGE=gcs には AVATAR_BUCKET が必要です")
        return GcsAvatarStorage(settings.avatar_bucket, settings.google_cloud_project)
    return FakeAvatarStorage()


app = create_app()
