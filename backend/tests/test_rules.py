from datetime import UTC, date, datetime, timedelta

from app import rules

TODAY = date(2026, 11, 9)
NOW = datetime(2026, 11, 9, 1, 0, 0, tzinfo=UTC)


def test_next_streak_extends_when_yesterday_was_shaken():
    assert rules.next_streak(3, TODAY - timedelta(days=1), TODAY) == 4


def test_next_streak_restarts_at_1_after_a_gap_or_for_a_new_user():
    assert rules.next_streak(3, TODAY - timedelta(days=2), TODAY) == 1
    assert rules.next_streak(0, None, TODAY) == 1


def test_current_streak_shows_counter_only_while_today_or_yesterday_is_shaken():
    assert rules.current_streak(5, TODAY, TODAY) == 5
    assert rules.current_streak(5, TODAY - timedelta(days=1), TODAY) == 5
    assert rules.current_streak(5, TODAY - timedelta(days=2), TODAY) == 0
    assert rules.current_streak(0, None, TODAY) == 0


def test_calculate_bonus_points_is_10_on_ordinary_days():
    assert rules.calculate_bonus_points(1) == 10
    assert rules.calculate_bonus_points(6) == 10


def test_calculate_bonus_points_adds_50_every_7th_streak_day():
    assert rules.calculate_bonus_points(7) == 60
    assert rules.calculate_bonus_points(14) == 60


def test_is_duplicate_shake_within_3_seconds_only():
    assert rules.is_duplicate_shake(NOW - timedelta(seconds=2.9), NOW)
    assert not rules.is_duplicate_shake(NOW - timedelta(seconds=3), NOW)
    assert not rules.is_duplicate_shake(None, NOW)


def test_is_cheer_match_within_5_seconds_before_or_after_my_shake():
    assert rules.is_cheer_match(NOW - timedelta(seconds=5), NOW)
    assert rules.is_cheer_match(NOW + timedelta(seconds=5), NOW)
    assert not rules.is_cheer_match(NOW - timedelta(seconds=5.1), NOW)
    assert not rules.is_cheer_match(None, NOW)


def test_is_shaking_now_up_to_10_seconds():
    assert rules.is_shaking_now(NOW - timedelta(seconds=10), NOW)
    assert not rules.is_shaking_now(NOW - timedelta(seconds=11), NOW)


def test_is_streak_milestone_at_3_7_14_30_and_multiples_of_7():
    assert [n for n in range(1, 31) if rules.is_streak_milestone(n)] == [3, 7, 14, 21, 28, 30]
