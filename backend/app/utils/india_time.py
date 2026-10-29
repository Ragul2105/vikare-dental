from __future__ import annotations

from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

INDIA_TZ = ZoneInfo("Asia/Kolkata")


def ensure_india_time(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=INDIA_TZ)
    return value.astimezone(INDIA_TZ)


def india_day_bounds(target_date: date) -> tuple[datetime, datetime]:
    start = datetime.combine(target_date, time.min, tzinfo=INDIA_TZ)
    return start, start + timedelta(days=1)


def india_date_range_bounds(start_date: date, days: int) -> tuple[datetime, datetime]:
    start, _ = india_day_bounds(start_date)
    return start, start + timedelta(days=days)


def india_today() -> date:
    return datetime.now(INDIA_TZ).date()


def india_now() -> datetime:
    return datetime.now(INDIA_TZ)
