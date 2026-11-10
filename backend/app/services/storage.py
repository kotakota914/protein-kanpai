"""アイコン画像の保存先。gcs：Cloud Storage（非公開バケット）。fake：メモリ。

画像は API の GET /avatars/{userId} 経由でしか配らないので、バケットは公開しない。
"""

from typing import Protocol


class AvatarStorage(Protocol):
    def save(self, user_id: str, image: bytes, content_type: str) -> None: ...
    def load(self, user_id: str) -> bytes | None: ...
    def delete(self, user_id: str) -> None: ...


class FakeAvatarStorage:
    def __init__(self) -> None:
        self._images: dict[str, bytes] = {}

    def save(self, user_id: str, image: bytes, content_type: str) -> None:
        self._images[user_id] = image

    def load(self, user_id: str) -> bytes | None:
        return self._images.get(user_id)

    def delete(self, user_id: str) -> None:
        self._images.pop(user_id, None)


class GcsAvatarStorage:
    def __init__(self, bucket_name: str, project: str | None = None) -> None:
        from google.cloud import storage

        self._bucket = storage.Client(project=project).bucket(bucket_name)

    def save(self, user_id: str, image: bytes, content_type: str) -> None:
        self._blob(user_id).upload_from_string(image, content_type=content_type)

    def load(self, user_id: str) -> bytes | None:
        from google.api_core.exceptions import NotFound

        try:
            return self._blob(user_id).download_as_bytes()
        except NotFound:
            return None

    def delete(self, user_id: str) -> None:
        from google.api_core.exceptions import NotFound

        try:
            self._blob(user_id).delete()
        except NotFound:
            pass

    def _blob(self, user_id: str):
        return self._bucket.blob(f"avatars/{user_id}")
