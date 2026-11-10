"""自分の記録の集計（/me と今週のふりかえりで共用）。"""

from dataclasses import dataclass
from datetime import datetime, timedelta

from .. import rules
from ..dates import jst_date_of, monday_of_week
from ..store.base import Store, UserRecord


@dataclass(frozen=True)
class RecordSummary:
    streak: int
    best_streak: int
    total_days: int
    total_cheers: int
    days_this_week: int
    cheers_this_week: int
    shook_today: bool


def summarize_records(store: Store, user: UserRecord, now: datetime) -> RecordSummary:
    today = jst_date_of(now)
    monday = monday_of_week(today)
    week_days = store.list_days_between(user.id, monday, monday + timedelta(days=7))
    return RecordSummary(
        streak=rules.current_streak(user.streak, user.last_shake_date, today),
        best_streak=user.best_streak,
        total_days=user.total_days,
        total_cheers=user.total_cheers,
        days_this_week=len(week_days),
        cheers_this_week=sum(len(d.cheer_with) for d in week_days),
        shook_today=user.last_shake_date == today,
    )


def compose_avatar_url(public_base_url: str, user: UserRecord) -> str | None:
    if user.avatar_updated_at is None:
        return None
    version = int(user.avatar_updated_at.timestamp())
    return f"{public_base_url}/avatars/{user.id}?v={version}"
