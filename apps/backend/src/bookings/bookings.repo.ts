import { randomInt } from "node:crypto";
import { ConflictException, ForbiddenException, NotFoundException } from "@nestjs/common";
import type { Pool } from "pg";
import type { InMemoryRideRepository } from "../rides/rides.repo.js";

export type BookingStatus =
  | "requested"
  | "countered"
  | "confirmed"
  | "rejected"
  | "cancelled"
  | "completed"
  | "no_show";

export interface BookingRecord {
  id: string;
  rideId: string;
  riderId: string;
  seats: number;
  status: BookingStatus;
  offeredPrice: number | null; // driver's counter-offer price/seat, if any
  idempotencyKey: string;
  createdAt: string;
  /**
   * 4-digit pickup PIN. Populated on rider-facing reads ONLY — the driver
   * must ask the passenger for it out loud, so it is never selected on any
   * driver-facing query.
   */
  startPin?: string | null;
  pickedUpAt?: string | null;
}

export interface BookingWithRide extends BookingRecord {
  ride: { originLabel: string; destLabel: string; departAt: string; pricePerSeat: number };
}

/** A pending request as the driver sees it in their inbox. */
export interface DriverRequest extends BookingWithRide {
  riderName: string | null;
}

export interface BookingPage {
  items: BookingWithRide[];
  nextCursor: string | null;
}

