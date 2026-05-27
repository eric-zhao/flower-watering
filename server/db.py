"""SQLite connection helpers for the flower-watering sync service.

The schema is documented in docs/plans/2026-05-27-family-sync-design.md.
A single SQLite file holds every household; rows are keyed by
``(household, ...)`` and each request only touches the household passed
in the ``X-Household`` header.
"""

from __future__ import annotations

import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path

DEFAULT_DB_PATH = Path(
    os.getenv(
        "FLOWER_WATERING_DB",
        str(Path(__file__).resolve().parent.parent / "data.db"),
    )
)

_SCHEMA = """
CREATE TABLE IF NOT EXISTS plants (
  household       TEXT    NOT NULL,
  id              TEXT    NOT NULL,
  name            TEXT    NOT NULL,
  image_bytes     BLOB,
  frequency_days  INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL,
  deleted_at      INTEGER,
  PRIMARY KEY (household, id)
);

CREATE TABLE IF NOT EXISTS waterings (
  household       TEXT    NOT NULL,
  plant_id        TEXT    NOT NULL,
  watered_date    INTEGER NOT NULL,
  watered_by      TEXT    NOT NULL,
  recorded_at     INTEGER NOT NULL,
  PRIMARY KEY (household, plant_id, watered_date, watered_by)
);

CREATE INDEX IF NOT EXISTS waterings_household_recorded
  ON waterings (household, recorded_at);

CREATE INDEX IF NOT EXISTS plants_household_updated
  ON plants (household, updated_at);
"""


def init_db(path: Path = DEFAULT_DB_PATH) -> None:
    """Create the SQLite file and apply the schema if needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(path) as conn:
        conn.executescript(_SCHEMA)
        conn.commit()


@contextmanager
def connect(path: Path = DEFAULT_DB_PATH):
    """Yield a SQLite connection with row-as-dict access and FK support."""
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()
