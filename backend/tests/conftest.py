from datetime import UTC, datetime, timedelta
from urllib.parse import quote

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.services.gemini import FakeGemini
from app.services.storage import FakeAvatarStorage
from app.store.memory import MemoryStore

START = datetime(2026, 11, 9, 1, 0, 0, tzinfo=UTC)  # 日本時間 11/9（月）10:00


class FakeClock:
    def __init__(self, start: datetime = START) -> None:
        self.current = start

    def now(self) -> datetime:
        return self.current

    def advance(self, **delta) -> None:
        self.current += timedelta(**delta)


def as_user(uid: str, name: str = "こうたろう") -> dict[str, str]:
    return {"Authorization": f"Bearer dev:{uid}:{quote(name)}"}


PNG_1PX = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"
    "0000000d4944415478da63fcffff3f0300050001ff6f0b2b0000000049454e44ae426082"
)


@pytest.fixture
def clock() -> FakeClock:
    return FakeClock()


@pytest.fixture
def store() -> MemoryStore:
    return MemoryStore()


@pytest.fixture
def gemini() -> FakeGemini:
    return FakeGemini()


@pytest.fixture
def avatar_storage() -> FakeAvatarStorage:
    return FakeAvatarStorage()


@pytest.fixture
def settings() -> Settings:
    return Settings(
        _env_file=None,
        store="memory",
        auth_mode="dev",
        gemini="fake",
        storage="fake",
        public_base_url="https://api.test",
        invite_base_url="https://app.test",
    )


class FakeSleep:
    """待ち時間を進める代わりに時計を進める。テストが実時間で待たないようにするため。"""

    def __init__(self, clock: FakeClock) -> None:
        self.clock = clock
        self.calls: list[float] = []
        self.on_sleep = None

    def __call__(self, seconds: float) -> None:
        self.calls.append(seconds)
        self.clock.advance(seconds=seconds)
        if self.on_sleep:
            self.on_sleep()


@pytest.fixture
def sleep(clock) -> FakeSleep:
    return FakeSleep(clock)


@pytest.fixture
def app(settings, clock, sleep, store, gemini, avatar_storage):
    return create_app(
        settings,
        store=store,
        gemini=gemini,
        avatar_storage=avatar_storage,
        clock=clock.now,
        sleep=sleep,
    )


@pytest.fixture
def client(app) -> TestClient:
    return TestClient(app)
