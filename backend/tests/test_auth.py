import pytest

from app.config import Settings
from tests.conftest import as_user


def test_request_without_authorization_header_is_401(client):
    response = client.get("/me")
    assert response.status_code == 401
    assert response.json() == {
        "error": {"code": "UNAUTHENTICATED", "message": "ログインが必要です"}
    }


def test_request_with_non_bearer_scheme_is_401(client):
    assert client.get("/me", headers={"Authorization": "Basic abc"}).status_code == 401


def test_dev_token_without_dev_prefix_is_401(client):
    assert client.get("/me", headers={"Authorization": "Bearer eyJhbGci"}).status_code == 401


def test_first_request_creates_the_user_with_the_token_name(client, store):
    response = client.get("/me", headers=as_user("u1", "はなこ"))
    assert response.status_code == 200
    assert response.json()["name"] == "はなこ"
    assert store.find_user("u1").name == "はなこ"


def test_dev_token_without_name_falls_back_to_anonymous(client):
    response = client.get("/me", headers={"Authorization": "Bearer dev:u9"})
    assert response.json()["name"] == "名無し"


def test_healthz_needs_no_login(client):
    assert client.get("/healthz").json() == {"ok": True}


def test_settings_refuse_dev_auth_on_cloud_run(monkeypatch):
    monkeypatch.setenv("K_SERVICE", "protein-kanpai-api")
    settings = Settings(
        _env_file=None, auth_mode="dev", store="firestore", gemini="vertex", storage="gcs"
    )
    with pytest.raises(RuntimeError, match="AUTH_MODE"):
        settings.refuse_fakes_on_cloud_run()


def test_settings_accept_real_services_on_cloud_run(monkeypatch):
    monkeypatch.setenv("K_SERVICE", "protein-kanpai-api")
    Settings(
        _env_file=None, auth_mode="firebase", store="firestore", gemini="vertex", storage="gcs"
    ).refuse_fakes_on_cloud_run()


def test_settings_allow_fakes_outside_cloud_run(monkeypatch):
    monkeypatch.delenv("K_SERVICE", raising=False)
    Settings(_env_file=None).refuse_fakes_on_cloud_run()


def test_unknown_path_uses_the_same_error_envelope(client):
    response = client.get("/nope", headers=as_user("u1"))
    assert response.status_code == 404
    assert response.json() == {"error": {"code": "NOT_FOUND", "message": "Not Found"}}


def test_display_name_prefers_name_then_email_local_part_then_anonymous():
    from app.auth import display_name_from_claims

    assert (
        display_name_from_claims({"name": " こうたろう ", "email": "k@example.com"}) == "こうたろう"
    )
    assert display_name_from_claims({"email": "kotaro@example.com"}) == "kotaro"
    assert display_name_from_claims({}) == "名無し"


def test_load_settings_refuses_fakes_on_cloud_run(monkeypatch):
    from app.config import load_settings

    monkeypatch.setenv("K_SERVICE", "api")
    monkeypatch.setenv("AUTH_MODE", "dev")
    with pytest.raises(RuntimeError):
        load_settings()


def test_api_prefix_moves_every_route_including_healthz(
    settings, clock, sleep, store, gemini, avatar_storage
):
    from fastapi.testclient import TestClient

    from app.main import create_app

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
    assert client.get("/api/healthz").status_code == 200
    assert client.get("/healthz").status_code == 404
    assert client.get("/api/me", headers=as_user("u1")).status_code == 200


def test_unexpected_exception_is_returned_in_the_error_envelope(app):
    from fastapi.testclient import TestClient

    @app.get("/boom")
    def boom():
        raise RuntimeError("壊れた")

    client = TestClient(app, raise_server_exceptions=False)
    response = client.get("/boom")
    assert response.status_code == 500
    assert response.json() == {
        "error": {"code": "INTERNAL", "message": "サーバーでエラーが起きました"}
    }
