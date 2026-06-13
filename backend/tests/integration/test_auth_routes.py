from __future__ import annotations

from app.models.user import User
from app.utils.security import hash_pin


async def test_list_users_returns_active_staff(client, db):
    db.add_all(
        [
            User(name="Admin", role="admin", pin_hash=hash_pin("1234"), is_active=True),
            User(name="Inactive", role="staff", pin_hash=hash_pin("5678"), is_active=False),
        ]
    )
    await db.commit()

    response = await client.get("/api/v1/auth/users")
    assert response.status_code == 200
    data = response.json()
    assert len(data["items"]) == 1
    assert data["items"][0]["name"] == "Admin"


async def test_login_success(client, db):
    user = User(name="Admin", role="admin", pin_hash=hash_pin("1234"), is_active=True)
    db.add(user)
    await db.commit()
    await db.refresh(user)

    response = await client.post(
        "/api/v1/auth/login",
        json={"user_id": str(user.id), "pin": "1234"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    assert "access_token" in body
    assert "refresh_token" in body

