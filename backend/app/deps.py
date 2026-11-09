"""ルーターが使う依存の取り出し。実体は main.create_app が app.state に置く。"""

from collections.abc import Callable
from datetime import datetime
from typing import Annotated

from fastapi import Depends, Header, Request

from .auth import TokenVerifier, bearer_token_of
from .config import Settings
from .services.gemini import Gemini
from .services.storage import AvatarStorage
from .store.base import Store, UserRecord

Clock = Callable[[], datetime]
Sleep = Callable[[float], None]


def resolve_settings(request: Request) -> Settings:
    return request.app.state.settings


def resolve_store(request: Request) -> Store:
    return request.app.state.store


def resolve_clock(request: Request) -> Clock:
    return request.app.state.clock


def resolve_sleep(request: Request) -> Sleep:
    return request.app.state.sleep


def resolve_gemini(request: Request) -> Gemini:
    return request.app.state.gemini


def resolve_avatar_storage(request: Request) -> AvatarStorage:
    return request.app.state.avatar_storage


def resolve_public_origin(request: Request) -> str:
    """外から見えるこのサーバーの起点（https://host）。API_PREFIX は含まない。"""
    settings: Settings = request.app.state.settings
    origin = settings.public_base_url or f"{request.url.scheme}://{request.headers.get('host', '')}"
    return origin.rstrip("/")


def resolve_public_base_url(request: Request) -> str:
    """avatarUrl などに使う、外から見える API の土台 URL。API_PREFIX 込み、末尾の / 無し。"""
    settings: Settings = request.app.state.settings
    return resolve_public_origin(request) + settings.api_prefix


def require_current_user(
    request: Request,
    authorization: Annotated[str | None, Header()] = None,
) -> UserRecord:
    """トークンを検証し、初めての人なら users に作ってから返す。"""
    verifier: TokenVerifier = request.app.state.token_verifier
    store: Store = request.app.state.store
    clock: Clock = request.app.state.clock
    identity = verifier.verify(bearer_token_of(authorization))
    return store.create_user_if_absent(
        UserRecord(id=identity.uid, name=identity.name, created_at=clock())
    )


SettingsDep = Annotated[Settings, Depends(resolve_settings)]
StoreDep = Annotated[Store, Depends(resolve_store)]
ClockDep = Annotated[Clock, Depends(resolve_clock)]
SleepDep = Annotated[Sleep, Depends(resolve_sleep)]
GeminiDep = Annotated[Gemini, Depends(resolve_gemini)]
AvatarStorageDep = Annotated[AvatarStorage, Depends(resolve_avatar_storage)]
PublicBaseUrlDep = Annotated[str, Depends(resolve_public_base_url)]
PublicOriginDep = Annotated[str, Depends(resolve_public_origin)]
CurrentUserDep = Annotated[UserRecord, Depends(require_current_user)]
