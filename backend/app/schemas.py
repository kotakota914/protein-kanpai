"""API が受け取る・返す JSON の形。docs/api-contract.md と 1:1 に保つ。"""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class ApiModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel, populate_by_name=True, serialize_by_alias=True
    )


class UserRef(ApiModel):
    id: str
    name: str


class FavoriteProtein(ApiModel):
    name: str = Field(min_length=1, max_length=100)
    flavor: str = Field(max_length=50)
    protein_grams: int = Field(ge=0, le=200)


class MeResponse(ApiModel):
    id: str
    name: str
    avatar_url: str | None
    points: int
    streak: int
    best_streak: int
    shook_today: bool
    total_days: int
    total_cheers: int
    days_this_week: int
    favorite_protein: FavoriteProtein | None


class AvatarResponse(ApiModel):
    avatar_url: str


class ShakeResponse(ApiModel):
    first_today: bool
    streak: int
    bonus_points: int
    cheer_with: UserRef | None
    # 契約への追加：画面が成長段階とバッジの変化を 1 往復で出せるように
    points: int
    total_days: int
    best_streak: int
    total_cheers: int


class CalendarDay(ApiModel):
    date: str
    cheer_with: list[str]


class FriendResponse(ApiModel):
    id: str
    name: str
    avatar_url: str | None
    following: bool
    shaking_now: bool
    shook_today: bool


FeedKind = Literal["shake", "cheer", "streak"]


class FeedItemResponse(ApiModel):
    kind: FeedKind
    friend: UserRef
    text: str
    at: str


class InviteResponse(ApiModel):
    url: str


class InviteAcceptResponse(ApiModel):
    friend: UserRef


class ProteinScanResponse(ApiModel):
    name: str
    flavor: str
    protein_grams: int


class WeeklySummaryResponse(ApiModel):
    text: str
    model: str
    generated_at: str


class HealthResponse(ApiModel):
    ok: bool
