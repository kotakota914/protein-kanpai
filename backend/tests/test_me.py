from datetime import date, timedelta

from app import errors
from app.store.base import CheerPartner, DayRecord, ShakeDecision, UserRecord
from tests.conftest import PNG_1PX, START, as_user


def seed_records(store, uid: str, days_ago: list[int], cheers_on: int | None = None, **counters):
    """振った日の記録とカウンタを直接作る（API を通さない）。"""
    store.create_user_if_absent(UserRecord(id=uid, name="x", created_at=START))
    for n in days_ago:
        day = date(2026, 11, 9) - timedelta(days=n)
        cheer = [CheerPartner("u2", "はなこ")] if n == cheers_on else []
        store.apply_shake(
            uid,
            lambda u, day=day, cheer=cheer: ShakeDecision(
                user=u, new_day=DayRecord(date=day, first_shake_at=START, cheer_with=cheer)
            ),
        )
    store.save_user(store.find_user(uid).copy_with(**counters))


def test_me_for_a_new_user_has_zero_records_and_nulls(client):
    body = client.get("/me", headers=as_user("u1")).json()
    assert body == {
        "id": "u1",
        "name": "こうたろう",
        "avatarUrl": None,
        "points": 0,
        "streak": 0,
        "bestStreak": 0,
        "shookToday": False,
        "totalDays": 0,
        "totalCheers": 0,
        "daysThisWeek": 0,
        "favoriteProtein": None,
    }


def test_me_reports_counters_and_counts_this_week_from_day_records(client, store):
    # 昨日（日曜）まで 3 日連続。今日は月曜なので今週はまだ 0 日
    seed_records(
        store,
        "u1",
        [1, 2, 3, 5],
        streak=3,
        best_streak=4,
        total_days=4,
        total_cheers=1,
        last_shake_date=date(2026, 11, 8),
    )
    body = client.get("/me", headers=as_user("u1")).json()
    assert body["streak"] == 3
    assert body["bestStreak"] == 4
    assert body["totalDays"] == 4
    assert body["totalCheers"] == 1
    assert body["daysThisWeek"] == 0
    assert body["shookToday"] is False


def test_me_streak_is_zero_when_the_last_shake_was_two_days_ago(client, store):
    seed_records(store, "u1", [2], streak=5, last_shake_date=date(2026, 11, 7))
    assert client.get("/me", headers=as_user("u1")).json()["streak"] == 0


def test_put_avatar_stores_png_and_returns_versioned_url(client, avatar_storage):
    response = client.put("/me/avatar", headers=as_user("u1"), content=PNG_1PX)
    assert response.status_code == 200
    assert response.json()["avatarUrl"] == f"https://api.test/avatars/u1?v={int(START.timestamp())}"
    assert avatar_storage.load("u1") == PNG_1PX
    assert (
        client.get("/me", headers=as_user("u1")).json()["avatarUrl"] == response.json()["avatarUrl"]
    )


def test_put_avatar_rejects_non_image_bytes_with_400(client):
    response = client.put("/me/avatar", headers=as_user("u1"), content=b"hello world")
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "BAD_IMAGE"


def test_put_avatar_rejects_more_than_2mb_with_413(client):
    big = PNG_1PX + b"\0" * (2 * 1024 * 1024)
    response = client.put("/me/avatar", headers=as_user("u1"), content=big)
    assert response.status_code == 413
    assert response.json()["error"]["code"] == "TOO_LARGE"


def test_delete_avatar_clears_url_and_storage(client, avatar_storage):
    client.put("/me/avatar", headers=as_user("u1"), content=PNG_1PX)
    assert client.delete("/me/avatar", headers=as_user("u1")).status_code == 204
    assert avatar_storage.load("u1") is None
    assert client.get("/me", headers=as_user("u1")).json()["avatarUrl"] is None


def test_avatar_is_visible_to_self_and_follow_related_users_only(client, store):
    client.put("/me/avatar", headers=as_user("u1"), content=PNG_1PX)
    assert client.get("/avatars/u1", headers=as_user("u1")).status_code == 200
    stranger = client.get("/avatars/u1", headers=as_user("u3", "けんた"))
    assert stranger.status_code == 403
    store.follow("u2", "u1", START)  # はなこ → こうたろう をフォロー
    follower = client.get("/avatars/u1", headers=as_user("u2", "はなこ"))
    assert follower.status_code == 200
    assert follower.headers["content-type"] == "image/png"
    assert follower.headers["cache-control"] == "private, max-age=86400"
    assert follower.content == PNG_1PX


def test_avatar_of_user_without_image_is_404(client):
    client.get("/me", headers=as_user("u1"))
    assert client.get("/avatars/u1", headers=as_user("u1")).status_code == 404


def test_put_favorite_protein_then_me_returns_it(client):
    body = {"name": "ホエイプロテイン", "flavor": "ココア味", "proteinGrams": 20}
    assert client.put("/me/favorite-protein", headers=as_user("u1"), json=body).status_code == 204
    assert client.get("/me", headers=as_user("u1")).json()["favoriteProtein"] == body


def test_put_favorite_protein_with_wrong_shape_is_400(client):
    response = client.put(
        "/me/favorite-protein", headers=as_user("u1"), json={"name": "", "flavor": "x"}
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "INVALID_ARGUMENT"


def test_weekly_summary_returns_text_model_and_time(client, gemini, store):
    seed_records(store, "u1", [0], cheers_on=0, streak=1, last_shake_date=date(2026, 11, 9))
    body = client.get("/me/weekly-summary", headers=as_user("u1")).json()
    assert body == {
        "text": "今週は 1日 振れました。あと 4日 で目標の 5日 に届きます。",
        "model": "fake-gemini",
        "generatedAt": "2026-11-09T01:00:00Z",
    }
    assert gemini.calls == ["summary"]


def test_weekly_summary_is_cached_while_the_numbers_do_not_change(client, gemini, clock):
    client.get("/me/weekly-summary", headers=as_user("u1"))
    clock.advance(hours=1)
    body = client.get("/me/weekly-summary", headers=as_user("u1")).json()
    assert body["generatedAt"] == "2026-11-09T01:00:00Z"
    assert gemini.calls == ["summary"]


def test_weekly_summary_is_503_when_gemini_fails(client, gemini):
    gemini.fail_with = errors.ai_unavailable()
    response = client.get("/me/weekly-summary", headers=as_user("u1"))
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "AI_UNAVAILABLE"


def test_avatar_is_404_when_metadata_exists_but_the_image_is_gone(client, avatar_storage):
    client.put("/me/avatar", headers=as_user("u1"), content=PNG_1PX)
    avatar_storage.delete("u1")
    assert client.get("/avatars/u1", headers=as_user("u1")).status_code == 404
