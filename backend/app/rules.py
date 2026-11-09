"""記録・ボーナス・乾杯の計算。保存先に依存しない純粋な関数だけを置く。

数字の出どころは docs/api-contract.md の「振る」の節。
"""

from datetime import date, datetime, timedelta

SHAKE_DEDUPE_SECONDS = 3
CHEER_WINDOW_SECONDS = 5
SHAKING_NOW_SECONDS = 10
DAILY_BONUS_POINTS = 10
WEEKLY_STREAK_BONUS_POINTS = 50
STREAK_MILESTONES = frozenset({3, 7, 14, 30})


def next_streak(previous_streak: int, last_shake_date: date | None, today: date) -> int:
    """今日はじめて振ったときの連続日数。昨日も振っていれば伸び、空いていれば 1 に戻る。"""
    if last_shake_date == today - timedelta(days=1):
        return previous_streak + 1
    return 1


def current_streak(streak: int, last_shake_date: date | None, today: date) -> int:
    """表示用の連続日数。今日か昨日に振っていなければ途切れているので 0。"""
    if last_shake_date in (today, today - timedelta(days=1)):
        return streak
    return 0


def calculate_bonus_points(streak_after_shake: int) -> int:
    bonus = DAILY_BONUS_POINTS
    if streak_after_shake > 0 and streak_after_shake % 7 == 0:
        bonus += WEEKLY_STREAK_BONUS_POINTS
    return bonus


def is_duplicate_shake(last_shake_at: datetime | None, now: datetime) -> bool:
    return _seconds_since(last_shake_at, now) < SHAKE_DEDUPE_SECONDS


def is_cheer_match(friend_last_shake_at: datetime | None, my_shake_at: datetime) -> bool:
    """友達の振った時刻が、自分の振った時刻の前後 5 秒以内か。"""
    if friend_last_shake_at is None:
        return False
    return abs((friend_last_shake_at - my_shake_at).total_seconds()) <= CHEER_WINDOW_SECONDS


def is_shaking_now(last_shake_at: datetime | None, now: datetime) -> bool:
    return _seconds_since(last_shake_at, now) <= SHAKING_NOW_SECONDS


def is_streak_milestone(streak: int) -> bool:
    return streak in STREAK_MILESTONES or (streak > 0 and streak % 7 == 0)


def _seconds_since(moment: datetime | None, now: datetime) -> float:
    if moment is None:
        return float("inf")
    return (now - moment).total_seconds()
