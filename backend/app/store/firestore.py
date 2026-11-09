"""Firestore（Native モード）の保存先。

文書の形：
  users/{uid}                         プロフィールとカウンタ
  users/{uid}/days/{YYYY-MM-DD}       振った日の記録（スタンプ）
  users/{uid}/following/{otherUid}    フォロー（中身は時刻だけ）
  users/{uid}/followers/{otherUid}    逆引き
  users/{uid}/events/{eventId}        本人の出来事（タイムラインの元）
  invites/{code}                      招待

問い合わせは単一項目の範囲・並べ替えだけにして、複合インデックスを要らなくしている。
"""

from collections.abc import Callable
from datetime import date, datetime

from google.api_core import exceptions as google_exceptions
from google.cloud import firestore
from google.cloud.firestore_v1 import (
    DocumentReference,
    DocumentSnapshot,
    FieldFilter,
    Transaction,
)

from .base import (
    CheerPartner,
    CheerSide,
    DayRecord,
    EventRecord,
    FavoriteProteinRecord,
    InviteRecord,
    ShakeDecision,
    UserRecord,
    WeeklySummaryCache,
)
from .memory import cheer_event_id


class FirestoreStore:
    def __init__(self, project: str | None = None, database: str = "(default)") -> None:
        self._db = firestore.Client(project=project, database=database)

    # ---- 参照 ----
    def _user_ref(self, user_id: str) -> DocumentReference:
        return self._db.collection("users").document(user_id)

    def _day_ref(self, user_id: str, day: date) -> DocumentReference:
        return self._user_ref(user_id).collection("days").document(day.isoformat())

    def _event_ref(self, user_id: str, event_id: str) -> DocumentReference:
        return self._user_ref(user_id).collection("events").document(event_id)

    # ---- ユーザー ----
    def find_user(self, user_id: str) -> UserRecord | None:
        return _user_from(self._user_ref(user_id).get())

    def find_users(self, user_ids: list[str]) -> dict[str, UserRecord]:
        if not user_ids:
            return {}
        snapshots = self._db.get_all([self._user_ref(uid) for uid in user_ids])
        found = (_user_from(snapshot) for snapshot in snapshots)
        return {user.id: user for user in found if user is not None}

    def create_user_if_absent(self, user: UserRecord) -> UserRecord:
        ref = self._user_ref(user.id)
        existing = _user_from(ref.get())
        if existing is not None:
            return existing
        try:
            ref.create(_user_to(user))
        except google_exceptions.AlreadyExists:
            # 同じ人の初回リクエストが同時に 2 つ来たときだけ通る
            existing = _user_from(ref.get())
            if existing is not None:
                return existing
        return user

    def save_user(self, user: UserRecord) -> None:
        self._user_ref(user.id).set(_user_to(user))

    def update_user_fields(self, user_id: str, **fields: object) -> None:
        self._user_ref(user_id).update(_user_fields_to(fields))

    # ---- 振る・乾杯 ----
    def apply_shake(
        self, user_id: str, decide: Callable[[UserRecord], ShakeDecision]
    ) -> ShakeDecision:
        user_ref = self._user_ref(user_id)

        @firestore.transactional
        def run(transaction: Transaction) -> ShakeDecision:
            current = _user_from(user_ref.get(transaction=transaction))
            if current is None:
                raise KeyError(user_id)
            decision = decide(current)
            if decision.is_duplicate:
                return decision
            transaction.set(user_ref, _user_to(decision.user))
            if decision.new_day is not None:
                day_ref = self._day_ref(user_id, decision.new_day.date)
                transaction.set(day_ref, _day_to(decision.new_day))
            for event in decision.events:
                transaction.set(self._event_ref(user_id, event.id), _event_to(event))
            return decision

        return run(self._db.transaction())

    def record_cheer(self, me: CheerSide, friend: CheerSide, at: datetime) -> bool:
        my_day_ref = self._day_ref(me.user_id, me.day)
        friend_day_ref = self._day_ref(friend.user_id, friend.day)

        @firestore.transactional
        def run(transaction: Transaction) -> bool:
            my_day = my_day_ref.get(transaction=transaction)
            friend_day = friend_day_ref.get(transaction=transaction)
            partners = (my_day.to_dict() or {}).get("cheerWith", []) if my_day.exists else []
            if any(p.get("id") == friend.partner.id for p in partners):
                return False
            _append_partner(transaction, my_day_ref, my_day, me.day, friend.partner, at)
            _append_partner(transaction, friend_day_ref, friend_day, friend.day, me.partner, at)
            for side in (me, friend):
                transaction.update(
                    self._user_ref(side.user_id), {"totalCheers": firestore.Increment(1)}
                )
            for owner, other in ((me, friend), (friend, me)):
                event = EventRecord(
                    id=cheer_event_id(owner.day, other.partner.id),
                    user_id=owner.user_id,
                    kind="cheer",
                    at=at,
                    counterpart=other.partner,
                )
                transaction.set(self._event_ref(owner.user_id, event.id), _event_to(event))
            return True

        return run(self._db.transaction())

    # ---- 振った日の記録 ----
    def find_day(self, user_id: str, day: date) -> DayRecord | None:
        return _day_from(self._day_ref(user_id, day).get())

    def list_days_between(self, user_id: str, start: date, end_exclusive: date) -> list[DayRecord]:
        query = (
            self._user_ref(user_id)
            .collection("days")
            .where(filter=FieldFilter("date", ">=", start.isoformat()))
            .where(filter=FieldFilter("date", "<", end_exclusive.isoformat()))
            .order_by("date")
        )
        days = (_day_from(snapshot) for snapshot in query.stream())
        return [day for day in days if day is not None]

    # ---- フォロー ----
    def follow(self, user_id: str, target_id: str, at: datetime) -> None:
        batch = self._db.batch()
        batch.set(self._user_ref(user_id).collection("following").document(target_id), {"at": at})
        batch.set(self._user_ref(target_id).collection("followers").document(user_id), {"at": at})
        batch.commit()

    def unfollow(self, user_id: str, target_id: str) -> None:
        batch = self._db.batch()
        batch.delete(self._user_ref(user_id).collection("following").document(target_id))
        batch.delete(self._user_ref(target_id).collection("followers").document(user_id))
        batch.commit()

    def is_following(self, user_id: str, target_id: str) -> bool:
        return self._user_ref(user_id).collection("following").document(target_id).get().exists

    def list_following_ids(self, user_id: str) -> list[str]:
        refs = self._user_ref(user_id).collection("following").list_documents()
        return [ref.id for ref in refs]

    def list_follower_ids(self, user_id: str) -> list[str]:
        refs = self._user_ref(user_id).collection("followers").list_documents()
        return [ref.id for ref in refs]

    # ---- 出来事 ----
    def add_event(self, event: EventRecord) -> None:
        self._event_ref(event.user_id, event.id).set(_event_to(event))

    def list_recent_events(self, user_id: str, limit: int) -> list[EventRecord]:
        query = (
            self._user_ref(user_id)
            .collection("events")
            .order_by("at", direction=firestore.Query.DESCENDING)
            .limit(limit)
        )
        return [_event_from(user_id, snapshot) for snapshot in query.stream()]

    # ---- 招待 ----
    def create_invite(self, invite: InviteRecord) -> None:
        self._db.collection("invites").document(invite.code).set(
            {
                "inviterId": invite.inviter_id,
                "createdAt": invite.created_at,
                "expiresAt": invite.expires_at,
            }
        )

    def find_invite(self, code: str) -> InviteRecord | None:
        snapshot = self._db.collection("invites").document(code).get()
        if not snapshot.exists:
            return None
        data = snapshot.to_dict() or {}
        return InviteRecord(
            code=snapshot.id,
            inviter_id=data["inviterId"],
            created_at=data["createdAt"],
            expires_at=data["expiresAt"],
        )


