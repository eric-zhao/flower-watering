"""Pydantic schemas for the sync API.

Photos travel as base64-encoded strings in JSON bodies. We keep them
optional so a plant can be created without a photo.
"""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, Field


class PlantUpsert(BaseModel):
    name: str
    image_b64: Optional[str] = None
    frequency_days: int = Field(ge=1, le=365)
    updated_at: int = Field(ge=0)


class PlantDelete(BaseModel):
    deleted_at: int = Field(ge=0)


class WateringCreate(BaseModel):
    watered_date: int = Field(ge=0)
    watered_by: str = ""
    recorded_at: int = Field(ge=0)


class PlantState(BaseModel):
    id: str
    name: str
    image_b64: Optional[str]
    frequency_days: int
    updated_at: int
    deleted_at: Optional[int]


class WateringState(BaseModel):
    plant_id: str
    watered_date: int
    watered_by: str
    recorded_at: int


class StateResponse(BaseModel):
    server_now: int
    plants: list[PlantState]
    waterings: list[WateringState]
