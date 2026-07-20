import type { Pool } from "pg";

export interface TripRecord {
  id: string;
  rideId: string;
  startedAt: string | null;
  endedAt: string | null;
  liveStatus: "pending" | "live" | "ended";
  shareToken: string;
}

export interface TripRepository {
  /** Starts (or returns) the live trip for a ride — one live trip per ride. */
  start(rideId: string): Promise<TripRecord>;
  end(rideId: string): Promise<TripRecord | null>;
  findLiveByRide(rideId: string): Promise<TripRecord | null>;
  findByShareToken(token: string): Promise<TripRecord | null>;
}

const COLS = `id, ride_id AS "rideId", started_at AS "startedAt", ended_at AS "endedAt",
  live_status AS "liveStatus", share_token AS "shareToken"`;

export class PgTripRepository implements TripRepository {
  constructor(private readonly pool: Pool) {}

  async start(rideId: string): Promise<TripRecord> {
    const existing = await this.findLiveByRide(rideId);
    if (existing) return existing;
    const { rows } = await this.pool.query(
      `INSERT INTO trips (ride_id, started_at, live_status)
       VALUES ($1, now(), 'live') RETURNING ${COLS}`,
      [rideId]
    );
    return rows[0];
  }

  async end(rideId: string): Promise<TripRecord | null> {
    const { rows } = await this.pool.query(
      `UPDATE trips SET live_status = 'ended', ended_at = now(), updated_at = now()
       WHERE ride_id = $1 AND live_status = 'live' RETURNING ${COLS}`,
      [rideId]
    );
    return rows[0] ?? null;
  }

  async findLiveByRide(rideId: string): Promise<TripRecord | null> {
    const { rows } = await this.pool.query(
      `SELECT ${COLS} FROM trips WHERE ride_id = $1 AND live_status = 'live'`,
      [rideId]
    );
    return rows[0] ?? null;
  }

  async findByShareToken(token: string): Promise<TripRecord | null> {
    const { rows } = await this.pool.query(
      `SELECT ${COLS} FROM trips WHERE share_token = $1`,
      [token]
    );
    return rows[0] ?? null;
  }
}

export class InMemoryTripRepository implements TripRepository {
  private readonly trips = new Map<string, TripRecord>();
  private seq = 0;

  async start(rideId: string): Promise<TripRecord> {
    const live = await this.findLiveByRide(rideId);
    if (live) return live;
    const trip: TripRecord = {
      id: `trip-${++this.seq}`,
      rideId,
      startedAt: new Date().toISOString(),
      endedAt: null,
      liveStatus: "live",
      shareToken: `share-${this.seq}-${Math.random().toString(36).slice(2, 10)}`
    };
    this.trips.set(trip.id, trip);
    return trip;
  }

  async end(rideId: string): Promise<TripRecord | null> {
    const live = await this.findLiveByRide(rideId);
    if (!live) return null;
    live.liveStatus = "ended";
    live.endedAt = new Date().toISOString();
    return live;
  }

  async findLiveByRide(rideId: string): Promise<TripRecord | null> {
    for (const t of this.trips.values()) {
      if (t.rideId === rideId && t.liveStatus === "live") return t;
    }
    return null;
  }

  async findByShareToken(token: string): Promise<TripRecord | null> {
    for (const t of this.trips.values()) if (t.shareToken === token) return t;
    return null;
  }
}
