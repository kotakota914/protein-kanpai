from app import errors
from app.services.gemini import ProteinPackage
from tests.conftest import PNG_1PX, as_user

JPEG_HEAD = b"\xff\xd8\xff\xe0" + b"\0" * 32


def test_scan_returns_what_gemini_read_without_saving_it(client, gemini):
    gemini.package = ProteinPackage(name="ソイプロテイン", flavor="抹茶味", protein_grams=18)
    response = client.post("/protein/scan", headers=as_user("u1"), content=JPEG_HEAD)
    assert response.status_code == 200
    assert response.json() == {"name": "ソイプロテイン", "flavor": "抹茶味", "proteinGrams": 18}
    assert gemini.calls == ["scan"]
    assert client.get("/me", headers=as_user("u1")).json()["favoriteProtein"] is None


def test_scan_accepts_png_too(client):
    assert client.post("/protein/scan", headers=as_user("u1"), content=PNG_1PX).status_code == 200


def test_scan_rejects_non_image_with_400_and_oversized_with_413(client, gemini):
    bad = client.post("/protein/scan", headers=as_user("u1"), content=b"not an image")
    assert (bad.status_code, bad.json()["error"]["code"]) == (400, "BAD_IMAGE")
    huge = client.post(
        "/protein/scan", headers=as_user("u1"), content=JPEG_HEAD + b"\0" * (10 * 1024 * 1024)
    )
    assert (huge.status_code, huge.json()["error"]["code"]) == (413, "TOO_LARGE")
    assert gemini.calls == []


def test_scan_is_422_when_gemini_cannot_read_a_protein_package(client, gemini):
    gemini.fail_with = errors.unreadable()
    response = client.post("/protein/scan", headers=as_user("u1"), content=JPEG_HEAD)
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "UNREADABLE"


def test_scan_is_503_when_gemini_is_down(client, gemini):
    gemini.fail_with = errors.ai_unavailable()
    assert client.post("/protein/scan", headers=as_user("u1"), content=JPEG_HEAD).status_code == 503


def test_scan_twice_within_5_seconds_is_429(client, clock, gemini):
    client.post("/protein/scan", headers=as_user("u1"), content=JPEG_HEAD)
    clock.advance(seconds=4)
    assert client.post("/protein/scan", headers=as_user("u1"), content=JPEG_HEAD).status_code == 429
    clock.advance(seconds=1)
    assert client.post("/protein/scan", headers=as_user("u1"), content=JPEG_HEAD).status_code == 200
    assert gemini.calls == ["scan", "scan"]
