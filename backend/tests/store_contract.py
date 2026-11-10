"""保存先の契約テスト。memory と firestore の両方に同じ検査を流す。

各テストは `store` フィクスチャ（空の保存先）を受け取る。
"""

from datetime import UTC, date, datetime, timedelta

from app.store.base import (
    CheerPartner,
    CheerSide,
    DayRecord,
    EventRecord,
    InviteRecord,
    ShakeDecision,
    UserRecord,
)

T0 = datetime(2026, 11, 9, 1, 0, 0, tzinfo=UTC)
D0 = date(2026, 11, 9)


def make_user(uid: str, name: str = "こうたろう") -> UserRecord:
    return UserRecord(id=uid, name=name, created_at=T0)


def shake_on(store, uid: str, day: date, at: datetime = T0) -> None:
    """その日に 1 回振った状態を作る（判断は固定で与える）。"""
    store.apply_shake(
        uid,
        lambda u: ShakeDecision(
            user=u.copy_with(last_shake_at=at, last_shake_date=day, total_days=u.total_days + 1),
            new_day=DayRecord(date=day, first_shake_at=at),
        ),
    )


class StoreContract:
    def test_find_user_returns_none_for_unknown_id(self, store):
        assert store.find_user("nobody") is None

    def test_create_user_if_absent_keeps_the_existing_record(self, store):
        first = store.create_user_if_absent(make_user("u1", "最初"))
        second = store.create_user_if_absent(make_user("u1", "二回目"))
        assert first.name == "最初"
        assert second.name == "最初"
        assert store.find_user("u1").name == "最初"

    def test_save_user_overwrites_all_fields_including_counters_and_dates(self, store):
        store.create_user_if_absent(make_user("u1"))
        store.save_user(
            make_user("u1").copy_with(
                points=120, streak=3, best_streak=5, last_shake_at=T0, last_shake_date=D0
            )
        )
        loaded = store.find_user("u1")
        assert (loaded.points, loaded.streak, loaded.best_streak) == (120, 3, 5)
        assert loaded.last_shake_at == T0
        assert loaded.last_shake_date == D0

    def test_update_user_fields_changes_only_the_given_fields(self, store):
        store.create_user_if_absent(make_user("u1"))
        store.save_user(make_user("u1").copy_with(points=120, total_cheers=3))
        store.update_user_fields("u1", points=130, last_scan_at=T0)
        loaded = store.find_user("u1")
        assert (loaded.points, loaded.total_cheers, loaded.last_scan_at) == (130, 3, T0)
        store.update_user_fields("u1", favorite_protein=None, last_scan_at=None)
        loaded = store.find_user("u1")
        assert loaded.favorite_protein is None and loaded.last_scan_at is None

    def test_find_users_returns_only_known_ids(self, store):
        store.create_user_if_absent(make_user("u1"))
        store.create_user_if_absent(make_user("u2"))
        assert set(store.find_users(["u1", "u2", "u3"])) == {"u1", "u2"}

    def test_apply_shake_passes_the_latest_user_and_writes_user_day_and_events(self, store):
        store.create_user_if_absent(make_user("u1"))
        store.save_user(make_user("u1").copy_with(points=5))
        seen = {}

        def decide(user):
            seen["points"] = user.points
            return ShakeDecision(
                user=user.copy_with(points=15, last_shake_at=T0, last_shake_date=D0),
                bonus_points=10,
                new_day=DayRecord(date=D0, first_shake_at=T0),
                events=(EventRecord(id="shake-2026-11-09", user_id="u1", kind="shake", at=T0),),
            )

        decision = store.apply_shake("u1", decide)
        assert seen["points"] == 5
        assert decision.bonus_points == 10
        assert store.find_user("u1").points == 15
        assert store.find_day("u1", D0).first_shake_at == T0
        assert [e.id for e in store.list_recent_events("u1", 10)] == ["shake-2026-11-09"]

    def test_apply_shake_writes_nothing_when_decision_is_duplicate(self, store):
        store.create_user_if_absent(make_user("u1"))
        store.apply_shake(
            "u1", lambda u: ShakeDecision(user=u.copy_with(points=99), is_duplicate=True)
        )
        assert store.find_user("u1").points == 0

    def test_list_days_between_is_inclusive_start_exclusive_end_and_sorted(self, store):
        store.create_user_if_absent(make_user("u1"))
        for d in (date(2026, 10, 31), date(2026, 11, 30), date(2026, 11, 1), date(2026, 12, 1)):
            shake_on(store, "u1", d)
        days = store.list_days_between("u1", date(2026, 11, 1), date(2026, 12, 1))
        assert [d.date for d in days] == [date(2026, 11, 1), date(2026, 11, 30)]

    def test_record_cheer_writes_both_days_counters_and_events(self, store):
        store.create_user_if_absent(make_user("u1", "こうたろう"))
        store.create_user_if_absent(make_user("u2", "はなこ"))
        shake_on(store, "u1", D0)
        shake_on(store, "u2", D0)
        me = CheerSide("u1", D0, CheerPartner("u1", "こうたろう"))
        friend = CheerSide("u2", D0, CheerPartner("u2", "はなこ"))
        assert store.record_cheer(me, friend, T0) is True
        assert store.find_day("u1", D0).cheer_with == [CheerPartner("u2", "はなこ")]
        assert store.find_day("u2", D0).cheer_with == [CheerPartner("u1", "こうたろう")]
        assert store.find_user("u1").total_cheers == 1
        assert store.find_user("u2").total_cheers == 1
        mine = [e for e in store.list_recent_events("u1", 10) if e.kind == "cheer"]
        assert [(e.id, e.counterpart.name) for e in mine] == [("cheer-2026-11-09-u2", "はなこ")]
        theirs = [e for e in store.list_recent_events("u2", 10) if e.kind == "cheer"]
        assert [(e.id, e.counterpart.name) for e in theirs] == [
            ("cheer-2026-11-09-u1", "こうたろう")
        ]

    def test_record_cheer_is_idempotent_for_the_same_pair_and_day(self, store):
        store.create_user_if_absent(make_user("u1"))
        store.create_user_if_absent(make_user("u2", "はなこ"))
        shake_on(store, "u1", D0)
        shake_on(store, "u2", D0)
        me = CheerSide("u1", D0, CheerPartner("u1", "こうたろう"))
        friend = CheerSide("u2", D0, CheerPartner("u2", "はなこ"))
        store.record_cheer(me, friend, T0)
        assert store.record_cheer(me, friend, T0 + timedelta(seconds=1)) is False
        assert store.record_cheer(friend, me, T0 + timedelta(seconds=1)) is False
        assert store.find_user("u1").total_cheers == 1
        assert len(store.find_day("u1", D0).cheer_with) == 1
        assert len(store.list_recent_events("u2", 10)) == 1

    def test_record_cheer_creates_the_friend_day_when_it_is_missing(self, store):
        store.create_user_if_absent(make_user("u1"))
        store.create_user_if_absent(make_user("u2", "はなこ"))
        shake_on(store, "u1", D0)
        me = CheerSide("u1", D0, CheerPartner("u1", "こうたろう"))
        friend = CheerSide("u2", D0 - timedelta(days=1), CheerPartner("u2", "はなこ"))
        store.record_cheer(me, friend, T0)
        assert store.find_day("u2", D0 - timedelta(days=1)).cheer_with == [
            CheerPartner("u1", "こうたろう")
        ]

    def test_follow_is_visible_from_both_sides_and_unfollow_removes_both(self, store):
        store.follow("u1", "u2", T0)
        assert store.is_following("u1", "u2")
        assert not store.is_following("u2", "u1")
        assert store.list_following_ids("u1") == ["u2"]
        assert store.list_follower_ids("u2") == ["u1"]
        store.unfollow("u1", "u2")
        assert not store.is_following("u1", "u2")
        assert store.list_following_ids("u1") == []
        assert store.list_follower_ids("u2") == []

    def test_add_event_with_the_same_id_replaces_instead_of_duplicating(self, store):
        store.add_event(EventRecord(id="shake-2026-11-09", user_id="u1", kind="shake", at=T0))
        store.add_event(EventRecord(id="shake-2026-11-09", user_id="u1", kind="shake", at=T0))
        assert len(store.list_recent_events("u1", 10)) == 1

    def test_list_recent_events_returns_newest_first_up_to_limit(self, store):
        store.add_event(EventRecord(id="e1", user_id="u1", kind="shake", at=T0))
        store.add_event(
            EventRecord(
                id="e2",
                user_id="u1",
                kind="cheer",
                at=T0 + timedelta(seconds=5),
                counterpart=CheerPartner("u2", "はなこ"),
            )
        )
        store.add_event(
            EventRecord(
                id="e3", user_id="u1", kind="streak", at=T0 + timedelta(seconds=9), streak=7
            )
        )
        assert [e.id for e in store.list_recent_events("u1", 10)] == ["e3", "e2", "e1"]
        assert [e.id for e in store.list_recent_events("u1", 1)] == ["e3"]
        assert store.list_recent_events("u1", 10)[0].streak == 7

    def test_invite_round_trip(self, store):
        invite = InviteRecord(
            code="abc12345", inviter_id="u1", created_at=T0, expires_at=T0 + timedelta(days=7)
        )
        store.create_invite(invite)
        assert store.find_invite("abc12345") == invite
        assert store.find_invite("zzz") is None
