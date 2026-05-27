# Family Sync — Design

**Date:** 2026-05-27
**Status:** Approved, ready to implement
**Slice:** 4

## Problem

Multiple family members want to share one plant list. When Alice marks the
rosemary watered on her phone, Bob's phone should reflect that. When Bob adds
a new plant with a photo, it should appear on Alice's home screen.

## Goals

- A device opts into a "household" by entering a shared passcode.
- All data — plants, photos, watering history — replicates to every device
  in the household.
- App still works fully offline; changes queue and replay when network
  returns.
- Watering history merges across devices (no entry is lost).

## Non-goals (slice 4)

- TLS / HTTPS (plaintext HTTP on port 7100 is acceptable for household scale).
- Per-user accounts, passwords, password reset.
- Real-time push (server doesn't notify clients; clients poll).
- Server admin UI, audit log.
- Photo deduplication (each upload sends bytes again — fine at household
  scale).

## Stack

**Server:**
- Python 3.10 + FastAPI + Uvicorn (matches existing service conventions).
- SQLite in a single file `/root/flower_watering/data.db` (no DB server).
- Lives in the same `flower-watering` repo under `server/`.

**Client:**
- New `lib/services/sync_service.dart` + `sync` Hive box.
- HTTP via the `http` package.

## Server

### Filesystem layout
```
flower-watering/server/
├── main.py             # FastAPI app, endpoint handlers
├── db.py               # SQLite connection + schema init
├── models.py           # Pydantic request/response schemas
├── requirements.txt    # fastapi, uvicorn[standard], pydantic
└── supervisord.conf    # snippet for /etc/supervisor/conf.d/
```

### Deployment
- Repo at `/root/flower_watering` on `47.237.79.175`.
- DB file at `/root/flower_watering/data.db`.
- Supervised by `supervisorctl` as `flower_watering_service`.
- Update flow (your standard workflow):
  ```bash
  ssh root@47.237.79.175 'cd /root/flower_watering && git pull && \
    supervisorctl restart flower_watering_service'
  ```

### Schema

```sql
CREATE TABLE plants (
  household       TEXT    NOT NULL,
  id              TEXT    NOT NULL,
  name            TEXT    NOT NULL,
  image_bytes     BLOB,                  -- nullable
  frequency_days  INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL,       -- ms since epoch, client-set
  deleted_at      INTEGER,                -- null = alive
  PRIMARY KEY (household, id)
);

CREATE TABLE waterings (
  household       TEXT    NOT NULL,
  plant_id        TEXT    NOT NULL,
  watered_date    INTEGER NOT NULL,       -- midnight ms since epoch
  watered_by      TEXT    NOT NULL,       -- '' if unknown
  recorded_at     INTEGER NOT NULL,
  PRIMARY KEY (household, plant_id, watered_date, watered_by)
);

CREATE INDEX waterings_household_recorded
  ON waterings (household, recorded_at);
CREATE INDEX plants_household_updated
  ON plants (household, updated_at);
```

The waterings PK gives free dedup: same plant + same date + same person =
one row, no conflicts possible.

### Authentication

Every request must send the header:

```
X-Household: <passcode>
```

No login, no user accounts. Whoever knows the passcode reads/writes that
household. Passcodes are arbitrary strings (`zhao-family-2026`).

If `X-Household` is missing → 401. If the header is present, the request
proceeds; we never validate that the passcode "exists" — first write to a
new passcode creates the household.

### Endpoints

All under `/api/`, all require `X-Household`. Photos travel as base64 in
JSON (~33% overhead, acceptable at <2 MB per photo).

| Method   | Path                                  | Purpose |
|----------|---------------------------------------|---------|
| `GET`    | `/api/state?since=<ms>`               | Plants + waterings newer than `since`. Returns `{server_now, plants, waterings}`. Initial sync uses `since=0`. |
| `PUT`    | `/api/plants/{id}`                    | Upsert plant. Body: `{name, image_b64, frequency_days, updated_at}`. Server keeps the row only if incoming `updated_at` is newer than the stored one. |
| `DELETE` | `/api/plants/{id}`                    | Soft delete. Body: `{deleted_at}`. Newer `deleted_at` wins over older update. |
| `POST`   | `/api/plants/{id}/waterings`          | Append a watering. Body: `{watered_date, watered_by, recorded_at}`. PK dedup. |

### Conflict resolution
- **Plant metadata:** last-write-wins by `updated_at`.
- **Waterings:** append-only merge — no conflicts by construction.
- **Delete vs. update:** whichever timestamp is newer wins. So if Alice
  deletes a plant at T=100 and Bob updates it at T=200, Bob's update wins
  and the plant comes back.

## Client

### New state

A new Hive box `sync` holds:
```dart
class SyncState {
  String householdPasscode;   // empty until joined
  int lastSyncedAt;           // server_now from last sync; used as `since`
  List<PendingOp> queue;      // writes waiting to push
}

class PendingOp {
  enum Kind { upsertPlant, deletePlant, addWatering }
  Kind kind;
  String plantId;
  Map<String, dynamic> payload;
}
```

### Sync cycle

`SyncService.runSync()` runs under a mutex; concurrent triggers no-op.

```
1. If householdPasscode is empty → return.
2. Drain queue: for each PendingOp, POST/PUT/DELETE.
   - Success → remove from queue.
   - Network error → keep, break out (try later).
3. GET /api/state?since=lastSyncedAt.
4. For each remote plant:
     - If local plant doesn't exist OR remote.updated_at > local.updated_at
       → upsert.
     - If remote.deleted_at > local.updated_at → soft-delete locally.
5. For each remote watering: insert into local plant's history if
   (watered_date, watered_by) not already present.
6. lastSyncedAt = server_now from step 3.
7. notifyListeners() → UI refreshes.
```

### Triggers

1. App start.
2. Passcode field change in Settings.
3. Any local write (push-only sweep is fine, full pull-and-push for
   simplicity).
4. 60-second timer while app is foregrounded.
5. Pull-to-refresh on Home.

### UI

A new **家庭共享 / Family Sync** section in `SettingsScreen`:
- Passcode TextField (bound to `SyncState.householdPasscode`).
- Status line:
  - empty passcode → "尚未加入 / Not joined"
  - queue non-empty → "离线 — N 条待同步 / Offline — N pending"
  - else → "已同步 — N 分钟前 / Synced N min ago"
- No other screens change. They re-read Hive via existing listeners.

### Photo handling

Photos travel as base64 in the upsert payload (~270 KB on the wire for a
200 KB photo). Cheap at household scale. We don't sync photos separately or
deduplicate by hash in v1.

## Security trade-offs (accepted)

- Plaintext HTTP — passcode + plant data readable on network path.
  Acceptable for personal/family use. TLS via Cloudflare tunnel or a domain
  + Let's Encrypt is a follow-up if desired.
- Passcode-only auth — leaked passcode = full access. Mitigation: change it.
- No rate limit — hobby scale, no abuse vector.

## Edge cases handled
- Switching passcodes does **not** wipe local data (avoid losing on typo).
- Photo > 2 MB → server returns 413, client logs and skips.
- Clock skew between devices → last-write-wins becomes "faster clock wins."
  Acceptable.
- Two devices simultaneously water same plant on same day → PK dedup means
  one row, attribution goes to whichever push arrives first.

## Implementation order
1. Server scaffold (FastAPI + SQLite, 4 endpoints).
2. Local smoke test (`uvicorn` + `curl`).
3. Deploy to middle server + supervisord registration.
4. Client `SyncService` + Hive box.
5. Wire into `PlantRepository` (every write enqueues).
6. Settings UI (passcode field + status).
7. End-to-end test from Chrome.
