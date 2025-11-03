from fastapi.testclient import TestClient
from src.main import app

client = TestClient(app)

def test_root():
    r = client.get("/")
    assert r.status_code == 200
    assert r.json().get("status") == "ok"

def test_health_check():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json().get("status") == "healthy"

def test_get_item():
    r = client.get("/items/5")
    assert r.status_code == 200
    j = r.json()
    assert j["id"] == 5
    assert j["name"] == "item-5"

def test_create_item():
    payload = {"id": 10, "name": "my-item"}
    r = client.post("/items", json=payload)
    assert r.status_code == 200
    j = r.json()
    assert j == payload