def _append_partner(
    transaction: Transaction,
    day_ref: DocumentReference,
    snapshot: DocumentSnapshot,
    day: date,
    partner: CheerPartner,
    at: datetime,
) -> None:
    partner_dict = {"id": partner.id, "name": partner.name}
    if snapshot.exists:
        transaction.update(day_ref, {"cheerWith": firestore.ArrayUnion([partner_dict])})
    else:
        transaction.set(
            day_ref, {"date": day.isoformat(), "firstShakeAt": at, "cheerWith": [partner_dict]}
        )


# ---- 変換 ----
_USER_KEYS = {
    "name": "name",
    "points": "points",
    "streak": "streak",
    "best_streak": "bestStreak",
    "total_days": "totalDays",
    "total_cheers": "totalCheers",
    "favorite_protein": "favoriteProtein",
    "last_shake_at": "lastShakeAt",
    "last_shake_date": "lastShakeDate",
    "last_scan_at": "lastScanAt",
    "avatar_updated_at": "avatarUpdatedAt",
    "avatar_content_type": "avatarContentType",
    "weekly_summary": "weeklySummary",
}


def _user_fields_to(fields: dict) -> dict:
    """一部の項目だけを Firestore の形にする。変換の規則は _user_to と同じものを使う。"""
    unknown = set(fields) - set(_USER_KEYS)
    if unknown:
        raise ValueError(f"更新できない項目: {sorted(unknown)}")
    placeholder = UserRecord(id="", name="", created_at=datetime.min, **fields)
    whole = _user_to(placeholder)
    return {_USER_KEYS[name]: whole[_USER_KEYS[name]] for name in fields}


