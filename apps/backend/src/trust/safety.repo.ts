import type { Pool } from "pg";

export interface SafetyEvent {
  id: string;
  userId: string;
  rideId: string | null;
  kind: "sos";
  lat: number | null;
  lng: number | null;
  createdAt: string;
}

export interface SafetyRepository {
  logSos(userId: string, rideId: string | null, lat: number | null, lng: number | null): Promise<SafetyEvent>;
}

const COLS = `id, user_id AS "userId", ride_id AS "rideId", kind, lat, lng, created_at AS "createdAt"`;

export class PgSafetyRepository implements SafetyRepository {
  constructor(private readonly pool: Pool) {}

  async logSos(userId: string, rideId: string | null, lat: number | null, lng: number | null): Promise<SafetyEvent> {
    const { rows } = await this.pool.query(
      `INSERT INTO safety_events (user_id, ride_id, lat, lng)
       VALUES ($1, $2, $3, $4) RETURNING ${COLS}`,
      [userId, rideId, lat, lng]
    );
    return rows[0];
  }
}

export class InMemorySafetyRepository implements SafetyRepository {
  readonly events: SafetyEvent[] = [];

  async logSos(userId: string, rideId: string | null, lat: number | null, lng: number | null): Promise<SafetyEvent> {
    const event: SafetyEvent = {
      id: `sos-${this.events.length + 1}`,
      userId,
      rideId,
      kind: "sos",
      lat,
      lng,
      createdAt: new Date().toISOString()
    };
    this.events.push(event);
    return event;
  }
}
