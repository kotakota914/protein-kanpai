"""Firestore 実装の契約テスト。エミュレータがあるときだけ動く。

実行：
  cd backend && firebase emulators:exec --only firestore --project demo-kanpai \\
    "uv run pytest tests/test_store_firestore.py -q"
"""

import os

import httpx
import pytest

from tests.store_contract import StoreContract

EMULATOR_HOST = os.environ.get("FIRESTORE_EMULATOR_HOST")
PROJECT = os.environ.get("GCLOUD_PROJECT", "demo-kanpai")

pytestmark = pytest.mark.skipif(not EMULATOR_HOST, reason="FIRESTORE_EMULATOR_HOST が無い")


def clear_emulator() -> None:
    url = f"http://{EMULATOR_HOST}/emulator/v1/projects/{PROJECT}/databases/(default)/documents"
    httpx.delete(url, timeout=10).raise_for_status()


class TestFirestoreStore(StoreContract):
    @pytest.fixture
    def store(self):
        from app.store.firestore import FirestoreStore

        clear_emulator()
        return FirestoreStore(project=PROJECT)
