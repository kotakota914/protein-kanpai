"""シェイカーを振った記録と、カレンダー用の月ごとの一覧。"""

from fastapi import APIRouter, Query

from .. import errors
from ..dates import jst_date_of, parse_month
from ..deps import ClockDep, CurrentUserDep, SettingsDep, SleepDep, StoreDep
from ..schemas import CalendarDay, ShakeResponse, UserRef
from ..services.shakes import decide_shake, find_cheer_partner
from ..store.base import CheerPartner, CheerSide

router = APIRouter()


@router.post("/shakes", response_model=ShakeResponse)
def record_shake(
    user: CurrentUserDep,
    store: StoreDep,
    clock: ClockDep,
    sleep: SleepDep,
    settings: SettingsDep,
):
    now = clock()
    decision = store.apply_shake(user.id, lambda current: decide_shake(current, now))
    if decision.is_duplicate:
        raise errors.too_many()
    me = decision.user

    # 自分の lastShakeAt を書いた後で相手を読む。逆順だと、同時に振った 2 人が互いを見つけられない
    partner = find_cheer_partner(
        store,
        me,
        now,
        wait_seconds=settings.cheer_wait_seconds,
        poll_seconds=settings.cheer_poll_seconds,
        clock=clock,
        sleep=sleep,
    )
    if partner is not None and partner.last_shake_date is not None:
        store.record_cheer(
            CheerSide(me.id, jst_date_of(now), CheerPartner(me.id, me.name)),
            CheerSide(partner.id, partner.last_shake_date, CheerPartner(partner.id, partner.name)),
            at=clock(),
        )
        me = store.find_user(me.id) or me

    return ShakeResponse(
        first_today=decision.new_day is not None,
        streak=me.streak,
        bonus_points=decision.bonus_points,
        cheer_with=UserRef(id=partner.id, name=partner.name) if partner else None,
        points=me.points,
        total_days=me.total_days,
        best_streak=me.best_streak,
        total_cheers=me.total_cheers,
    )


@router.get("/shakes", response_model=list[CalendarDay])
def list_calendar(
    user: CurrentUserDep,
    store: StoreDep,
    month: str = Query(pattern=r"^\d{4}-\d{2}$", description="YYYY-MM"),
):
    try:
        start, end = parse_month(month)
    except ValueError as exc:
        raise errors.invalid_argument("month は YYYY-MM の形で指定してください") from exc
    return [
        CalendarDay(date=d.date.isoformat(), cheer_with=[p.name for p in d.cheer_with])
        for d in store.list_days_between(user.id, start, end)
    ]
