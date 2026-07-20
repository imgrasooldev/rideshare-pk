import { ConflictException, NotFoundException } from "@nestjs/common";
import type { Pool } from "pg";
import type { InMemoryRideRepository } from "../rides/rides.repo.js";

export type BookingStatus = "requested" | "confirmed" | "cancelled" | "completed";

export interface BookingRecord {
  id: string;
  rideId: string;
  riderId: string;
  seats: number;
  status: BookingStatus;
  idempotencyKey: string;
  createdAt: string;
}

export interface BookingWithRide extends BookingRecord {
  ride: { originLabel: string; destLabel: string; departAt: string; pricePerSeat: number };
}

export interface BookingPage {
  items: BookingWithRide[];
  nextCursor: string | null;
}

export interface BookingRepository {
  /**
   * Race-safe booking (rule 7): seat decrement is a single conditional UPDATE
   * in the same transaction as the booking insert — two riders can never both
   * take the last seat. Replays with the same (rider, idempotencyKey) return
   * the original booking without decrementing again.
   */
  create(riderId: string, rideId: string, seats: number, idempotencyKey: string): Promise<BookingRecord>;
  /** Cancel own booking; restores seats and reopens a full ride. */
  cancel(bookingId: string, riderId: string): Promise<BookingRecord>;
  listByRider(riderId: string, cursor: string | null, limit: number): Promise<BookingPage>;
}

function encodeCursor(b: BookingRecord): string {
  return Buffer.from(`${new Date(b.createdAt).toISOString()}|${b.id}`).toString("base64url");
}

function decodeCursor(cursor: string): { createdAt: string; id: string } | null {
  try {
    const [createdAt, id] = Buffer.from(cursor, "base64url").toString("utf8").split("|");
    return createdAt && id ? { createdAt, id } : null;
  } catch {
    return null;
  }
}

const B_COLS = `id, ride_id AS "rideId", rider_id AS "riderId", seats, status,
  idempotency_key AS "idempotencyKey", created_at AS "createdAt"`;

export class PgBookingRepository implements BookingRepository {
  constructor(private readonly pool: Pool) {}

  private async findByKey(riderId: string, key: string): Promise<BookingRecord | null> {
    const { rows } = await this.pool.query(
      `SELECT ${B_COLS} FROM bookings WHERE rider_id = $1 AND idempotency_key = $2`,
      [riderId, key]
    );
    return rows[0] ?? null;
  }

  async create(riderId: string, rideId: string, seats: number, idempotencyKey: string): Promise<BookingRecord> {
    const existing = await this.findByKey(riderId, idempotencyKey);
    if (existing) return existing;

    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");

      // The race-safe core: decrement only if enough seats remain.
      const upd = await client.query(
        `UPDATE rides SET seats_available = seats_available - $2, updated_at = now()
         WHERE id = $1 AND status = 'open' AND seats_available >= $2
         RETURNING seats_available`,
        [rideId, seats]
      );
      if (!upd.rows[0]) {
        await client.query("ROLLBACK");
        throw new ConflictException("Not enough seats available on this ride");
      }
      if (upd.rows[0].seats_available === 0) {
        await client.query(`UPDATE rides SET status = 'full', updated_at = now() WHERE id = $1`, [rideId]);
      }

      const ins = await client.query(
        `INSERT INTO bookings (ride_id, rider_id, seats, status, idempotency_key)
         VALUES ($1, $2, $3, 'confirmed', $4) RETURNING ${B_COLS}`,
        [rideId, riderId, seats, idempotencyKey]
      );
      await client.query("COMMIT");
      return ins.rows[0];
    } catch (err: unknown) {
      await client.query("ROLLBACK").catch(() => {});
      // Concurrent replay of the same idempotency key: unique violation —
      // the first attempt's booking is the answer.
      if ((err as { code?: string }).code === "23505") {
        const replay = await this.findByKey(riderId, idempotencyKey);
        if (replay) return replay;
      }
      throw err;
    } finally {
      client.release();
    }
  }

  async cancel(bookingId: string, riderId: string): Promise<BookingRecord> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const upd = await client.query(
        `UPDATE bookings SET status = 'cancelled', updated_at = now()
         WHERE id = $1 AND rider_id = $2 AND status IN ('requested', 'confirmed')
         RETURNING ${B_COLS}`,
        [bookingId, riderId]
      );
      if (!upd.rows[0]) {
        await client.query("ROLLBACK");
        throw new NotFoundException("Booking not found, not yours, or already finished");
      }
      const booking: BookingRecord = upd.rows[0];
      await client.query(
        `UPDATE rides SET seats_available = seats_available + $2,
           status = CASE WHEN status = 'full' THEN 'open' ELSE status END,
           updated_at = now()
         WHERE id = $1`,
        [booking.rideId, booking.seats]
      );
      await client.query("COMMIT");
      return booking;
    } catch (err) {
      await client.query("ROLLBACK").catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }

  async listByRider(riderId: string, cursor: string | null, limit: number): Promise<BookingPage> {
    const after = cursor ? decodeCursor(cursor) : null;
    const params: unknown[] = [riderId, limit + 1];
    let where = `b.rider_id = $1`;
    if (after) {
      params.push(after.createdAt, after.id);
      where += ` AND (b.created_at, b.id) < ($3::timestamptz, $4::uuid)`;
    }
    const { rows } = await this.pool.query(
      `SELECT b.id, b.ride_id AS "rideId", b.rider_id AS "riderId", b.seats, b.status,
              b.idempotency_key AS "idempotencyKey", b.created_at AS "createdAt",
              r.origin_label AS "originLabel", r.dest_label AS "destLabel",
              r.depart_at AS "departAt", r.price_per_seat AS "pricePerSeat"
       FROM bookings b JOIN rides r ON r.id = b.ride_id
       WHERE ${where}
       ORDER BY b.created_at DESC, b.id DESC LIMIT $2`,
      params
    );
    const items = rows.slice(0, limit).map((r) => ({
      id: r.id,
      rideId: r.rideId,
      riderId: r.riderId,
      seats: r.seats,
      status: r.status,
      idempotencyKey: r.idempotencyKey,
      createdAt: r.createdAt,
      ride: {
        originLabel: r.originLabel,
        destLabel: r.destLabel,
        departAt: r.departAt,
        pricePerSeat: r.pricePerSeat
      }
    }));
    const nextCursor = rows.length > limit ? encodeCursor(items[items.length - 1]!) : null;
    return { items, nextCursor };
  }
}

