# Architecture

## Shape

One deployable **modular monolith** (NestJS) + a Flutter app + a statically-exported Next.js admin console + Postgres/PostGIS + Redis. API instances are stateless; all shared state lives in Postgres/Redis so replicas scale horizontally behind Fly's proxy.

```
Flutter app ──REST/WS──▶ ┌────────────────────────────┐      ┌────────────┐
Admin console ──REST───▶ │  NestJS API (N replicas)   │─────▶│ Postgres + │
Family share link ─────▶ │  /api/v1 · /trips · /admin │      │  PostGIS   │
                         └─────────────┬──────────────┘      └────────────┘
                                       │ KeyValueStore · MessageBus
                                       ▼
                                 Redis (KV + pub/sub)
```

## Backend module map

Modules talk only through **exported service interfaces** — never each other's tables — so any module can be peeled into its own service without a rewrite.

| Module | Owns | Key invariants |
|---|---|---|
| `auth` | phone OTP, email/password, social identities, JWT | OTP: 3 sends/h, 5 verify attempts, single-use, HMAC at rest. Refresh tokens rotate (single-use jti in KV). Login rate-limited. Reset tokens 30-min single-use. OAuth verifiers config-gated. |
| `users` | profiles, CNIC (AES-256-GCM at rest, masked in API), emergency contact, rating aggregates | phone nullable (email/social accounts); email unique case-insensitive |
| `vehicles` | car/bike/hiace/minivan records + docs | |
| `rides` | posting + geo search | Search = `ST_DWithin` on origin **and** dest geographies + `depart_at` window, keyset-paginated; **index-backed** (GiST ×2 + btree — proven by `explain-search.mjs`). Verified-driver gate; bike = 1 seat; ladies-only ⇒ female driver; `payment_method='cash'`. |
| `bookings` | seat reservation | Conditional `UPDATE … WHERE seats_available >= n` in the same txn as the insert (no overbooking, race-proven); idempotency key per (rider, key); cancel restores seats. |
| `tracking` | trips + live location | WS `/trips` (auth via handshake); locations → KV with 90s TTL, throttled 1/3s, **never Postgres**; fan-out via `MessageBus`; public share token per trip; one live trip per ride (partial unique index). |
| `ratings` | two-way ratings | participants only; one per (ride, from, to); insert + aggregate update in one txn |
| `trust` | verification queue, admin console APIs, safety | approval flips user/vehicle verified flags; `/safety/sos` durable log; `/admin/metrics·users·rides·timeseries` behind DB-checked AdminGuard |
| `infra` | DI wiring | Real drivers when `DATABASE_URL`/`REDIS_URL` set; in-memory fallbacks for zero-infra dev — same interfaces either way |

## Frontends

- **apps/mobile** — Flutter, strict BLoC + repository layering: `core/` (dio ApiClient with single-flight refresh rotation, token storage, theme tokens) and `features/<name>/{data,bloc,presentation}`. GPS with demo-route fallback for the driver's live trip. All colors/typography flow from `core/theme/app_theme.dart`.
- **apps/admin** — Next.js static export served by the API at `/admin`. Auth redirects use hard navigation (static-export router quirk). Brand: jet-black + signal orange; success states stay semantic green.

## Scale path

1. **Now** (one corridor): 1 Fly machine + Supabase free tier ≈ $0/mo. In-memory KV/bus are fine on one instance.
2. **Provision Redis** (`flyctl redis create`, set `REDIS_URL`): OTPs/sessions/locations survive restarts; pub/sub crosses instances → `flyctl scale count N` safely.
3. **Growth**: Postgres read replica; queue workers (BullMQ) for SMS/notifications; dedicated IPv4.
4. **Later**: peel `tracking` (connection-heavy) and `matching` (CPU-heavy) into services; partition rides by `city`. The interfaces above make that a deployment change, not a rewrite.

## Deliberate deferrals

Payments (schema carries `payment_method` CHECK ready to grow), SMS delivery (adapter interface exists; dev mode returns codes), doc uploads to object storage (URLs accepted today), CI (GitHub Actions blocked account-side; quality gates run locally pre-push).
