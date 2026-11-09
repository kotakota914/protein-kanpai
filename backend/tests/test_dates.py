from datetime import UTC, date, datetime

import pytest

from app import dates


def test_jst_date_of_rolls_to_next_day_after_15_utc():
    assert dates.jst_date_of(datetime(2026, 11, 9, 14, 59, tzinfo=UTC)) == date(2026, 11, 9)
    assert dates.jst_date_of(datetime(2026, 11, 9, 15, 0, tzinfo=UTC)) == date(2026, 11, 10)


def test_monday_of_week_returns_same_day_for_monday_and_previous_monday_for_sunday():
    assert dates.monday_of_week(date(2026, 11, 9)) == date(2026, 11, 9)
    assert dates.monday_of_week(date(2026, 11, 15)) == date(2026, 11, 9)


def test_to_iso_utc_uses_z_suffix_without_microseconds():
    moment = datetime(2026, 11, 7, 10, 0, 0, 123456, tzinfo=UTC)
    assert dates.to_iso_utc(moment) == "2026-11-07T10:00:00Z"


def test_parse_month_returns_first_day_and_next_month_first_day():
    assert dates.parse_month("2026-11") == (date(2026, 11, 1), date(2026, 12, 1))
    assert dates.parse_month("2026-12") == (date(2026, 12, 1), date(2027, 1, 1))


def test_parse_month_rejects_other_shapes():
    with pytest.raises(ValueError):
        dates.parse_month("2026-11-05")