def _user_to(user: UserRecord) -> dict:
    favorite = user.favorite_protein
    summary = user.weekly_summary
    return {
        "name": user.name,
        "createdAt": user.created_at,
        "points": user.points,
        "streak": user.streak,
        "bestStreak": user.best_streak,
        "totalDays": user.total_days,
        "totalCheers": user.total_cheers,
        "favoriteProtein": (
            {
                "name": favorite.name,
                "flavor": favorite.flavor,
                "proteinGrams": favorite.protein_grams,
            }
            if favorite
            else None
        ),
        "lastShakeAt": user.last_shake_at,
        "lastShakeDate": user.last_shake_date.isoformat() if user.last_shake_date else None,
        "lastScanAt": user.last_scan_at,
        "avatarUpdatedAt": user.avatar_updated_at,
        "avatarContentType": user.avatar_content_type,
        "weeklySummary": (
            {
                "key": summary.key,
                "text": summary.text,
                "model": summary.model,
                "generatedAt": summary.generated_at,
            }
            if summary
            else None
        ),
    }


def _user_from(snapshot: DocumentSnapshot) -> UserRecord | None:
    if not snapshot.exists:
        return None
    data = snapshot.to_dict() or {}
    favorite = data.get("favoriteProtein")
    summary = data.get("weeklySummary")
    last_shake_date = data.get("lastShakeDate")
    return UserRecord(
        id=snapshot.id,
        name=data.get("name", "名無し"),
        created_at=data["createdAt"],
        points=data.get("points", 0),
        streak=data.get("streak", 0),
        best_streak=data.get("bestStreak", 0),
        total_days=data.get("totalDays", 0),
        total_cheers=data.get("totalCheers", 0),
        favorite_protein=(
            FavoriteProteinRecord(favorite["name"], favorite["flavor"], favorite["proteinGrams"])
            if favorite
            else None
        ),
        last_shake_at=data.get("lastShakeAt"),
        last_shake_date=date.fromisoformat(last_shake_date) if last_shake_date else None,
        last_scan_at=data.get("lastScanAt"),
        avatar_updated_at=data.get("avatarUpdatedAt"),
        avatar_content_type=data.get("avatarContentType"),
        weekly_summary=(
            WeeklySummaryCache(
                summary["key"], summary["text"], summary["model"], summary["generatedAt"]
            )
            if summary
            else None
        ),
    )


def _day_to(day: DayRecord) -> dict:
    return {
        "date": day.date.isoformat(),
        "firstShakeAt": day.first_shake_at,
        "cheerWith": [{"id": p.id, "name": p.name} for p in day.cheer_with],
    }


def _day_from(snapshot: DocumentSnapshot) -> DayRecord | None:
    if not snapshot.exists:
        return None
    data = snapshot.to_dict() or {}
    return DayRecord(
        date=date.fromisoformat(data["date"]),
        first_shake_at=data["firstShakeAt"],
        cheer_with=[CheerPartner(p["id"], p["name"]) for p in data.get("cheerWith", [])],
    )


def _event_to(event: EventRecord) -> dict:
    counterpart = event.counterpart
    return {
        "kind": event.kind,
        "at": event.at,
        "counterpart": {"id": counterpart.id, "name": counterpart.name} if counterpart else None,
        "streak": event.streak,
    }


def _event_from(user_id: str, snapshot: DocumentSnapshot) -> EventRecord:
    data = snapshot.to_dict() or {}
    counterpart = data.get("counterpart")
    return EventRecord(
        id=snapshot.id,
        user_id=user_id,
        kind=data["kind"],
        at=data["at"],
        counterpart=CheerPartner(counterpart["id"], counterpart["name"]) if counterpart else None,
        streak=data.get("streak"),
    )
