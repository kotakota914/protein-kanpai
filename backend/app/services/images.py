"""アップロードされた画像の受け取りと形式の判定。Content-Type ヘッダーは信用しない。"""

from fastapi import Request

from .. import errors

_PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
_JPEG_SIGNATURE = b"\xff\xd8\xff"


def detect_image_type(image: bytes) -> str | None:
    """先頭バイトで PNG / JPEG を見分ける。それ以外は None。"""
    if image.startswith(_PNG_SIGNATURE):
        return "image/png"
    if image.startswith(_JPEG_SIGNATURE):
        return "image/jpeg"
    return None


async def read_image_within(request: Request, max_bytes: int) -> tuple[bytes, str]:
    """本文を読み、大きすぎれば 413、画像でなければ 400。(バイト列, MIME) を返す。"""
    declared = request.headers.get("content-length")
    if declared and declared.isdigit() and int(declared) > max_bytes:
        raise errors.too_large()
    body = await request.body()
    if len(body) > max_bytes:
        raise errors.too_large()
    if not body:
        raise errors.bad_image("画像が空です")
    content_type = detect_image_type(body)
    if content_type is None:
        raise errors.bad_image()
    return body, content_type
