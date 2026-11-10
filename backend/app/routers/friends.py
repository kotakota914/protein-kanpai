"""友達一覧・フォロー・タイムライン・招待。"""

import secrets
from datetime import date, timedelta

from fastapi import APIRouter, Query, Response

from .. import errors, rules
from ..dates import jst_date_of, to_iso_utc
from ..deps import (
    ClockDep,
    CurrentUserDep,
    PublicBaseUrlDep,
    PublicOriginDep,
    SettingsDep,
    StoreDep,
)
from ..schemas import (
    FeedItemResponse,
    FriendResponse,
    InviteAcceptResponse,
    InviteResponse,
    UserRef,
)
from ..services.profile import compose_avatar_url
from ..store.base import EventRecord, InviteRecord, Store, UserRecord

router = APIRouter()

INVITE_LIFETIME = timedelta(days=7)
FEED_MAX_LIMIT = 50


@router.get("/friends", response_model=list[FriendResponse])
def list_friends(
    user: CurrentUserDep, store: StoreDep, clock: ClockDep, base_url: PublicBaseUrlDep
):
    """フォロー関係（どちら向きでも）がある人だけ。知らない人の名前は出さない（契約の安全性項目）。"""
    following = set(store.list_following_ids(user.id))
    related = (following | set(store.list_follower_ids(user.id))) - {user.id}
    now = clock()
    today = jst_date_of(now)
    friends = sorted(store.find_users(sorted(related)).values(), key=lambda u: (u.name, u.id))
    return [
        FriendResponse(
            id=friend.id,
            name=friend.name,
            avatar_url=compose_avatar_url(base_url, friend),
            following=friend.id in following,
            shaking_now=rules.is_shaking_now(friend.last_shake_at, now),
            shook_today=friend.last_shake_date == today,
        )
        for friend in friends
    ]


@router.put("/follows/{user_id}", status_code=204, response_class=Response)
def follow(user_id: str, user: CurrentUserDep, store: StoreDep, clock: ClockDep):
    if user_id == user.id:
        raise errors.invalid_argument("自分はフォローできません")
    if store.find_user(user_id) is None:
        raise errors.not_found("相手が見つかりません")
    # uid を知っているだけの人を一方的にフォローして記録やアイコンを見られないように、
    # 相手が自分をフォローしている（招待でつながった）ときだけ許す
    if not store.is_following(user_id, user.id):
        raise errors.forbidden("招待リンクからつながってください")
    store.follow(user.id, user_id, clock())
    return Response(status_code=204)


@router.delete("/follows/{user_id}", status_code=204, response_class=Response)
def unfollow(user_id: str, user: CurrentUserDep, store: StoreDep):
    if user_id == user.id:
        raise errors.invalid_argument("自分はフォローできません")
    store.unfollow(user.id, user_id)
    return Response(status_code=204)


@router.get("/feed", response_model=list[FeedItemResponse])
def read_feed(user: CurrentUserDep, store: StoreDep, clock: ClockDep, limit: int = Query(20)):
    limit = max(1, min(limit, FEED_MAX_LIMIT))
    today = jst_date_of(clock())
    following = store.list_following_ids(user.id)
    actors = store.find_users(following)
    items: list[FeedItemResponse] = []
    for actor_id in following:
        actor = actors.get(actor_id)
        if actor is None:
            continue
        for event in store.list_recent_events(actor_id, limit):
            item = compose_friend_item(event, actor, viewer_id=user.id, today=today)
            if item is not None:
                items.append(item)
    # 自分の乾杯は自分の出来事から（相手が未フォローでも出す）。種類で絞れないので多めに読む
    for event in store.list_recent_events(user.id, limit * 3):
        if event.kind == "cheer" and event.counterpart is not None:
            items.append(
                FeedItemResponse(
                    kind="cheer",
                    friend=UserRef(id=event.counterpart.id, name=event.counterpart.name),
                    text=f"{event.counterpart.name}さんと乾杯しました",
                    at=to_iso_utc(event.at),
                )
            )
    items.sort(key=lambda item: item.at, reverse=True)
    return items[:limit]


def compose_friend_item(
    event: EventRecord, actor: UserRecord, *, viewer_id: str, today: date
) -> FeedItemResponse | None:
    actor_ref = UserRef(id=actor.id, name=actor.name)
    at = to_iso_utc(event.at)
    if event.kind == "shake":
        when = "今日の" if jst_date_of(event.at) == today else ""
        return FeedItemResponse(
            kind="shake",
            friend=actor_ref,
            text=f"{actor.name}さんが{when}プロテインを振りました",
            at=at,
        )
    if event.kind == "streak":
        return FeedItemResponse(
            kind="streak",
            friend=actor_ref,
            text=f"{actor.name}さんが {event.streak}日連続を達成！",
            at=at,
        )
    if event.counterpart is None or event.counterpart.id == viewer_id:
        # 自分との乾杯は自分側の出来事として出すので、相手側の分は重ねない
        return None
    return FeedItemResponse(
        kind="cheer",
        friend=actor_ref,
        text=f"{actor.name}さんが{event.counterpart.name}さんと乾杯しました",
        at=at,
    )


@router.post("/invites", response_model=InviteResponse)
def create_invite(
    user: CurrentUserDep,
    store: StoreDep,
    clock: ClockDep,
    settings: SettingsDep,
    origin: PublicOriginDep,
):
    now = clock()
    code = unused_invite_code(store)
    store.create_invite(
        InviteRecord(
            code=code, inviter_id=user.id, created_at=now, expires_at=now + INVITE_LIFETIME
        )
    )
    # 招待リンクの先は画面（Hosting）。未設定ならこのサーバーの起点（API_PREFIX は付けない）
    base = (settings.invite_base_url or origin).rstrip("/")
    return InviteResponse(url=f"{base}/invite/{code}")


def unused_invite_code(store: Store) -> str:
    while True:
        code = secrets.token_urlsafe(6)
        if store.find_invite(code) is None:
            return code


@router.post("/invites/{code}/accept", response_model=InviteAcceptResponse)
def accept_invite(code: str, user: CurrentUserDep, store: StoreDep, clock: ClockDep):
    now = clock()
    invite = store.find_invite(code)
    if invite is None or invite.expires_at <= now:
        raise errors.not_found("招待が見つからないか、期限が切れています")
    if invite.inviter_id == user.id:
        raise errors.invalid_argument("自分の招待は受け取れません")
    inviter = store.find_user(invite.inviter_id)
    if inviter is None:
        raise errors.not_found("招待した人が見つかりません")
    store.follow(user.id, inviter.id, now)
    store.follow(inviter.id, user.id, now)
    return InviteAcceptResponse(friend=UserRef(id=inviter.id, name=inviter.name))
