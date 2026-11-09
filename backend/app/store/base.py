"""保存先の約束（Protocol）。memory.py と firestore.py が同じ形で実装する。

ルーターや計算はこの約束だけに依存し、Firestore 固有の型を知らない。
振る・乾杯の書き込みは、同じ人の連打や 2 人の同時検知で二重に数えないよう、
保存先側で「読んで決めて書く」をひとまとまり（トランザクション）にする。
"""

from collections.abc import Callable
from dataclasses import dataclass, field, replace
from datetime import date, datetime
from typing import Literal, Protocol

EventKind = Literal["shake", "cheer", "streak"]


@dataclass(frozen=True)
class CheerPartner:
    id: str
    name: str


@dataclass(frozen=True)
class FavoriteProteinRecord:
    name: str
    flavor: str
    protein_grams: int


@dataclass(frozen=True)
class WeeklySummaryCache:
    key: str
    text: str
    model: str
    generated_at: datetime


@dataclass
class UserRecord:
    id: str
    name: str
    created_at: datetime
    points: int = 0
    # 連続日数などはカウンタで持つ。毎回 days を全部読んで数え直さないため
    streak: int = 0
    best_streak: int = 0
    total_days: int = 0
    total_cheers: int = 0
    favorite_protein: FavoriteProteinRecord | None = None
    last_shake_at: datetime | None = None
    last_shake_date: date | None = None
    last_scan_at: datetime | None = None
    avatar_updated_at: datetime | None = None
    avatar_content_type: str | None = None
    weekly_summary: WeeklySummaryCache | None = None

    def copy_with(self, **changes: object) -> "UserRecord":
        return replace(self, **changes)


@dataclass
class DayRecord:
    date: date
    first_shake_at: datetime
    cheer_with: list[CheerPartner] = field(default_factory=list)


@dataclass(frozen=True)
class EventRecord:
    """本人の出来事。id は決定的（shake-日付 など）にして、二重登録しても 1 件になるようにする。"""

    id: str
    user_id: str
    kind: EventKind
    at: datetime
    counterpart: CheerPartner | None = None
    streak: int | None = None


@dataclass(frozen=True)
class InviteRecord:
    code: str
    inviter_id: str
    created_at: datetime
    expires_at: datetime


@dataclass(frozen=True)
class ShakeDecision:
    """振ったときに書き込む内容。services/shakes.decide_shake が作る。"""

    user: UserRecord
    bonus_points: int = 0
    new_day: DayRecord | None = None
    events: tuple[EventRecord, ...] = ()
    is_duplicate: bool = False


@dataclass(frozen=True)
class CheerSide:
    """乾杯の片側。partner は相手の日記録に書く自分の名前。day はどの日の記録に書くか。"""

    user_id: str
    day: date
    partner: CheerPartner


class Store(Protocol):
    # ---- ユーザー ----
    def find_user(self, user_id: str) -> UserRecord | None: ...
    def find_users(self, user_ids: list[str]) -> dict[str, UserRecord]: ...
    def create_user_if_absent(self, user: UserRecord) -> UserRecord: ...
    def save_user(self, user: UserRecord) -> None:
        """文書を丸ごと置き換える。テストの準備用。リクエスト処理では使わない。"""
        ...

    def update_user_fields(self, user_id: str, **fields: object) -> None:
        """指定した項目だけを書き換える。

        丸ごと書き戻すと、読んでから書くまでの間に他の人の乾杯が加算した totalCheers などを
        古い値で上書きしてしまうため、リクエスト処理ではこちらを使う。
        """
        ...

    # ---- 振る・乾杯（ひとまとまりで書く） ----
    def apply_shake(
        self, user_id: str, decide: Callable[[UserRecord], ShakeDecision]
    ) -> ShakeDecision:
        """最新のユーザーを読んで decide に渡し、返ってきた内容を書く。重複なら何も書かない。"""
        ...

    def record_cheer(self, me: CheerSide, friend: CheerSide, at: datetime) -> bool:
        """両者の日記録・乾杯回数・出来事を書く。すでに同じ日に同じ相手と乾杯済みなら False。"""
        ...

    # ---- 振った日の記録 ----
    def find_day(self, user_id: str, day: date) -> DayRecord | None: ...
    def list_days_between(
        self, user_id: str, start: date, end_exclusive: date
    ) -> list[DayRecord]: ...

    # ---- フォロー ----
    def follow(self, user_id: str, target_id: str, at: datetime) -> None: ...
    def unfollow(self, user_id: str, target_id: str) -> None: ...
    def is_following(self, user_id: str, target_id: str) -> bool: ...
    def list_following_ids(self, user_id: str) -> list[str]: ...
    def list_follower_ids(self, user_id: str) -> list[str]: ...

    # ---- 出来事（タイムラインの元） ----
    def add_event(self, event: EventRecord) -> None: ...
    def list_recent_events(self, user_id: str, limit: int) -> list[EventRecord]:
        """新しい順。種類で絞る引数は持たない（Firestore で複合インデックスが要るため）。"""
        ...

    # ---- 招待 ----
    def create_invite(self, invite: InviteRecord) -> None: ...
    def find_invite(self, code: str) -> InviteRecord | None: ...
