import pytest

from app.store.memory import MemoryStore
from tests.store_contract import StoreContract


class TestMemoryStore(StoreContract):
    @pytest.fixture
    def store(self):
        return MemoryStore()
