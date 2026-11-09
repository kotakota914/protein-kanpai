from datetime import timedelta

from tests.conftest import START, as_user


def shake(client, uid: str, name: str):
    return client.post("/shakes", headers=as_user(uid, name))


def connect(store, a: str, b: str) -> None:
    """招待でつながった状態（相互フォロー）を作る。"""
    store.follow(a, b, START)
    store.follow(b, a, START)


def test_friends_lists_only_follow_related_users_with_direction_flags(client, store):
    for uid, name in (("u1", "こうたろう"), ("u2", "はなこ"), ("u3", "たろう"), ("u4", "けんた")):
        client.get("/me", headers=as_user(uid, name))
    store.follow("u1", "u2", START)  # 自分 → はなこ
    store.follow("u3", "u1", START)  # たろう → 自分
    body = client.get("/friends", headers=as_user("u1")).json()
    assert [(f["name"], f["following"]) for f in body] == [("たろう", False), ("はなこ", True)]


def test_friends_reports_shaking_now_within_10_seconds_and_shook_today(client, store, clock):
    client.get("/me", headers=as_user("u1"))
    shake(client, "u2", "はなこ")
    connect(store, "u1", "u2")
    clock.advance(seconds=9)
    friend = client.get("/friends", headers=as_user("u1")).json()[0]
    assert (friend["shakingNow"], friend["shookToday"]) == (True, True)
    clock.advance(seconds=2)
    friend = client.get("/friends", headers=as_user("u1")).json()[0]
    assert (friend["shakingNow"], friend["shookToday"]) == (False, True)
    clock.advance(days=1)
    friend = client.get("/friends", headers=as_user("u1")).json()[0]
    assert friend["shookToday"] is False


def test_friends_includes_avatar_url_when_the_friend_has_one(client, store):
    from tests.conftest import PNG_1PX

    client.put("/me/avatar", headers=as_user("u2", "はなこ"), content=PNG_1PX)
    client.get("/me", headers=as_user("u1"))
    connect(store, "u1", "u2")
    friend = client.get("/friends", headers=as_user("u1")).json()[0]
    assert friend["avatarUrl"].startswith("https://api.test/avatars/u2?v=")


def test_follow_requires_that_the_other_person_already_follows_you(client, store):
    client.get("/me", headers=as_user("u1"))
    client.get("/me", headers=as_user("u2", "はなこ"))
    denied = client.put("/follows/u2", headers=as_user("u1"))
    assert denied.status_code == 403
    assert denied.json()["error"]["code"] == "FORBIDDEN"
    store.follow("u2", "u1", START)
    assert client.put("/follows/u2", headers=as_user("u1")).status_code == 204
    assert store.is_following("u1", "u2")


def test_follow_yourself_is_400_and_unknown_user_is_404(client):
    client.get("/me", headers=as_user("u1"))
    assert client.put("/follows/u1", headers=as_user("u1")).status_code == 400
    assert client.put("/follows/ghost", headers=as_user("u1")).status_code == 404


def test_unfollow_removes_only_your_side_and_is_idempotent(client, store):
    client.get("/me", headers=as_user("u1"))
    client.get("/me", headers=as_user("u2", "はなこ"))
    connect(store, "u1", "u2")
    assert client.delete("/follows/u2", headers=as_user("u1")).status_code == 204
    assert client.delete("/follows/u2", headers=as_user("u1")).status_code == 204
    assert not store.is_following("u1", "u2")
    assert store.is_following("u2", "u1")


