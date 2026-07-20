# API reference

Base URL: `https://rideshare-pk.fly.dev/api/v1` · JSON · `Authorization: Bearer <accessToken>` unless marked public. Errors: `{ error?, message, details? }`. List endpoints are keyset-paginated: pass back `nextCursor` as `?cursor=`.

## Auth (public)

| Endpoint | Body | Notes |
|---|---|---|
| `POST /auth/otp/request` | `{ phone }` | PK mobiles only; 3/h per phone; dev mode returns `devCode` |
| `POST /auth/otp/verify` | `{ phone, code }` | → `{ accessToken, refreshToken, user }`; creates account on first login |
| `POST /auth/register` | `{ name?, email, password }` | 409 if email exists; password ≥ 8 |
| `POST /auth/login` | `{ email, password }` | 5 attempts / 15 min |
| `POST /auth/password/forgot` | `{ email }` | always 200; dev mode returns `devResetToken` |
| `POST /auth/password/reset` | `{ token, password }` | token single-use, 30 min |
| `POST /auth/refresh` | `{ refreshToken }` | rotation — each refresh token is single-use |
| `POST /auth/oauth/google` | `{ idToken }` | 503 until `GOOGLE_CLIENT_ID` configured |
| `POST /auth/oauth/facebook` | `{ accessToken }` | 503 until FB app configured |

## Profile & vehicles

| Endpoint | Notes |
|---|---|
| `GET /me` | profile incl. `cnicMasked`, `ratingAvg/Count`, `emergencyPhone` |
| `PATCH /me` | `{ name?, role?, gender?, cnic?, emergencyPhone? }` — CNIC stored encrypted |
| `POST /vehicles` | `{ vehicleType: car\|bike\|hiace\|minivan, make, model, plate, seats, docUrls }` |
| `GET /vehicles/mine` | |

## Rides & bookings

| Endpoint | Notes |
|---|---|
| `POST /rides` | origin/dest labels+coords, `departAt`, `recurringDays[]`, `seatsTotal`, `pricePerSeat`, `vehicleType`, `ladiesOnly` — driver must be verified (config), bike max 1 seat, ladies-only ⇒ female driver. `paymentMethod` always `cash`. |
| `GET /rides/search` | `pickupLat/Lng, dropLat/Lng, radiusKm≤25, departAfter/Before, ladiesOnly?, vehicleType?, cursor?` — both endpoints within radius |
| `GET /rides/mine` | driver's rides |
| `GET /rides/:id` | |
| `POST /bookings` | `{ rideId, seats, idempotencyKey }` — race-safe; replay with same key returns original; 409 when full |
| `GET /bookings/mine` | includes ride summary |
| `POST /bookings/:id/cancel` | restores seats, reopens full rides |

## Trips (live tracking)

| Endpoint | Notes |
|---|---|
| `POST /trips/:rideId/start` | driver only; returns `shareToken`; idempotent while live |
| `POST /trips/:rideId/location` | `{ lat, lng }` — throttled 1/3s; KV only |
| `GET /trips/:rideId/location` | poll fallback: `{ trip, location }` |
| `POST /trips/:rideId/end` | clears location, notifies subscribers |
| `GET /trips/shared/:token` | **public** family link: status + labels + live location |

WebSocket: `io('<origin>/trips', { auth: { token, rideId } })` — receive `location {lat,lng,at}` and `ended`; driver may emit `location`.

## Ratings & safety

| Endpoint | Notes |
|---|---|
| `POST /ratings` | `{ rideId, toUserId, stars 1-5, comment? }` — participants only, once per pair per ride (409 on repeat); updates target's aggregate transactionally |
| `POST /safety/sos` | `{ rideId?, lat?, lng? }` — durable log; reports whether emergency contact on file |
| `GET /verifications/mine` | own submissions |
| `POST /verifications` | `{ type: cnic\|license\|vehicle, docUrl, vehicleId? }` |

## Admin (AdminGuard — `users.is_admin`)

| Endpoint | Notes |
|---|---|
| `GET /admin/metrics` | totals, fill rate, pending verifications, SOS count |
| `GET /admin/timeseries?days=7..90` | daily signups/rides/bookings |
| `GET /admin/users` · `GET /admin/rides` | recent activity |
| `GET /admin/verifications` | pending queue (cursor) |
| `POST /admin/verifications/:id` | `{ action: approve\|reject, notes? }` — single review; approve flips trust flags |

## Health (public, unprefixed)

`GET /health` (liveness) · `GET /health/ready` (DB + KV probes → `ready|degraded`)
