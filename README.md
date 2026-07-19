# Rideshare-PK

Mobile-first **carpool marketplace for Pakistan**: drivers with spare seats on a recurring route (providers) meet commuters (seekers), with geo-corridor matching, live map tracking, verification/trust, and cost-sharing pricing.

**Status:** Phase 1 (MVP) in progress. See [ARCHITECTURE.md](ARCHITECTURE.md) for the module map and scale path.

## Run in under 5 minutes

Prereqs: Node ≥ 20, Docker (for local Postgres+PostGIS and Redis).

```bash
git clone <repo> && cd rideshare-pk
cp .env.example .env          # defaults work for local dev
npm ci
npm run db:up                 # Postgres+PostGIS :5432, Redis :6379
psql postgresql://rideshare:rideshare@localhost:5432/rideshare -f apps/backend/schema.sql
npm run dev                   # backend on http://localhost:4000
```

Smoke check: `curl http://localhost:4000/health` → `{"status":"ok",...}`.

No Docker? Point `DATABASE_URL` at a free-tier [Supabase](https://supabase.com) project (PostGIS is available via `create extension postgis`) and `REDIS_URL` at a free Upstash instance.

## Commands

| Command | What it does |
|---|---|
| `npm run dev` | Backend in watch mode |
| `npm run lint` / `npm run typecheck` / `npm test` | What CI runs |
| `npm run db:up` / `npm run db:down` | Local infra via docker compose |

## Layout

```
apps/backend/    NestJS modular monolith (REST /api/v1 + WebSocket tracking)
apps/web/        Next.js PWA (added in build step 8)
db/migrations/   SQL migrations
```
