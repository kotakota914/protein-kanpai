"""Gemini を使う 2 つの機能。vertex：Vertex AI 経由の本物。fake：決まった答えを返す。

Cloud Credit は AI Studio の API キーには使えないので Vertex AI 経由にする（docs/product.md）。
"""

import json
import logging
from dataclasses import dataclass
from typing import Any, Protocol

from pydantic import BaseModel, ValidationError

from .. import errors

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class ProteinPackage:
    name: str
    flavor: str
    protein_grams: int


@dataclass(frozen=True)
class WeeklyStats:
    days_this_week: int
    streak: int
    cheers_this_week: int
    target_days: int = 5


class Gemini(Protocol):
    def read_protein_package(self, image: bytes, mime_type: str) -> ProteinPackage: ...
    def write_weekly_summary(self, stats: WeeklyStats) -> tuple[str, str]:
        """(文章, 使ったモデル名) を返す。"""
        ...


class FakeGemini:
    """テスト用。`fail_with` に ApiError を入れると、その例外を投げる。"""

    def __init__(self) -> None:
        self.fail_with: Exception | None = None
        self.calls: list[str] = []
        self.package = ProteinPackage(name="ホエイプロテイン", flavor="ココア味", protein_grams=20)

    def read_protein_package(self, image: bytes, mime_type: str) -> ProteinPackage:
        self.calls.append("scan")
        if self.fail_with:
            raise self.fail_with
        return self.package

    def write_weekly_summary(self, stats: WeeklyStats) -> tuple[str, str]:
        self.calls.append("summary")
        if self.fail_with:
            raise self.fail_with
        left = max(0, stats.target_days - stats.days_this_week)
        head = f"今週は {stats.days_this_week}日 振れました。"
        tail = (
            f"目標の {stats.target_days}日 を達成。この調子で続けよう。"
            if left == 0
            else f"あと {left}日 で目標の {stats.target_days}日 に届きます。"
        )
        text = head + tail
        return text, "fake-gemini"


class _PackageReading(BaseModel):
    """構造化出力のスキーマ。読めない写真は is_protein_package=false で返させる。"""

    is_protein_package: bool
    name: str | None = None
    flavor: str | None = None
    protein_grams_per_serving: int | None = None


_SCAN_PROMPT = (
    "この写真を見て、プロテイン（たんぱく質補給食品）の袋・容器かどうかを判定してください。"
    "プロテインなら、商品名（name）、味（flavor。例：ココア味）、"
    "1 食あたりのたんぱく質量をグラムの整数（protein_grams_per_serving）で読み取ってください。"
    "読み取れない項目は null にしてください。"
    "プロテインの袋・容器でない、または文字が読めない場合は "
    "is_protein_package を false にしてください。"
)

_SUMMARY_SYSTEM = (
    "あなたは筋トレを続ける人を励ます応援係です。渡された記録の数字だけをもとに、"
    "日本語で 2 文以内、80 文字以内の前向きな一言を書いてください。"
    "医療・栄養・健康に関する助言や診断、サプリメントの摂取量の指示は絶対にしないでください。"
    "数字は渡されたものだけを使い、作らないでください。絵文字は使わないでください。"
)


def response_schema_for(model: type[BaseModel]) -> dict[str, Any]:
    """pydantic の JSON スキーマから、Vertex の responseJsonSchema が受け付けない語を外す。

    `default` と `title` は対応語の一覧に無い
    （https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/control-generated-output ）。
    受け付けられず 400 になる危険を避けるため、送る前に落とす。
    """
    schema = dict(model.model_json_schema())
    schema.pop("title", None)
    schema.pop("description", None)
    schema["properties"] = {
        name: {k: v for k, v in prop.items() if k not in ("title", "default")}
        for name, prop in schema.get("properties", {}).items()
    }
    return schema


class VertexGemini:
    def __init__(
        self, project: str | None, location: str, model: str, client: Any | None = None
    ) -> None:
        self._client = client or _build_client(project, location)
        self._model = model

    @property
    def model_name(self) -> str:
        return self._model

    def read_protein_package(self, image: bytes, mime_type: str) -> ProteinPackage:
        from google.genai import types

        # thinking_budget=0 は、2.5 Flash が既定で「思考」に時間と料金を使うのを止めるため。
        # 思考に対応しないモデルに変えたときは外す（API がエラーを返す）
        config = types.GenerateContentConfig(
            response_mime_type="application/json",
            response_json_schema=response_schema_for(_PackageReading),
            temperature=0,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
        )
        text = self._generate(
            [types.Part.from_bytes(data=image, mime_type=mime_type), _SCAN_PROMPT], config
        )
        try:
            reading = _PackageReading.model_validate_json(text)
        except ValidationError as exc:
            logger.warning("Gemini の出力がスキーマに合わない: %.200s", text)
            raise errors.unreadable() from exc
        if not reading.is_protein_package or not reading.name:
            raise errors.unreadable()
        return ProteinPackage(
            name=reading.name.strip(),
            flavor=(reading.flavor or "").strip(),
            protein_grams=max(0, reading.protein_grams_per_serving or 0),
        )

    def write_weekly_summary(self, stats: WeeklyStats) -> tuple[str, str]:
        from google.genai import types

        config = types.GenerateContentConfig(
            system_instruction=_SUMMARY_SYSTEM,
            temperature=0.7,
            max_output_tokens=200,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
        )
        prompt = "今週の記録: " + json.dumps(
            {
                "今週振った日数": stats.days_this_week,
                "今週の目標日数": stats.target_days,
                "連続日数": stats.streak,
                "今週の乾杯回数": stats.cheers_this_week,
            },
            ensure_ascii=False,
        )
        text = self._generate(prompt, config).strip()
        if not text:
            logger.error("Gemini がふりかえりの文章を返さなかった")
            raise errors.ai_unavailable()
        return text, self._model

    def _generate(self, contents, config) -> str:
        from google.genai import errors as genai_errors

        try:
            response = self._client.models.generate_content(
                model=self._model, contents=contents, config=config
            )
        except genai_errors.APIError as exc:
            logger.exception("Gemini の呼び出しに失敗（model=%s）", self._model)
            raise errors.ai_unavailable() from exc
        return response.text or ""


def _build_client(project: str | None, location: str):
    from google import genai

    return genai.Client(enterprise=True, project=project, location=location)
