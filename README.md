# Rideshare-PK

A **carpool marketplace for Pakistan**: anyone with spare seats — car, bike, Hiace, or minivan — posts a route; commuters find and book seats. Geo-corridor matching (PostGIS), live trip tracking (WebSocket), verification/trust badges, ratings, safety centre, cash-only cost-sharing.

**Live:**
- API — https://rideshare-pk.fly.dev (`/health`, `/health/ready`)
- Admin console — https://rideshare-pk.fly.dev/admin
- Mobile app — Flutter (`apps/mobile`), Android APK + web build

## Repo layout

```
apps/backend/    NestJS modular monolith — REST /api/v1 + Socket.IO /trips
apps/admin/      Next.js admin console (static export served at /admin)
apps/mobile/     Flutter app (BLoC + repository pattern) — Android/iOS/web
db/migrations/   SQL migrations (apply with apps/backend/scripts/db-apply.mjs)
```

## Stack

| Layer | Tech |
|---|---|
| API | NestJS (TypeScript), zod validation, JWT (access 15m / rotating refresh 30d) |
| DB | **PostgreSQL + PostGIS** (Supabase) — GiST geo indexes drive ride search |
| Cache/bus | Redis via `KeyValueStore` + `MessageBus` interfaces (in-memory dev fallback) |
| Realtime | Socket.IO namespace `/trips`, Redis pub/sub backplane |
| Mobile | Flutter, flutter_bloc, dio, flutter_map (OSM), socket_io_client |
| Admin | Next.js App Router, Tailwind v4, recharts, lucide |
| Deploy | Docker on Fly.io (`sin`); one image ships API + admin console |

## Run locally (< 5 min)

Prereqs: Node ≥ 20. (Docker/Postgres optional — see below.)

```bash
npm ci
npm run dev            # backend on http://localhost:4000 — zero infra needed
```

With no `DATABASE_URL`/`REDIS_URL` the API uses **in-memory dev drivers** (single
instance, data resets on restart) and `OTP_DEV_MODE` returns OTP codes in
responses — the full flow works offline.

Real database: `cp .env.example .env`, set `DATABASE_URL` (Supabase or
`npm run db:up` for local Docker PostGIS), then:

```bash
node apps/backend/scripts/db-apply.mjs apps/backend/schema.sql   # first time
node apps/backend/scripts/seed.mjs                               # demo Lahore rides
```

Mobile app (web preview): `cd apps/mobile && flutter run -d chrome`
(or `flutter build web` and serve `build/web`). Point it at a local API with
`--dart-define=API_BASE_URL=http://localhost:4000`.

Admin console dev: `cd apps/admin && npm run dev` with
`NEXT_PUBLIC_API_BASE_URL=http://localhost:4000`.

## Quality gates

```bash
npm run lint && npm run typecheck && npm test   # backend (74 tests)
cd apps/backend && npm run smoke                # boots server, checks /health
node scripts/api-smoke.mjs                      # full HTTP E2E incl. WS tracking,
                                                # booking race, ratings, safety
cd apps/mobile && flutter analyze && flutter test   # 18 tests incl. widget flows
```

The API smoke proves the invariants that matter: 4 concurrent bookings on a
3-seat ride → exactly 3 succeed; a rider's socket receives the driver's
location; a spent refresh token is rejected; `EXPLAIN` (via
`scripts/explain-search.mjs`) shows the geo search hitting both GiST indexes.

## Operations

- **Deploy**: `flyctl deploy --remote-only` (builds backend + admin console).
- **Migrations**: add `db/migrations/NNNN_*.sql`, apply with `db-apply.mjs`.
- **Grant admin**: `DATABASE_URL=… node apps/backend/scripts/make-admin.mjs +923…`
- **Secrets** (Fly): `DATABASE_URL`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`,
  `CNIC_ENC_KEY`, `REDIS_URL` (when provisioned), `GOOGLE_CLIENT_ID` /
  `FB_APP_ID`+`FB_APP_SECRET` (to enable social login).
- **Scale**: single machine until `REDIS_URL` is set (in-memory OTP/bus are
  per-instance); with Redis, `flyctl scale count N` is safe — the API is stateless.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the module map and scale path, and
[docs/API.md](docs/API.md) for the endpoint reference.
