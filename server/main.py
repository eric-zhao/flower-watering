"""FastAPI app for flower-watering family sync.

Run locally:
    cd server && pip install -r requirements.txt
    uvicorn main:app --host 0.0.0.0 --port 7100

On production (middle server) it's run by supervisord; see supervisord.conf.
"""

from __future__ import annotations

import base64
import time

from fastapi import FastAPI, Header, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware

from db import connect, init_db
from models import (
    PlantDelete,
    PlantState,
    PlantUpsert,
    StateResponse,
    WateringCreate,
    WateringState,
)

app = FastAPI(title="flower-watering sync", version="1.0.0")

# Chrome dev preview talks to us cross-origin from localhost:8765.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def _startup() -> None:
    init_db()


def _household(x_household: str | None) -> str:
    if not x_household:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing X-Household header",
        )
    return x_household.strip()


def _now_ms() -> int:
    return int(time.time() * 1000)


@app.get("/api/health")
def health() -> dict:
    return {"ok": True, "now": _now_ms()}


@app.get("/api/state", response_model=StateResponse)
def get_state(
    since: int = 0,
    x_household: str | None = Header(default=None),
) -> StateResponse:
    household = _household(x_household)
    now = _now_ms()
    with connect() as conn:
        plant_rows = conn.execute(
            """
            SELECT id, name, image_bytes, frequency_days, updated_at, deleted_at
            FROM plants
            WHERE household = ?
              AND (updated_at > ? OR (deleted_at IS NOT NULL AND deleted_at > ?))
            """,
            (household, since, since),
        ).fetchall()

        watering_rows = conn.execute(
            """
            SELECT plant_id, watered_date, watered_by, recorded_at
            FROM waterings
            WHERE household = ? AND recorded_at > ?
            """,
            (household, since),
        ).fetchall()

    plants = [
        PlantState(
            id=row["id"],
            name=row["name"],
            image_b64=(
                base64.b64encode(row["image_bytes"]).decode("ascii")
                if row["image_bytes"]
                else None
            ),
            frequency_days=row["frequency_days"],
            updated_at=row["updated_at"],
            deleted_at=row["deleted_at"],
        )
        for row in plant_rows
    ]
    waterings = [
        WateringState(
            plant_id=row["plant_id"],
            watered_date=row["watered_date"],
            watered_by=row["watered_by"],
            recorded_at=row["recorded_at"],
        )
        for row in watering_rows
    ]
    return StateResponse(server_now=now, plants=plants, waterings=waterings)


@app.put("/api/plants/{plant_id}")
def upsert_plant(
    plant_id: str,
    body: PlantUpsert,
    x_household: str | None = Header(default=None),
) -> dict:
    household = _household(x_household)
    image_blob = (
        base64.b64decode(body.image_b64) if body.image_b64 else None
    )
    if image_blob and len(image_blob) > 2 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="image > 2 MB",
        )

    with connect() as conn:
        existing = conn.execute(
            "SELECT updated_at, deleted_at FROM plants WHERE household = ? AND id = ?",
            (household, plant_id),
        ).fetchone()

        # Last-write-wins: only apply if incoming updated_at is strictly newer
        # than any stored timestamp (update or delete).
        if existing is not None:
            local_max = max(
                existing["updated_at"] or 0,
                existing["deleted_at"] or 0,
            )
            if body.updated_at <= local_max:
                return {"applied": False, "reason": "stale"}

        conn.execute(
            """
            INSERT INTO plants
                (household, id, name, image_bytes, frequency_days,
                 updated_at, deleted_at)
            VALUES (?, ?, ?, ?, ?, ?, NULL)
            ON CONFLICT (household, id) DO UPDATE SET
                name           = excluded.name,
                image_bytes    = excluded.image_bytes,
                frequency_days = excluded.frequency_days,
                updated_at     = excluded.updated_at,
                deleted_at     = NULL
            """,
            (
                household,
                plant_id,
                body.name,
                image_blob,
                body.frequency_days,
                body.updated_at,
            ),
        )
    return {"applied": True}


@app.delete("/api/plants/{plant_id}")
def delete_plant(
    plant_id: str,
    body: PlantDelete,
    x_household: str | None = Header(default=None),
) -> dict:
    household = _household(x_household)
    with connect() as conn:
        existing = conn.execute(
            "SELECT updated_at, deleted_at FROM plants WHERE household = ? AND id = ?",
            (household, plant_id),
        ).fetchone()

        if existing is not None:
            local_max = max(
                existing["updated_at"] or 0,
                existing["deleted_at"] or 0,
            )
            if body.deleted_at <= local_max:
                return {"applied": False, "reason": "stale"}

        # Insert-or-update a tombstone. Keep the name/frequency intact so a
        # later state read can still surface 'this plant existed and was deleted'.
        conn.execute(
            """
            INSERT INTO plants
                (household, id, name, image_bytes, frequency_days,
                 updated_at, deleted_at)
            VALUES (?, ?, '', NULL, 1, ?, ?)
            ON CONFLICT (household, id) DO UPDATE SET
                deleted_at = excluded.deleted_at,
                updated_at = excluded.updated_at
            """,
            (household, plant_id, body.deleted_at, body.deleted_at),
        )
    return {"applied": True}


@app.post("/api/plants/{plant_id}/waterings")
def add_watering(
    plant_id: str,
    body: WateringCreate,
    x_household: str | None = Header(default=None),
) -> dict:
    household = _household(x_household)
    with connect() as conn:
        conn.execute(
            """
            INSERT OR IGNORE INTO waterings
                (household, plant_id, watered_date, watered_by, recorded_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                household,
                plant_id,
                body.watered_date,
                body.watered_by,
                body.recorded_at,
            ),
        )
    return {"ok": True}
