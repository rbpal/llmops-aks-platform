from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_healthz():
    r = client.get("/healthz")
    assert r.status_code == 200 and r.json()["status"] == "ok"


def test_metrics():
    r = client.get("/metrics")
    assert r.status_code == 200


def test_chat_offtopic_refusal():
    # off-topic short-circuits before retrieval, so no index needed
    r = client.post("/chat", json={"question": "what's the weather tomorrow?"})
    assert r.status_code == 200
    assert "accounting and tax" in r.json()["answer"]
