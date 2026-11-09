"""振ったときの判断（純粋な計算）と、乾杯相手の探索。"""

from collections.abc import Callable
from datetime import date, datetime, timedelta

from .. import rules
from ..dates import jst_date_of
from ..store.base import DayRecord, EventRecord, ShakeDecision, Store, UserRecord


def shake_event_id(day: date) -> str:
    return f"shake-{day.isoformat()}"


def streak_event_id(day: date) -> str:
    return f"streak-{day.isoformat()}"


def decide_shake(user: UserRecord, now: datetime) -> ShakeDecision:
    if rules.is_duplicate_shake(user.last_shake_at, now):
        return ShakeDecision(user=user, is_duplicate=True)
    today = jst_date_of(now)
    if user.last_shake_date == today:
        return ShakeDecision(user=user.copy_with(last_shake_at=now))

    streak = rules.next_streak(user.streak, user.last_shake_date, today)
    bonus = rules.calculate_bonus_points(streak)
    updated = user.copy_with(
        last_shake_at=now,
        last_shake_date=today,
        streak=streak,
        best_streak=max(user.best_streak, streak),
        total_days=user.total_days + 1,
        points=user.points + bonus,
    )
    events = [EventRecord(id=shake_event_id(today), user_id=user.id, kind="shake", at=now)]
    if rules.is_streak_milestone(streak):
        events.append(
            EventRecord(
                id=streak_event_id(today), user_id=user.id, kind="streak", at=now, streak=streak
            )
        )
    return ShakeDecision(
        user=updated,
        bonus_points=bonus,
        new_day=DayRecord(date=today, first_shake_at=now),
        events=tuple(events),
    )


def find_cheer_partner(
    store: Store,
    me: UserRecord,
    my_shake_at: datetime,
    *,
    wait_seconds: float,
    poll_seconds: float,
    clock: Callable[[], datetime],
    sleep: Callable[[float], None],
) -> UserRecord | None:
    """フォロー中の友達で、自分の前後 5 秒以内に振った人を探す。

    先に振った側の画面にも乾杯を出すため、相手がまだ振っていなければ最大 wait_seconds だけ
    待って読み直す（契約の「前後 5 秒」の「後」の分）。フォローしている人がいなければ待たない。
    """
    following = store.list_following_ids(me.id)
    if not following:
        return None
    deadline = my_shake_at + timedelta(seconds=wait_seconds)
    while True:
        friends = store.find_users(following)
        matches = [
            f for f in friends.values() if rules.is_cheer_match(f.last_shake_at, my_shake_at)
        ]
        if matches:
            return max(matches, key=lambda f: f.last_shake_at)
        if clock() >= deadline:
            return None
        sleep(poll_seconds)
