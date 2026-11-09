"""VertexGemini の応答の読み方。本物の API は呼ばず、偽のクライアントで確かめる。"""

import json

import pytest

from app import errors
from app.services.gemini import VertexGemini, WeeklyStats, _PackageReading, response_schema_for


class FakeResponse:
    def __init__(self, text):
        self.text = text


class FakeModels:
    def __init__(self, text=None, error=None):
        self.text = text
        self.error = error
        self.calls = []

    def generate_content(self, *, model, contents, config):
        self.calls.append((model, contents, config))
        if self.error:
            raise self.error
        return FakeResponse(self.text)


class FakeClient:
    def __init__(self, models):
        self.models = models


def gemini_with(text=None, error=None):
    models = FakeModels(text=text, error=error)
    return VertexGemini("proj", "global", "gemini-test", client=FakeClient(models)), models


def test_response_schema_drops_default_and_title_which_vertex_does_not_accept():
    schema = response_schema_for(_PackageReading)
    assert "title" not in schema and "description" not in schema
    for prop in schema["properties"].values():
        assert "default" not in prop and "title" not in prop
    assert schema["required"] == ["is_protein_package"]


def test_read_protein_package_returns_the_structured_fields():
    gemini, models = gemini_with(
        text=json.dumps(
            {
                "is_protein_package": True,
                "name": " ホエイ ",
                "flavor": "ココア味",
                "protein_grams_per_serving": 21,
            }
        )
    )
    package = gemini.read_protein_package(b"\xff\xd8\xff", "image/jpeg")
    assert (package.name, package.flavor, package.protein_grams) == ("ホエイ", "ココア味", 21)
    model, contents, config = models.calls[0]
    assert model == "gemini-test"
    assert config.response_mime_type == "application/json"


def test_read_protein_package_is_422_when_not_a_protein_package_or_unparseable():
    gemini, _ = gemini_with(text=json.dumps({"is_protein_package": False}))
    with pytest.raises(errors.ApiError) as caught:
        gemini.read_protein_package(b"img", "image/png")
    assert caught.value.status_code == 422
    gemini, _ = gemini_with(text="これは JSON ではない")
    with pytest.raises(errors.ApiError) as caught:
        gemini.read_protein_package(b"img", "image/png")
    assert caught.value.status_code == 422


def test_api_errors_from_gemini_become_503():
    from google.genai import errors as genai_errors

    gemini, _ = gemini_with(error=genai_errors.APIError(500, {"error": {"message": "down"}}))
    with pytest.raises(errors.ApiError) as caught:
        gemini.write_weekly_summary(WeeklyStats(days_this_week=2, streak=2, cheers_this_week=0))
    assert caught.value.status_code == 503


def test_weekly_summary_returns_text_and_model_and_rejects_empty_output():
    gemini, _ = gemini_with(text="  今週は 2日 振れました。あと 3日。  ")
    assert gemini.write_weekly_summary(WeeklyStats(2, 2, 0)) == (
        "今週は 2日 振れました。あと 3日。",
        "gemini-test",
    )
    gemini, _ = gemini_with(text="")
    with pytest.raises(errors.ApiError) as caught:
        gemini.write_weekly_summary(WeeklyStats(2, 2, 0))
    assert caught.value.status_code == 503
