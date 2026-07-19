# Architecture

## Shape

One deployable **modular monolith** (NestJS) + one PWA (Next.js) + Postgres/PostGIS + Redis. Stateless API instances; all shared state in Postgres/Redis so replicas scale horizontally behind a load balancer.

## Module map (backend)

Each domain is a Nest module. Modules call each other's **exported services only** — never each other's tables — so any module can later be peeled into its own service without a rewrite.

| Module | Owns | Notes |
|---|---|---|
| `auth` | phone OTP, JWT access/refresh, rate limits | OTP send is async (queue); hard rate limits — OTP is the per-signup cost |
| `users` | profiles, roles, CNIC capture | PII minimised, CNIC encrypted at rest |
| `vehicles` | vehicle records + docs | |
| `rides` | ride posting, lifecycle | `city` dimension on every core row (multi-city ready) |
| `matching` | geo+time search | PostGIS `ST_DWithin` on `geography` + GiST indexes; **never** scan-and-filter in app code |
| `bookings` | seat reservation | race-safe single-statement decrement + idempotency keys |
| `tracking` | live trips | WS + Redis pub/sub backplane; locations in Redis geo sets, throttled ≤1/3s |
| `trust` | ratings, verification queue, badges | |
| `notifications` | FCM push, SMS/WhatsApp adapters | queue-backed with retries |
| `admin` | review queue, disputes, KPIs | |
| `payments` | Phase 2 stub interfaces | Easypaisa/JazzCash/Raast adapters later |

## Key decisions

- **Search** — `rides` carries `geography(Point)` origin/dest + optional route `LineString`; matching is `ST_DWithin(origin_geo, :pickup, :r) AND ST_DWithin(dest_geo, :drop, :r) AND depart_at BETWEEN ...`, backed by GiST + btree indexes (see `apps/backend/schema.sql`). Prove with `EXPLAIN` on seeded data (build step 4).
- **Seat race** — `UPDATE rides SET seats_available = seats_available - :n WHERE id = :id AND seats_available >= :n` in the booking transaction; `bookings(rider_id, idempotency_key)` unique constraint makes retries safe.
- **Realtime** — driver publishes location over WS; server writes to Redis geo set and fans out via Redis pub/sub so any instance can serve any subscriber. No polling, no per-ping Postgres writes.
- **Providers behind adapters** — maps (OSM/MapLibre default, Google switchable), SMS, storage: all config switches, not code changes.
- **Feature flags** — Phase 2–4 features (accept/decline, payments, fees) ship dark behind env flags (`src/config/config.ts`).
- **Phase 3 ready** — `organizations` table and `users.org_id` exist now; unused until B2B.

## Scale path

1. **Now (one corridor):** 1 backend instance + Supabase free tier + Upstash Redis. Cost ≈ $0.
2. **Growth:** N stateless replicas + managed Postgres with read replica; Redis holds hot paths (locations, sessions, rate limits). Queue workers (BullMQ) scale separately from the API.
3. **Later:** peel `tracking` (highest connection count) and `matching` (highest CPU) into services; partition rides by `city`. The module boundaries and Redis backplane make this a deployment change, not a rewrite.
