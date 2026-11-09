from datetime import date

from app.store.base import UserRecord
from tests.conftest import START, as_user


def shake(client, uid: str, name: str = "こうたろう"):
    return client.post("/shakes", headers=as_user(uid, name))


def test_first_shake_of_the_day_stamps_streak_1_and_10_points(client):
    body = shake(client, "u1").json()
    assert body == {
        "firstToday": True,
        "streak": 1,
        "bonusPoints": 10,
        "cheerWith": None,
        "points": 10,
        "totalDays": 1,
        "bestStreak": 1,
        "totalCheers": 0,
    }


def test_second_shake_within_3_seconds_is_429(client, clock):
    shake(client, "u1")
    clock.advance(seconds=2)
    response = shake(client, "u1")
    assert response.status_code == 429
    assert response.json()["error"]["code"] == "TOO_MANY"


def test_second_shake_of_the_day_gives_no_bonus_and_no_new_stamp(client, clock):
    shake(client, "u1")
    clock.advance(seconds=30)
    body = shake(client, "u1").json()
    assert (body["firstToday"], body["bonusPoints"], body["points"], body["totalDays"]) == (
        False,
        0,
        10,
        1,
    )


def test_streak_grows_on_consecutive_days_and_resets_after_a_gap(client, clock):
    assert shake(client, "u1").json()["streak"] == 1
    clock.advance(days=1)
    assert shake(client, "u1").json()["streak"] == 2
    clock.advance(days=2)
    body = shake(client, "u1").json()
    assert (body["streak"], body["bestStreak"], body["totalDays"]) == (1, 2, 3)


def test_seventh_consecutive_day_pays_60_points(client, clock):
    for _ in range(6):
        shake(client, "u1")
        clock.advance(days=1)
    body = shake(client, "u1").json()
    assert (body["streak"], body["bonusPoints"], body["points"]) == (7, 60, 120)


def test_streak_milestones_leave_a_streak_event(client, clock, store):
    for _ in range(3):
        shake(client, "u1")
        clock.advance(days=1)
    kinds = [(e.kind, e.streak) for e in store.list_recent_events("u1", 10) if e.kind == "streak"]
    assert kinds == [("streak", 3)]


def test_shake_within_5_seconds_after_a_followed_friend_is_a_cheer(client, clock, store):
    shake(client, "u2", "はなこ")
    store.follow("u1", "u2", START)
    clock.advance(seconds=3)
    body = shake(client, "u1").json()
    assert body["cheerWith"] == {"id": "u2", "name": "はなこ"}
    assert body["totalCheers"] == 1
    assert [p.name for p in store.find_day("u1", date(2026, 11, 9)).cheer_with] == ["はなこ"]
    assert [p.name for p in store.find_day("u2", date(2026, 11, 9)).cheer_with] == ["こうたろう"]
    assert store.find_user("u2").total_cheers == 1
    assert [e.counterpart.name for e in store.list_recent_events("u2", 5) if e.kind == "cheer"] == [
        "こうたろう"
    ]


def test_shake_more_than_5_seconds_after_the_friend_is_not_a_cheer(client, clock, store, sleep):
    shake(client, "u2", "はなこ")
    store.follow("u1", "u2", START)
    clock.advance(seconds=6)
    assert shake(client, "u1").json()["cheerWith"] is None
    assert sleep.calls, "友達がいるので最大 5 秒は待つ"


def test_shake_near_someone_you_do_not_follow_is_not_a_cheer(client, clock, store, sleep):
    shake(client, "u2", "はなこ")
    clock.advance(seconds=2)
    assert shake(client, "u1").json()["cheerWith"] is None
    assert sleep.calls == [], "フォローしている人がいなければ待たない"


def test_first_shaker_waits_and_still_gets_the_cheer_when_the_friend_shakes_soon_after(
    client, clock, store, sleep
):
    store.follow("u1", "u2", START)
    store.create_user_if_absent(UserRecord(id="u2", name="はなこ", created_at=START))
    friend_shaken = {"done": False}

    def friend_shakes_after_one_second():
        if not friend_shaken["done"] and clock.now() >= START.replace(second=1):
            friend_shaken["done"] = True
            shake(client, "u2", "はなこ")

    sleep.on_sleep = friend_shakes_after_one_second
    body = shake(client, "u1").json()
    assert body["cheerWith"] == {"id": "u2", "name": "はなこ"}
    assert body["totalCheers"] == 1
    assert store.find_user("u2").total_cheers == 1
    assert len(store.find_day("u2", date(2026, 11, 9)).cheer_with) == 1


def test_calendar_lists_days_of_the_month_with_cheer_partner_names(client, clock, store):
    shake(client, "u2", "はなこ")
    store.follow("u1", "u2", START)
    clock.advance(seconds=1)
    shake(client, "u1")
    clock.advance(days=1)
    shake(client, "u1")
    body = client.get("/shakes?month=2026-11", headers=as_user("u1")).json()
    assert body == [
        {"date": "2026-11-09", "cheerWith": ["はなこ"]},
        {"date": "2026-11-10", "cheerWith": []},
    ]
    assert client.get("/shakes?month=2026-10", headers=as_user("u1")).json() == []


def test_calendar_with_a_malformed_month_is_400(client):
    response = client.get("/shakes?month=2026-11-09", headers=as_user("u1"))
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "INVALID_ARGUMENT"
