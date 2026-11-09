"""エラーの形を契約（docs/api-contract.md）の {"error": {"code", "message"}} にそろえる。"""

import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger(__name__)


class ApiError(Exception):
    def __init__(self, status_code: int, code: str, message: str) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message


def invalid_argument(message: str) -> ApiError:
    return ApiError(400, "INVALID_ARGUMENT", message)


def bad_image(message: str = "画像の形式が読み取れません") -> ApiError:
    return ApiError(400, "BAD_IMAGE", message)


def unauthenticated(message: str = "ログインが必要です") -> ApiError:
    return ApiError(401, "UNAUTHENTICATED", message)


def forbidden(message: str = "この操作はできません") -> ApiError:
    return ApiError(403, "FORBIDDEN", message)


def not_found(message: str = "見つかりません") -> ApiError:
    return ApiError(404, "NOT_FOUND", message)


def too_large(message: str = "写真が大きすぎます") -> ApiError:
    return ApiError(413, "TOO_LARGE", message)


def unreadable(message: str = "読み取れませんでした。撮り直してください") -> ApiError:
    return ApiError(422, "UNREADABLE", message)


def too_many(message: str = "少し待ってからもう一度") -> ApiError:
    return ApiError(429, "TOO_MANY", message)


def ai_unavailable(message: str = "いまは使えません。時間をおいてください") -> ApiError:
    return ApiError(503, "AI_UNAVAILABLE", message)


_CODE_BY_STATUS = {
    400: "INVALID_ARGUMENT",
    401: "UNAUTHENTICATED",
    403: "FORBIDDEN",
    404: "NOT_FOUND",
    405: "METHOD_NOT_ALLOWED",
    413: "TOO_LARGE",
    422: "UNREADABLE",
    429: "TOO_MANY",
    503: "AI_UNAVAILABLE",
}


def error_response(status_code: int, code: str, message: str) -> JSONResponse:
    return JSONResponse(
        status_code=status_code, content={"error": {"code": code, "message": message}}
    )


def install_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def on_api_error(_: Request, exc: ApiError) -> JSONResponse:
        return error_response(exc.status_code, exc.code, exc.message)

    # FastAPI の入力検証は既定で 422 を返すが、契約では 422 を「写真が読めない」に
    # 使っているので、入力の形の誤りは 400 に寄せる。
    @app.exception_handler(RequestValidationError)
    async def on_validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
        return error_response(400, "INVALID_ARGUMENT", "入力を確認してください")

    @app.exception_handler(StarletteHTTPException)
    async def on_http_error(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        code = _CODE_BY_STATUS.get(exc.status_code, "ERROR")
        return error_response(exc.status_code, code, str(exc.detail))

    # 想定外の例外も同じ封筒で返す。中身はログにだけ出す（Cloud Logging で追えるように）
    @app.exception_handler(Exception)
    async def on_unexpected_error(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("unhandled error: %s %s", request.method, request.url.path)
        return error_response(500, "INTERNAL", "サーバーでエラーが起きました")
