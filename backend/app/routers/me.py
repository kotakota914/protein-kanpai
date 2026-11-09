"""自分のプロフィール・アイコン・好きなプロテイン・今週のふりかえり。"""

from fastapi import APIRouter, Request, Response
from starlette.concurrency import run_in_threadpool

from .. import errors
from ..dates import jst_date_of, monday_of_week, to_iso_utc
from ..deps import (
    AvatarStorageDep,
    ClockDep,
    CurrentUserDep,
    GeminiDep,
    PublicBaseUrlDep,
    StoreDep,
)
from ..schemas import AvatarResponse, FavoriteProtein, MeResponse, WeeklySummaryResponse
from ..services.gemini import WeeklyStats
from ..services.images import read_image_within
from ..services.profile import compose_avatar_url, summarize_records
from ..store.base import FavoriteProteinRecord, WeeklySummaryCache

router = APIRouter()

MAX_AVATAR_BYTES = 2 * 1024 * 1024
WEEKLY_TARGET_DAYS = 5


@router.get("/me", response_model=MeResponse)
def read_me(user: CurrentUserDep, store: StoreDep, clock: ClockDep, base_url: PublicBaseUrlDep):
    summary = summarize_records(store, user, clock())
    favorite = user.favorite_protein
    return MeResponse(
        id=user.id,
        name=user.name,
        avatar_url=compose_avatar_url(base_url, user),
        points=user.points,
        streak=summary.streak,
        best_streak=summary.best_streak,
        shook_today=summary.shook_today,
        total_days=summary.total_days,
        total_cheers=summary.total_cheers,
        days_this_week=summary.days_this_week,
        favorite_protein=(
            FavoriteProtein(
                name=favorite.name, flavor=favorite.flavor, protein_grams=favorite.protein_grams
            )
            if favorite
            else None
        ),
    )


@router.put("/me/avatar", response_model=AvatarResponse)
async def replace_avatar(
    request: Request,
    user: CurrentUserDep,
    store: StoreDep,
    clock: ClockDep,
    storage: AvatarStorageDep,
    base_url: PublicBaseUrlDep,
):
    image, content_type = await read_image_within(request, MAX_AVATAR_BYTES)
    # async の入口で同期の I/O を直接呼ぶと、その間サーバー全体が止まるので別スレッドに逃がす
    await run_in_threadpool(storage.save, user.id, image, content_type)
    updated = user.copy_with(avatar_updated_at=clock(), avatar_content_type=content_type)
    await run_in_threadpool(
        store.update_user_fields,
        user.id,
        avatar_updated_at=updated.avatar_updated_at,
        avatar_content_type=content_type,
    )
    return AvatarResponse(avatar_url=compose_avatar_url(base_url, updated))


@router.delete("/me/avatar", status_code=204, response_class=Response)
def remove_avatar(user: CurrentUserDep, store: StoreDep, storage: AvatarStorageDep):
    storage.delete(user.id)
    store.update_user_fields(user.id, avatar_updated_at=None, avatar_content_type=None)
    return Response(status_code=204)


@router.get("/avatars/{user_id}")
def read_avatar(user_id: str, user: CurrentUserDep, store: StoreDep, storage: AvatarStorageDep):
    is_related = (
        user_id == user.id
        or store.is_following(user.id, user_id)
        or store.is_following(user_id, user.id)
    )
    if not is_related:
        raise errors.forbidden()
    owner = store.find_user(user_id)
    if owner is None or owner.avatar_updated_at is None:
        raise errors.not_found("アイコンがありません")
    image = storage.load(user_id)
    if image is None:
        raise errors.not_found("アイコンがありません")
    return Response(
        content=image,
        media_type=owner.avatar_content_type or "application/octet-stream",
        headers={"Cache-Control": "private, max-age=86400", "X-Content-Type-Options": "nosniff"},
    )


@router.put("/me/favorite-protein", status_code=204, response_class=Response)
def replace_favorite_protein(body: FavoriteProtein, user: CurrentUserDep, store: StoreDep):
    store.update_user_fields(
        user.id,
        favorite_protein=FavoriteProteinRecord(
            name=body.name, flavor=body.flavor, protein_grams=body.protein_grams
        ),
    )
    return Response(status_code=204)


@router.get("/me/weekly-summary", response_model=WeeklySummaryResponse)
def read_weekly_summary(user: CurrentUserDep, store: StoreDep, clock: ClockDep, gemini: GeminiDep):
    now = clock()
    summary = summarize_records(store, user, now)
    stats = WeeklyStats(
        days_this_week=summary.days_this_week,
        streak=summary.streak,
        cheers_this_week=summary.cheers_this_week,
        target_days=WEEKLY_TARGET_DAYS,
    )
    # 同じ週で数字が変わっていなければ Gemini を呼び直さない（画面を開くたびの課金と遅延を避ける）
    week = monday_of_week(jst_date_of(now)).isoformat()
    cache_key = f"{week}:{stats.days_this_week}:{stats.streak}:{stats.cheers_this_week}"
    cached = user.weekly_summary
    if cached is None or cached.key != cache_key:
        text, model = gemini.write_weekly_summary(stats)
        cached = WeeklySummaryCache(key=cache_key, text=text, model=model, generated_at=now)
        store.update_user_fields(user.id, weekly_summary=cached)
    return WeeklySummaryResponse(
        text=cached.text, model=cached.model, generated_at=to_iso_utc(cached.generated_at)
    )
