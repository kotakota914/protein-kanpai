"""メモリ上の保存先。自動テストと、GCP なしのローカル実行に使う。プロセスが終わると消える。

同時に来た 2 つのリクエストを直列化しない（Firestore 実装はトランザクションで守る）。
ローカルで 2 人が同時に振ると、ごくまれに乾杯回数が二重に数えられ得る。本番では使わない。
"""

from collections import defaultdict
from collections.abc import Callable
from datetime import date, datetime

from .base import (
    CheerPartner,
    CheerSide,
    DayRecord,
    EventRecord,
    InviteRecord,
    ShakeDecision,
    UserRecord,
)


class MemoryStore:
    def __init__(self) -> None:
        self._users: dict[str, UserRecord] = {}
        self._days: dict[str, dict[date, DayRecord]] = defaultdict(dict)
        self._following: dict[str, dict[str, datetime]] = defaultdict(dict)
        self._followers: dict[str, dict[str, datetime]] = defaultdict(dict)
        self._events: dict[str, dict[str, EventRecord]] = defaultdict(dict)
        self._invites: dict[str, InviteRecord] = {}

    # ---- ユーザー ----
    def find_user(self, user_id: str) -> UserRecord | None:
        return self._users.get(user_id)

    def find_users(self, user_ids: list[str]) -> dict[str, UserRecord]:
        return {uid: self._users[uid] for uid in user_ids if uid in self._users}

    def create_user_if_absent(self, user: UserRecord) -> UserRecord:
        return self._users.setdefault(user.id, user)

    def save_user(self, user: UserRecord) -> None:
        self._users[user.id] = user

    def update_user_fields(self, user_id: str, **fields: object) -> None:
        self._users[user_id] = self._users[user_id].copy_with(**fields)

    # ---- 振る・乾杯 ----
    def apply_shake(
        self, user_id: str, decide: Callable[[UserRecord], ShakeDecision]
    ) -> ShakeDecision:
        decision = decide(self._users[user_id])
        if decision.is_duplicate:
            return decision
        self._users[user_id] = decision.user
        if decision.new_day is not None:
            self._days[user_id][decision.new_day.date] = decision.new_day
        for event in decision.events:
            self.add_event(event)
        return decision

    def record_cheer(self, me: CheerSide, friend: CheerSide, at: datetime) -> bool:
        my_day = self._day_or_new(me.user_id, me.day, at)
        if any(p.id == friend.partner.id for p in my_day.cheer_with):
            return False
        my_day.cheer_with.append(friend.partner)
        self._day_or_new(friend.user_id, friend.day, at).cheer_with.append(me.partner)
        for side in (me, friend):
            user = self._users[side.user_id]
            self._users[side.user_id] = user.copy_with(total_cheers=user.total_cheers + 1)
        self.add_event(_cheer_event(me, friend, at))
        self.add_event(_cheer_event(friend, me, at))
        return True

    def _day_or_new(self, user_id: str, day: date, at: datetime) -> DayRecord:
        return self._days[user_id].setdefault(day, DayRecord(date=day, first_shake_at=at))

    # ---- 振った日の記録 ----
    def find_day(self, user_id: str, day: date) -> DayRecord | None:
        return self._days[user_id].get(day)

    def list_days_between(self, user_id: str, start: date, end_exclusive: date) -> list[DayRecord]:
        return sorted(
            (d for d in self._days[user_id].values() if start <= d.date < end_exclusive),
            key=lambda d: d.date,
        )

    # ---- フォロー ----
    def follow(self, user_id: str, target_id: str, at: datetime) -> None:
        self._following[user_id][target_id] = at
        self._followers[target_id][user_id] = at

    def unfollow(self, user_id: str, target_id: str) -> None:
        self._following[user_id].pop(target_id, None)
        self._followers[target_id].pop(user_id, None)

    def is_following(self, user_id: str, target_id: str) -> bool:
        return target_id in self._following[user_id]

    def list_following_ids(self, user_id: str) -> list[str]:
        return list(self._following[user_id])

    def list_follower_ids(self, user_id: str) -> list[str]:
        return list(self._followers[user_id])

    # ---- 出来事 ----
    def add_event(self, event: EventRecord) -> None:
        self._events[event.user_id][event.id] = event

    def list_recent_events(self, user_id: str, limit: int) -> list[EventRecord]:
        events = sorted(self._events[user_id].values(), key=lambda e: e.at, reverse=True)
        return events[:limit]

    # ---- 招待 ----
    def create_invite(self, invite: InviteRecord) -> None:
        self._invites[invite.code] = invite

    def find_invite(self, code: str) -> InviteRecord | None:
        return self._invites.get(code)


def cheer_event_id(day: date, partner_id: str) -> str:
    return f"cheer-{day.isoformat()}-{partner_id}"


def _cheer_event(owner: CheerSide, other: CheerSide, at: datetime) -> EventRecord:
    return EventRecord(
        id=cheer_event_id(owner.day, other.partner.id),
        user_id=owner.user_id,
        kind="cheer",
        at=at,
        counterpart=CheerPartner(other.partner.id, other.partner.name),
    )