export interface BookingRepository {
  /**
   * Create a booking REQUEST (status 'requested'). Requests hold no seats — a
   * ride only loses availability when the driver accepts. Idempotent on
   * (rider, idempotencyKey).
   */
  create(riderId: string, rideId: string, seats: number, idempotencyKey: string): Promise<BookingRecord>;
  /** Cancel own booking; restores seats only if it was confirmed. */
  cancel(bookingId: string, riderId: string, reason?: string): Promise<BookingRecord>;
  /** Driver marks a confirmed rider a no-show; frees the seat. */
  noShow(bookingId: string, driverId: string): Promise<BookingRecord>;
  /**
   * Driver enters the PIN the passenger reads out. Confirms the right person
   * is in the right car; wrong attempts are counted and eventually locked.
   */
  verifyStartPin(bookingId: string, driverId: string, pin: string): Promise<BookingRecord>;
  /** Confirmed passengers on a driver's ride (their manifest). */
  listForRide(rideId: string, driverId: string): Promise<DriverRequest[]>;
  /** Driver accepts a request → race-safe seat decrement + confirm. */
  accept(bookingId: string, driverId: string): Promise<BookingRecord>;
  /** Driver rejects a request. */
  reject(bookingId: string, driverId: string): Promise<BookingRecord>;
  /** Driver counter-offers a different price/seat. */
  counter(bookingId: string, driverId: string, offeredPrice: number): Promise<BookingRecord>;
  /** Rider accepts/declines a counter-offer. Accept → race-safe decrement + confirm. */
  respondToCounter(bookingId: string, riderId: string, accept: boolean): Promise<BookingRecord>;
  /** Open requests across a driver's rides (their dispatch inbox). */
  listRequestsForDriver(driverId: string, limit: number): Promise<DriverRequest[]>;
  listByRider(riderId: string, cursor: string | null, limit: number): Promise<BookingPage>;
  /** True when the rider holds a confirmed/completed booking on the ride. */
  hasBookingForRide(riderId: string, rideId: string): Promise<boolean>;
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

/** Cryptographically random 4-digit pickup PIN. */
function newStartPin(): string {
  return randomInt(0, 10_000).toString().padStart(4, "0");
}

/** Wrong PINs allowed before the code locks and must be regenerated. */
const MAX_PIN_ATTEMPTS = 5;

const B_COLS = `id, ride_id AS "rideId", rider_id AS "riderId", seats, status,
  offered_price AS "offeredPrice", idempotency_key AS "idempotencyKey", created_at AS "createdAt",
  picked_up_at AS "pickedUpAt"`;
// Same columns, table-qualified for UPDATE ... FROM rides joins.
const B_RET = `b.id, b.ride_id AS "rideId", b.rider_id AS "riderId", b.seats, b.status,
  b.offered_price AS "offeredPrice", b.idempotency_key AS "idempotencyKey", b.created_at AS "createdAt",
  b.picked_up_at AS "pickedUpAt"`;

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
    try {
      const { rows } = await this.pool.query(
        `INSERT INTO bookings (ride_id, rider_id, seats, status, idempotency_key)
         VALUES ($1, $2, $3, 'requested', $4) RETURNING ${B_COLS}`,
        [rideId, riderId, seats, idempotencyKey]
      );
      return rows[0];
    } catch (err: unknown) {
      if ((err as { code?: string }).code === "23505") {
        const replay = await this.findByKey(riderId, idempotencyKey);
        if (replay) return replay;
      }
      throw err;
    }
  }

  /** Shared race-safe decrement + confirm, run inside a transaction. */
  private async confirmWithSeats(
    bookingId: string,
    where: { driverId?: string; riderId?: string; statuses: BookingStatus[] }
  ): Promise<BookingRecord> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const sel = await client.query(
        `SELECT b.seats, b.ride_id, b.status, b.rider_id, r.driver_id
         FROM bookings b JOIN rides r ON r.id = b.ride_id
         WHERE b.id = $1 FOR UPDATE OF b`,
        [bookingId]
      );
      const row = sel.rows[0];
      if (!row) {
        await client.query("ROLLBACK");
        throw new NotFoundException("Request not found");
      }
      if (where.driverId && row.driver_id !== where.driverId) {
        await client.query("ROLLBACK");
        throw new ForbiddenException("Not your ride");
      }
      if (where.riderId && row.rider_id !== where.riderId) {
        await client.query("ROLLBACK");
        throw new ForbiddenException("Not your booking");
      }
      if (!where.statuses.includes(row.status)) {
        await client.query("ROLLBACK");
        throw new ConflictException("This request was already handled");
      }
      const dec = await client.query(
        `UPDATE rides SET seats_available = seats_available - $2,
           status = CASE WHEN seats_available - $2 = 0 THEN 'full' ELSE status END,
           updated_at = now()
         WHERE id = $1 AND status = 'open' AND seats_available >= $2
         RETURNING seats_available`,
        [row.ride_id, row.seats]
      );
      if (!dec.rows[0]) {
        await client.query("ROLLBACK");
        throw new ConflictException("Not enough seats left on this ride");
      }
      const upd = await client.query(
        `UPDATE bookings SET status = 'confirmed', responded_at = now(),
           start_pin = COALESCE(start_pin, $2), pin_attempts = 0, updated_at = now()
         WHERE id = $1 RETURNING ${B_COLS}, start_pin AS "startPin"`,
        [bookingId, newStartPin()]
      );
      await client.query("COMMIT");
      return upd.rows[0];
    } catch (err) {
      await client.query("ROLLBACK").catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }

  accept(bookingId: string, driverId: string): Promise<BookingRecord> {
    return this.confirmWithSeats(bookingId, { driverId, statuses: ["requested", "countered"] });
  }

  async reject(bookingId: string, driverId: string): Promise<BookingRecord> {
    const { rows } = await this.pool.query(
      `UPDATE bookings b SET status = 'rejected', responded_at = now(), updated_at = now()
       FROM rides r
       WHERE b.id = $1 AND r.id = b.ride_id AND r.driver_id = $2
         AND b.status IN ('requested', 'countered')
       RETURNING ${B_RET}`,
      [bookingId, driverId]
    );
    if (!rows[0]) throw new NotFoundException("Request not found, not yours, or already handled");
    return rows[0];
  }

  async counter(bookingId: string, driverId: string, offeredPrice: number): Promise<BookingRecord> {
    const { rows } = await this.pool.query(
      `UPDATE bookings b SET status = 'countered', offered_price = $3, updated_at = now()
       FROM rides r
       WHERE b.id = $1 AND r.id = b.ride_id AND r.driver_id = $2 AND b.status = 'requested'
       RETURNING ${B_RET}`,
      [bookingId, driverId, offeredPrice]
    );
    if (!rows[0]) throw new NotFoundException("Request not found, not yours, or already handled");
    return rows[0];
  }

  async respondToCounter(bookingId: string, riderId: string, accept: boolean): Promise<BookingRecord> {
    if (accept) {
      return this.confirmWithSeats(bookingId, { riderId, statuses: ["countered"] });
    }
    const { rows } = await this.pool.query(
      `UPDATE bookings SET status = 'cancelled', responded_at = now(), updated_at = now()
       WHERE id = $1 AND rider_id = $2 AND status = 'countered' RETURNING ${B_COLS}`,
      [bookingId, riderId]
    );
    if (!rows[0]) throw new NotFoundException("Counter-offer not found or already handled");
    return rows[0];
  }

  async cancel(bookingId: string, riderId: string, reason?: string): Promise<BookingRecord> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      // Lock the row and read the PRE-cancel status — only a confirmed booking
      // held a seat, so only it releases one back.
      const sel = await client.query(
        `SELECT status, ride_id, seats FROM bookings WHERE id = $1 AND rider_id = $2 FOR UPDATE`,
        [bookingId, riderId]
      );
      const cur = sel.rows[0];
      if (!cur || !["requested", "countered", "confirmed"].includes(cur.status)) {
        await client.query("ROLLBACK");
        throw new NotFoundException("Booking not found, not yours, or already finished");
      }
      const upd = await client.query(
        `UPDATE bookings SET status = 'cancelled', cancel_reason = $2, updated_at = now()
         WHERE id = $1 RETURNING ${B_COLS}`,
        [bookingId, reason ?? null]
      );
      if (cur.status === "confirmed") {
        await client.query(
          `UPDATE rides SET seats_available = seats_available + $2,
             status = CASE WHEN status = 'full' THEN 'open' ELSE status END,
             updated_at = now()
           WHERE id = $1`,
          [cur.ride_id, cur.seats]
        );
      }
      await client.query("COMMIT");
      return upd.rows[0];
    } catch (err) {
      await client.query("ROLLBACK").catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }

  async noShow(bookingId: string, driverId: string): Promise<BookingRecord> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const sel = await client.query(
        `SELECT b.status, b.ride_id, b.seats
         FROM bookings b JOIN rides r ON r.id = b.ride_id
         WHERE b.id = $1 AND r.driver_id = $2 FOR UPDATE OF b`,
        [bookingId, driverId]
      );
      const cur = sel.rows[0];
      if (!cur) {
        await client.query("ROLLBACK");
        throw new NotFoundException("Booking not found or not on your ride");
      }
      if (cur.status !== "confirmed") {
        await client.query("ROLLBACK");
        throw new ConflictException("Only a confirmed booking can be marked no-show");
      }
      const upd = await client.query(
        `UPDATE bookings SET status = 'no_show', updated_at = now() WHERE id = $1 RETURNING ${B_COLS}`,
        [bookingId]
      );
      await client.query(
        `UPDATE rides SET seats_available = seats_available + $2,
           status = CASE WHEN status = 'full' THEN 'open' ELSE status END, updated_at = now()
         WHERE id = $1`,
        [cur.ride_id, cur.seats]
      );
      await client.query("COMMIT");
      return upd.rows[0];
    } catch (err) {
      await client.query("ROLLBACK").catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }

  async verifyStartPin(bookingId: string, driverId: string, pin: string): Promise<BookingRecord> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      // Lock the row so parallel guesses cannot race past the attempt cap.
      const sel = await client.query(
        `SELECT b.status, b.start_pin, b.pin_attempts, b.picked_up_at
         FROM bookings b JOIN rides r ON r.id = b.ride_id
         WHERE b.id = $1 AND r.driver_id = $2 FOR UPDATE OF b`,
        [bookingId, driverId]
      );
      const cur = sel.rows[0];
      if (!cur) {
        await client.query("ROLLBACK");
        throw new NotFoundException("Booking not found or not on your ride");
      }
      if (cur.status !== "confirmed") {
        await client.query("ROLLBACK");
        throw new ConflictException("Only a confirmed booking can be picked up");
      }
      if (cur.picked_up_at) {
        await client.query("ROLLBACK");
        throw new ConflictException("This passenger is already picked up");
      }
      if (cur.pin_attempts >= MAX_PIN_ATTEMPTS) {
        await client.query("ROLLBACK");
        throw new ForbiddenException(
          "Too many incorrect PINs. Ask the passenger to refresh their code."
        );
      }
      if (cur.start_pin !== pin) {
        // Count the failure and commit it, so attempts survive the rejection.
        await client.query(
          `UPDATE bookings SET pin_attempts = pin_attempts + 1, updated_at = now() WHERE id = $1`,
          [bookingId]
        );
        await client.query("COMMIT");
        throw new ForbiddenException("Incorrect PIN — ask the passenger to read it again");
      }

      const upd = await client.query(
        `UPDATE bookings SET picked_up_at = now(), updated_at = now()
         WHERE id = $1 RETURNING ${B_COLS}`,
        [bookingId]
      );
      await client.query("COMMIT");
      return upd.rows[0];
    } catch (err) {
      await client.query("ROLLBACK").catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }

  async listForRide(rideId: string, driverId: string): Promise<DriverRequest[]> {
    // NOTE: start_pin is deliberately NOT selected — the driver must ask the
    // passenger for it, otherwise the check proves nothing.
    const { rows } = await this.pool.query(
      `SELECT b.id, b.ride_id AS "rideId", b.rider_id AS "riderId", b.seats, b.status,
              b.offered_price AS "offeredPrice", b.idempotency_key AS "idempotencyKey",
              b.created_at AS "createdAt", b.picked_up_at AS "pickedUpAt",
              r.origin_label AS "originLabel", r.dest_label AS "destLabel",
              r.depart_at AS "departAt", r.price_per_seat AS "pricePerSeat",
              u.name AS "riderName"
       FROM bookings b
       JOIN rides r ON r.id = b.ride_id
       JOIN users u ON u.id = b.rider_id
       WHERE b.ride_id = $1 AND r.driver_id = $2 AND b.status = 'confirmed'
       ORDER BY b.created_at`,
      [rideId, driverId]
    );
    return rows.map((r) => ({
      id: r.id,
      rideId: r.rideId,
      riderId: r.riderId,
      seats: r.seats,
      status: r.status,
      offeredPrice: r.offeredPrice,
      idempotencyKey: r.idempotencyKey,
      createdAt: r.createdAt,
      riderName: r.riderName,
      ride: {
        originLabel: r.originLabel,
        destLabel: r.destLabel,
        departAt: r.departAt,
        pricePerSeat: r.pricePerSeat
      }
    }));
  }

  async hasBookingForRide(riderId: string, rideId: string): Promise<boolean> {
    const { rows } = await this.pool.query(
      `SELECT 1 FROM bookings
       WHERE rider_id = $1 AND ride_id = $2 AND status IN ('confirmed','completed') LIMIT 1`,
      [riderId, rideId]
    );
    return rows.length > 0;
  }

  async listRequestsForDriver(driverId: string, limit: number): Promise<DriverRequest[]> {
    const { rows } = await this.pool.query(
      `SELECT b.id, b.ride_id AS "rideId", b.rider_id AS "riderId", b.seats, b.status,
              b.offered_price AS "offeredPrice", b.idempotency_key AS "idempotencyKey",
              b.created_at AS "createdAt",
              r.origin_label AS "originLabel", r.dest_label AS "destLabel",
              r.depart_at AS "departAt", r.price_per_seat AS "pricePerSeat",
              u.name AS "riderName"
       FROM bookings b
       JOIN rides r ON r.id = b.ride_id
       JOIN users u ON u.id = b.rider_id
       WHERE r.driver_id = $1 AND b.status IN ('requested', 'countered')
       ORDER BY b.created_at DESC LIMIT $2`,
      [driverId, Math.min(Math.max(limit, 1), 100)]
    );
    return rows.map((r) => ({
      id: r.id,
      rideId: r.rideId,
      riderId: r.riderId,
      seats: r.seats,
      status: r.status,
      offeredPrice: r.offeredPrice,
      idempotencyKey: r.idempotencyKey,
      createdAt: r.createdAt,
      riderName: r.riderName,
      ride: {
        originLabel: r.originLabel,
        destLabel: r.destLabel,
        departAt: r.departAt,
        pricePerSeat: r.pricePerSeat
      }
    }));
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
      // Rider-facing: this is the ONLY query that exposes start_pin.
      `SELECT b.id, b.ride_id AS "rideId", b.rider_id AS "riderId", b.seats, b.status,
              b.offered_price AS "offeredPrice", b.idempotency_key AS "idempotencyKey",
              b.created_at AS "createdAt", b.picked_up_at AS "pickedUpAt",
              b.start_pin AS "startPin",
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
      offeredPrice: r.offeredPrice,
      idempotencyKey: r.idempotencyKey,
      createdAt: r.createdAt,
      // Rider-only: their pickup PIN and whether the driver has confirmed it.
      startPin: r.startPin,
      pickedUpAt: r.pickedUpAt,
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

type InMemBooking = BookingRecord & {
  _ride: { originLabel: string; destLabel: string; departAt: string; pricePerSeat: number };
  _pinAttempts?: number;
};

export class InMemoryBookingRepository implements BookingRepository {
  private readonly items = new Map<string, InMemBooking>();
  private seq = 0;

  constructor(private readonly rides: InMemoryRideRepository) {}

  async create(riderId: string, rideId: string, seats: number, idempotencyKey: string): Promise<BookingRecord> {
    for (const b of this.items.values()) {
      if (b.riderId === riderId && b.idempotencyKey === idempotencyKey) return b;
    }
    const ride = await this.rides.findById(rideId);
    const rec: InMemBooking = {
      id: `bkg-${String(++this.seq).padStart(4, "0")}`,
      rideId,
      riderId,
      seats,
      status: "requested",
      offeredPrice: null,
      idempotencyKey,
      createdAt: new Date(Date.now() + this.seq).toISOString(),
      _ride: {
        originLabel: ride?.originLabel ?? "",
        destLabel: ride?.destLabel ?? "",
        departAt: ride?.departAt ?? new Date().toISOString(),
        pricePerSeat: ride?.pricePerSeat ?? 0
      }
    };
    this.items.set(rec.id, rec);
    return rec;
  }

  private async decrementOrThrow(rideId: string, seats: number): Promise<void> {
    const ride = await this.rides.findById(rideId);
    if (!ride || ride.status !== "open" || ride.seatsAvailable < seats) {
      throw new ConflictException("Not enough seats left on this ride");
    }
    ride.seatsAvailable -= seats;
    if (ride.seatsAvailable === 0) ride.status = "full";
  }

  async accept(bookingId: string, driverId: string): Promise<BookingRecord> {
    const b = this.items.get(bookingId);
    if (!b) throw new NotFoundException("Request not found");
    const ride = await this.rides.findById(b.rideId);
    if (!ride || ride.driverId !== driverId) throw new ForbiddenException("Not your ride");
    if (b.status !== "requested" && b.status !== "countered") {
      throw new ConflictException("This request was already handled");
    }
    await this.decrementOrThrow(b.rideId, b.seats);
    b.status = "confirmed";
    b.startPin ??= newStartPin();
    b._pinAttempts = 0;
    return b;
  }

  async reject(bookingId: string, driverId: string): Promise<BookingRecord> {
    const b = this.items.get(bookingId);
    const ride = b ? await this.rides.findById(b.rideId) : null;
    if (!b || !ride || ride.driverId !== driverId || (b.status !== "requested" && b.status !== "countered")) {
      throw new NotFoundException("Request not found, not yours, or already handled");
    }
    b.status = "rejected";
    return b;
  }

  async counter(bookingId: string, driverId: string, offeredPrice: number): Promise<BookingRecord> {
    const b = this.items.get(bookingId);
    const ride = b ? await this.rides.findById(b.rideId) : null;
    if (!b || !ride || ride.driverId !== driverId || b.status !== "requested") {
      throw new NotFoundException("Request not found, not yours, or already handled");
    }
    b.status = "countered";
    b.offeredPrice = offeredPrice;
    return b;
  }

  async respondToCounter(bookingId: string, riderId: string, accept: boolean): Promise<BookingRecord> {
    const b = this.items.get(bookingId);
    if (!b || b.riderId !== riderId || b.status !== "countered") {
      throw new NotFoundException("Counter-offer not found or already handled");
    }
    if (accept) {
      await this.decrementOrThrow(b.rideId, b.seats);
      b.status = "confirmed";
      b.startPin ??= newStartPin();
      b._pinAttempts = 0;
    } else {
      b.status = "cancelled";
    }
    return b;
  }

  async cancel(bookingId: string, riderId: string, _reason?: string): Promise<BookingRecord> {
    const b = this.items.get(bookingId);
    if (
      !b ||
      b.riderId !== riderId ||
      !["requested", "countered", "confirmed"].includes(b.status)
    ) {
      throw new NotFoundException("Booking not found, not yours, or already finished");
    }
    const wasConfirmed = b.status === "confirmed";
    b.status = "cancelled";
    if (wasConfirmed) {
      const ride = await this.rides.findById(b.rideId);
      if (ride) {
        ride.seatsAvailable += b.seats;
        if (ride.status === "full") ride.status = "open";
      }
    }
    return b;
  }

  async noShow(bookingId: string, driverId: string): Promise<BookingRecord> {
    const b = this.items.get(bookingId);
    const ride = b ? await this.rides.findById(b.rideId) : null;
    if (!b || !ride || ride.driverId !== driverId) {
      throw new NotFoundException("Booking not found or not on your ride");
    }
    if (b.status !== "confirmed") {
      throw new ConflictException("Only a confirmed booking can be marked no-show");
    }
    b.status = "no_show";
    ride.seatsAvailable += b.seats;
    if (ride.status === "full") ride.status = "open";
    return b;
  }

  async verifyStartPin(bookingId: string, driverId: string, pin: string): Promise<BookingRecord> {
    const b = this.items.get(bookingId);
    const ride = b ? await this.rides.findById(b.rideId) : null;
    if (!b || !ride || ride.driverId !== driverId) {
      throw new NotFoundException("Booking not found or not on your ride");
    }
    if (b.status !== "confirmed") {
      throw new ConflictException("Only a confirmed booking can be picked up");
    }
    if (b.pickedUpAt) throw new ConflictException("This passenger is already picked up");
    if ((b._pinAttempts ?? 0) >= MAX_PIN_ATTEMPTS) {
      throw new ForbiddenException(
        "Too many incorrect PINs. Ask the passenger to refresh their code."
      );
    }
    if (b.startPin !== pin) {
      b._pinAttempts = (b._pinAttempts ?? 0) + 1;
      throw new ForbiddenException("Incorrect PIN — ask the passenger to read it again");
    }
    b.pickedUpAt = new Date().toISOString();
    return b;
  }

  async listForRide(rideId: string, driverId: string): Promise<DriverRequest[]> {
    const out: DriverRequest[] = [];
    for (const b of this.items.values()) {
      if (b.rideId !== rideId || b.status !== "confirmed") continue;
      const ride = await this.rides.findById(b.rideId);
      if (!ride || ride.driverId !== driverId) continue;
      // Mirror the SQL: never hand the PIN to the driver.
      out.push({ ...b, startPin: undefined, ride: b._ride, riderName: null });
    }
    return out.sort((a, b) => a.createdAt.localeCompare(b.createdAt));
  }

  async hasBookingForRide(riderId: string, rideId: string): Promise<boolean> {
    for (const b of this.items.values()) {
      if (
        b.riderId === riderId &&
        b.rideId === rideId &&
        (b.status === "confirmed" || b.status === "completed")
      ) {
        return true;
      }
    }
    return false;
  }

  async listRequestsForDriver(driverId: string, limit: number): Promise<DriverRequest[]> {
    const out: DriverRequest[] = [];
    for (const b of this.items.values()) {
      if (b.status !== "requested" && b.status !== "countered") continue;
      const ride = await this.rides.findById(b.rideId);
      if (!ride || ride.driverId !== driverId) continue;
      out.push({ ...b, ride: b._ride, riderName: null });
    }
    return out
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .slice(0, limit);
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
