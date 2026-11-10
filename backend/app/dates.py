"""日付の扱い。日付は日本時間で区切り、時刻は UTC の ISO 8601 で返す（契約の「共通」）。"""

from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

JST = ZoneInfo("Asia/Tokyo")


def now_utc() -> datetime:
    return datetime.now(UTC)


def jst_date_of(moment: datetime) -> date:
    if moment.tzinfo is None:
        raise ValueError("タイムゾーン付きの時刻だけを扱う（Firestore も UTC 付きで返す）")
    return moment.astimezone(JST).date()


def monday_of_week(day: date) -> date:
    return day - timedelta(days=day.weekday())


def to_iso_utc(moment: datetime) -> str:
    return moment.astimezone(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_month(text: str) -> tuple[date, date]:
    """ "YYYY-MM" を、その月の初日と翌月の初日に直す。形が違えば ValueError。"""
    first = datetime.strptime(text, "%Y-%m").date()
    next_first = date(first.year + (first.month // 12), first.month % 12 + 1, 1)
    return first, next_first
