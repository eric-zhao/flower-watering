# flower-watering sync server

Tiny FastAPI service that holds the shared household state for the
flower-watering app. SQLite single-file database; one process per
deployment.

See `docs/plans/2026-05-27-family-sync-design.md` for the full design.

## Local run

```bash
cd server
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/uvicorn main:app --host 0.0.0.0 --port 7100 --reload
```

## Deploy on the middle server (47.237.79.175)

Once per host:

```bash
ssh root@47.237.79.175
cd /root
git clone https://github.com/eric-zhao/flower-watering.git flower_watering
cd flower_watering/server
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp supervisord.conf /etc/supervisor/conf.d/flower_watering_service.conf
supervisorctl reread && supervisorctl update
supervisorctl start flower_watering_service
```

Per release:

```bash
ssh root@47.237.79.175 'cd /root/flower_watering && git pull && \
  supervisorctl restart flower_watering_service'
```

## Smoke test

```bash
H="X-Household: smoke-test"
BASE=http://localhost:7100

curl -s $BASE/api/health
# {"ok":true,"now":...}

curl -s -X PUT $BASE/api/plants/p1 -H "$H" -H "Content-Type: application/json" \
  -d '{"name":"Rose","frequency_days":7,"updated_at":1716700000000}'
# {"applied":true}

curl -s -X POST $BASE/api/plants/p1/waterings -H "$H" \
  -H "Content-Type: application/json" \
  -d '{"watered_date":1716700000000,"watered_by":"Alice","recorded_at":1716700000000}'
# {"ok":true}

curl -s "$BASE/api/state?since=0" -H "$H" | jq .
```
