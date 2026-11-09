"""Authorization: Bearer <トークン> から「誰か」を決める。

- firebase：Firebase Authentication の ID トークンを Firebase Admin SDK で検証する。
- dev：`dev:<uid>:<名前>` をそのまま信じる。名前は URL エンコード（HTTP ヘッダーは ASCII のみ）。
  ローカルと自動テスト専用
  （Cloud Run 上では config.refuse_fakes_on_cloud_run が起動を止める）。
"""

import logging
from dataclasses import dataclass
from typing import Protocol
from urllib.parse import unquote

from . import errors

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class Identity:
    uid: str
    name: str


class TokenVerifier(Protocol):
    def verify(self, token: str) -> Identity: ...


class DevTokenVerifier:
    PREFIX = "dev:"

    def verify(self, token: str) -> Identity:
        if not token.startswith(self.PREFIX):
            raise errors.unauthenticated("dev モードのトークンは dev:<uid>:<名前> の形です")
        parts = token[len(self.PREFIX) :].split(":", 1)
        uid = parts[0].strip()
        if not uid:
            raise errors.unauthenticated("uid が空です")
        name = unquote(parts[1]).strip() if len(parts) == 2 else ""
        return Identity(uid=uid, name=name or "名無し")


class FirebaseTokenVerifier:
    def __init__(self, project_id: str | None) -> None:
        import firebase_admin

        if not firebase_admin._apps:
            options = {"projectId": project_id} if project_id else None
            firebase_admin.initialize_app(options=options)

    def verify(self, token: str) -> Identity:
        from firebase_admin import auth as firebase_auth

        try:
            # 端末の時計が少し進んでいて iat が未来になる事故を吸収する（最大 10 秒）
            claims = firebase_auth.verify_id_token(token, clock_skew_seconds=10)
        except firebase_auth.ExpiredIdTokenError as exc:
            raise errors.unauthenticated("ログインの期限が切れました") from exc
        except firebase_auth.CertificateFetchError as exc:
            logger.exception("Firebase の公開鍵を取得できなかった")
            raise errors.ai_unavailable("ログインの確認に失敗しました") from exc
        except (firebase_auth.InvalidIdTokenError, ValueError) as exc:
            raise errors.unauthenticated() from exc
        return Identity(uid=claims["uid"], name=display_name_from_claims(claims))


def display_name_from_claims(claims: dict) -> str:
    name = (claims.get("name") or "").strip()
    if name:
        return name
    email = claims.get("email") or ""
    if "@" in email:
        return email.split("@", 1)[0]
    return "名無し"


def bearer_token_of(authorization_header: str | None) -> str:
    if not authorization_header:
        raise errors.unauthenticated()
    scheme, _, token = authorization_header.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise errors.unauthenticated()
    return token.strip()
