from fastapi.testclient import TestClient


def test_health_reports_version_slot_and_database(
    client: TestClient,
):
    response = client.get("/health")

    assert response.status_code == 200

    body = response.json()
    assert body["status"] == "healthy"
    assert body["service"] == "course-service"
    assert body["database"] == "ok"
    assert "version" in body
    assert "slot" in body