export class InMemoryBookingRepository implements BookingRepository {
  private readonly items = new Map<string, BookingRecord & { _ride: { originLabel: string; destLabel: string; departAt: string; pricePerSeat: number } }>();
  private seq = 0;

  constructor(private readonly rides: InMemoryRideRepository) {}

  async create(riderId: string, rideId: string, seats: number, idempotencyKey: string): Promise<BookingRecord> {
    for (const b of this.items.values()) {
      if (b.riderId === riderId && b.idempotencyKey === idempotencyKey) return b;
    }
    // Synchronous check-and-decrement mirrors the SQL conditional UPDATE's
    // atomicity (single-threaded event loop — no await between check and write).
    const ride = await this.rides.findById(rideId);
    if (!ride || ride.status !== "open" || ride.seatsAvailable < seats) {
      throw new ConflictException("Not enough seats available on this ride");
    }
    ride.seatsAvailable -= seats;
    if (ride.seatsAvailable === 0) ride.status = "full";

    const rec = {
      id: `bkg-${String(++this.seq).padStart(4, "0")}`,
      rideId,
      riderId,
      seats,
      status: "confirmed" as const,
      idempotencyKey,
      createdAt: new Date(Date.now() + this.seq).toISOString(),
      _ride: {
        originLabel: ride.originLabel,
        destLabel: ride.destLabel,
        departAt: ride.departAt,
        pricePerSeat: ride.pricePerSeat
      }
    };
    this.items.set(rec.id, rec);
    return rec;
  }

  async cancel(bookingId: string, riderId: string): Promise<BookingRecord> {
    const b = this.items.get(bookingId);
    if (!b || b.riderId !== riderId || (b.status !== "confirmed" && b.status !== "requested")) {
      throw new NotFoundException("Booking not found, not yours, or already finished");
    }
    b.status = "cancelled";
    const ride = await this.rides.findById(b.rideId);
    if (ride) {
      ride.seatsAvailable += b.seats;
      if (ride.status === "full") ride.status = "open";
    }
    return b;
  }

  async listByRider(riderId: string, cursor: string | null, limit: number): Promise<BookingPage> {
    const after = cursor ? decodeCursor(cursor) : null;
    const all = [...this.items.values()]
      .filter((b) => b.riderId === riderId)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt) || b.id.localeCompare(a.id))
      .filter((b) => {
        if (!after) return true;
        const cmp = new Date(b.createdAt).toISOString().localeCompare(after.createdAt);
        return cmp < 0 || (cmp === 0 && b.id.localeCompare(after.id) < 0);
      });
    const items = all.slice(0, limit).map((b) => ({ ...b, ride: b._ride }));
    const nextCursor = all.length > limit ? encodeCursor(items[items.length - 1]!) : null;
    return { items, nextCursor };
  }
}