def test_feed_shows_followed_friends_events_and_own_cheers_newest_first(client, app, store, clock):
    # 待ち時間は偽の時計を進めてしまうので、このテストでは「先に振った人を後から検知する」だけで組む
    app.state.settings.cheer_wait_seconds = 0
    client.get("/me", headers=as_user("u1"))
    client.get("/me", headers=as_user("u2", "はなこ"))
    client.get("/me", headers=as_user("u3", "たろう"))
    connect(store, "u1", "u2")
    connect(store, "u2", "u3")
    for _ in range(2):  # はなこ：2 日目で連続 2（節目ではない）、3 日目で節目 3
        shake(client, "u2", "はなこ")
        clock.advance(days=1)
    shake(client, "u2", "はなこ")  # 11/11：はなこ 3 日連続
    clock.advance(seconds=2)
    shake(client, "u3", "たろう")  # たろうが 2 秒後に振る → はなこと乾杯（u1 はたろうを未フォロー）
    clock.advance(seconds=2)
    shake(client, "u1", "こうたろう")  # 自分も 4 秒後に振る → はなこと乾杯
    body = client.get("/feed?limit=10", headers=as_user("u1")).json()
    # 同じ時刻の出来事（振った・節目）の前後は決めていないので、並びは時刻だけ確かめる
    assert [item["at"] for item in body] == sorted((item["at"] for item in body), reverse=True)
    assert sorted((item["kind"], item["friend"]["name"], item["text"]) for item in body) == sorted(
        [
            ("cheer", "はなこ", "はなこさんと乾杯しました"),
            ("cheer", "はなこ", "はなこさんがたろうさんと乾杯しました"),
            ("streak", "はなこ", "はなこさんが 3日連続を達成！"),
            ("shake", "はなこ", "はなこさんが今日のプロテインを振りました"),
            ("shake", "はなこ", "はなこさんがプロテインを振りました"),
            ("shake", "はなこ", "はなこさんがプロテインを振りました"),
        ]
    )
    assert body[0]["at"] == "2026-11-11T01:00:04Z"


def test_feed_excludes_people_you_do_not_follow_and_respects_limit(client, store, clock):
    client.get("/me", headers=as_user("u1"))
    shake(client, "u3", "たろう")
    body = client.get("/feed", headers=as_user("u1")).json()
    assert body == []
    connect(store, "u1", "u3")
    for _ in range(3):
        clock.advance(days=1)
        shake(client, "u3", "たろう")
    assert len(client.get("/feed?limit=2", headers=as_user("u1")).json()) == 2
    assert len(client.get("/feed?limit=0", headers=as_user("u1")).json()) == 1


def test_invite_link_accept_makes_both_users_follow_each_other(client, store, clock):
    url = client.post("/invites", headers=as_user("u1")).json()["url"]
    assert url.startswith("https://app.test/invite/")
    code = url.rsplit("/", 1)[1]
    accepted = client.post(f"/invites/{code}/accept", headers=as_user("u2", "はなこ"))
    assert accepted.status_code == 200
    assert accepted.json() == {"friend": {"id": "u1", "name": "こうたろう"}}
    assert store.is_following("u1", "u2") and store.is_following("u2", "u1")
    names = [f["name"] for f in client.get("/friends", headers=as_user("u1")).json()]
    assert names == ["はなこ"]


def test_invite_cannot_be_accepted_by_the_inviter_and_expires_after_7_days(client, clock):
    code = client.post("/invites", headers=as_user("u1")).json()["url"].rsplit("/", 1)[1]
    assert client.post(f"/invites/{code}/accept", headers=as_user("u1")).status_code == 400
    clock.advance(days=7)
    assert (
        client.post(f"/invites/{code}/accept", headers=as_user("u2", "はなこ")).status_code == 404
    )
    assert client.post("/invites/nope/accept", headers=as_user("u2", "はなこ")).status_code == 404


def test_invite_expiry_is_recorded_as_7_days(client, store):
    code = client.post("/invites", headers=as_user("u1")).json()["url"].rsplit("/", 1)[1]
    invite = store.find_invite(code)
    assert invite.expires_at - invite.created_at == timedelta(days=7)


def test_invite_url_falls_back_to_the_server_origin_without_api_prefix(
    settings, clock, sleep, store, gemini, avatar_storage
):
    from fastapi.testclient import TestClient

    from app.main import create_app

    settings.invite_base_url = None
    settings.public_base_url = None
    settings.api_prefix = "/api"
    client = TestClient(
        create_app(
            settings,
            store=store,
            gemini=gemini,
            avatar_storage=avatar_storage,
            clock=clock.now,
            sleep=sleep,
        )
    )
    url = client.post("/api/invites", headers=as_user("u1")).json()["url"]
    assert url.startswith("http://testserver/invite/")
