"""環境変数から設定を読む。

ローカルと自動テストでは GCP なしで動かせるように、保存先・認証・Gemini・画像保存の
4 つを「本物」と「代わり」で切り替える。Cloud Run 上では本物以外を拒否する。
"""

import os
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict

StoreKind = Literal["memory", "firestore"]
AuthMode = Literal["dev", "firebase"]
GeminiKind = Literal["fake", "vertex"]
StorageKind = Literal["fake", "gcs"]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    store: StoreKind = "memory"
    auth_mode: AuthMode = "dev"
    gemini: GeminiKind = "fake"
    storage: StorageKind = "fake"

    google_cloud_project: str | None = None
    firebase_project_id: str | None = None
    firestore_database: str = "(default)"

    # Gemini だけ global を既定にするのは、モデルの提供リージョンに左右されないため
    # （Vertex AI のグローバルエンドポイント）。ほかのサービスはプロジェクト側の設定に従う。
    gemini_location: str = "global"
    gemini_model: str = "gemini-2.5-flash"

    avatar_bucket: str | None = None

    # avatarUrl と招待リンクを組み立てるための外から見える URL。
    # 無ければリクエストの Host から組み立てる（ローカル用）。
    public_base_url: str | None = None
    invite_base_url: str | None = None

    # 先に振った側の画面にも乾杯を出すため、POST /shakes が相手の振りを待つ最大秒数。0 で待たない
    cheer_wait_seconds: float = 5.0
    cheer_poll_seconds: float = 0.5

    # Firebase Hosting の rewrites で /api に向ける場合は "/api"
    api_prefix: str = ""

    # ブラウザ版のための CORS。カンマ区切りの完全一致と、開発用の正規表現。
    allowed_origins: str = ""
    allowed_origin_regex: str = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"

    @property
    def allowed_origin_list(self) -> list[str]:
        return [o.strip() for o in self.allowed_origins.split(",") if o.strip()]

    @property
    def resolved_firebase_project_id(self) -> str | None:
        return self.firebase_project_id or self.google_cloud_project

    def refuse_fakes_on_cloud_run(self) -> None:
        """Cloud Run 上で「代わり」の実装が有効なら起動させない。

        K_SERVICE は Cloud Run が必ず付ける環境変数
        （https://cloud.google.com/run/docs/container-contract#services-env-vars ）。
        dev 認証はトークンを検証しないので、本番で有効になっていたら誰でも他人になれる。
        """
        if not os.environ.get("K_SERVICE"):
            return
        fakes = [
            name
            for name, value, real in (
                ("AUTH_MODE", self.auth_mode, "firebase"),
                ("STORE", self.store, "firestore"),
                ("GEMINI", self.gemini, "vertex"),
                ("STORAGE", self.storage, "gcs"),
            )
            if value != real
        ]
        if fakes:
            raise RuntimeError(
                "Cloud Run 上でテスト用の設定が有効になっています: " + ", ".join(fakes)
            )


def load_settings() -> Settings:
    settings = Settings()
    settings.refuse_fakes_on_cloud_run()
    return settings
