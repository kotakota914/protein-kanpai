"""プロテインの袋の写真から、商品名・味・たんぱく質量を読み取る（Gemini）。"""

from fastapi import APIRouter, Request
from starlette.concurrency import run_in_threadpool

from .. import errors
from ..deps import ClockDep, CurrentUserDep, GeminiDep, StoreDep
from ..schemas import ProteinScanResponse
from ..services.images import read_image_within

router = APIRouter()

MAX_SCAN_BYTES = 10 * 1024 * 1024
SCAN_COOLDOWN_SECONDS = 5


@router.post("/protein/scan", response_model=ProteinScanResponse)
async def scan_protein_package(
    request: Request,
    user: CurrentUserDep,
    store: StoreDep,
    clock: ClockDep,
    gemini: GeminiDep,
):
    image, content_type = await read_image_within(request, MAX_SCAN_BYTES)
    now = clock()
    if (
        user.last_scan_at is not None
        and (now - user.last_scan_at).total_seconds() < SCAN_COOLDOWN_SECONDS
    ):
        raise errors.too_many()
    # async の入口で Gemini（数秒かかる）を直接呼ぶと、その間サーバー全体が止まる。
    # 別スレッドに逃がして、他の人の /shakes を待たせない
    await run_in_threadpool(store.update_user_fields, user.id, last_scan_at=now)
    package = await run_in_threadpool(gemini.read_protein_package, image, content_type)
    # 結果はここでは保存しない。画面で確認してから PUT /me/favorite-protein で保存する（契約）
    return ProteinScanResponse(
        name=package.name, flavor=package.flavor, protein_grams=package.protein_grams
    )
