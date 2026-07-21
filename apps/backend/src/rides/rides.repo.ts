import type { Pool } from "pg";

export type RideStatus = "open" | "full" | "cancelled" | "completed";
export type Vertical =
  | "office" | "school" | "city" | "rentacar" | "ladies"
  | "parcel" | "corporate" | "airport" | "events";
export type RideVehicleType = "car" | "bike" | "hiace" | "minivan";

export interface RideRecord {
  id: string;
  driverId: string;
  vehicleId: string | null;
  originLabel: string;
  originLat: number;
  originLng: number;
  destLabel: string;
  destLat: number;
  destLng: number;
  departAt: string;
  recurringDays: number[];
  seatsTotal: number;
  seatsAvailable: number;
  pricePerSeat: number;
  vertical: Vertical;
  vehicleType: RideVehicleType;
  paymentMethod: "cash";
  ladiesOnly: boolean;
  status: RideStatus;
  city: string;
}

export interface NewRide {
  driverId: string;
  vehicleId: string | null;
  originLabel: string;
  originLat: number;
  originLng: number;
  destLabel: string;
  destLat: number;
  destLng: number;
  departAt: string;
  recurringDays: number[];
  seatsTotal: number;
  pricePerSeat: number;
  vertical: Vertical;
  vehicleType: RideVehicleType;
  ladiesOnly: boolean;
  city: string;
}

export interface RideSearch {
  pickupLat: number;
  pickupLng: number;
  dropLat: number;
  dropLng: number;
  radiusM: number;
  departAfter: string;
  departBefore: string;
  ladiesOnly?: boolean;
  vehicleType?: RideVehicleType;
  vertical?: Vertical;
  city?: string;
  cursor: string | null;
  limit: number;
}

export interface RidePage {
  items: RideRecord[];
  nextCursor: string | null;
}

export interface RideRepository {
  create(ride: NewRide): Promise<RideRecord>;
  findById(id: string): Promise<RideRecord | null>;
  /** Geo-corridor + time-window search. MUST be index-backed in SQL (rule 3). */
  search(params: RideSearch): Promise<RidePage>;
  /** Driver's own rides, newest departure first. */
  listByDriver(driverId: string, cursor: string | null, limit: number): Promise<RidePage>;
}

function encodeCursor(r: RideRecord): string {
  return Buffer.from(`${new Date(r.departAt).toISOString()}|${r.id}`).toString("base64url");
}

function decodeCursor(cursor: string): { departAt: string; id: string } | null {
  try {
    const [departAt, id] = Buffer.from(cursor, "base64url").toString("utf8").split("|");
    return departAt && id ? { departAt, id } : null;
  } catch {
    return null;
  }
}

const COLS = `id, driver_id AS "driverId", vehicle_id AS "vehicleId",
  origin_label AS "originLabel",
  ST_Y(origin_geo::geometry) AS "originLat", ST_X(origin_geo::geometry) AS "originLng",
  dest_label AS "destLabel",
  ST_Y(dest_geo::geometry) AS "destLat", ST_X(dest_geo::geometry) AS "destLng",
  depart_at AS "departAt", recurring_days AS "recurringDays",
  seats_total AS "seatsTotal", seats_available AS "seatsAvailable",
  price_per_seat AS "pricePerSeat", vertical, vehicle_type AS "vehicleType",
  payment_method AS "paymentMethod", ladies_only AS "ladiesOnly", status, city`;

export class PgRideRepository implements RideRepository {
  constructor(private readonly pool: Pool) {}

  async create(r: NewRide): Promise<RideRecord> {
    const { rows } = await this.pool.query(
      `INSERT INTO rides
         (driver_id, vehicle_id, origin_label, origin_geo, dest_label, dest_geo,
          depart_at, recurring_days, seats_total, seats_available, price_per_seat,
          vertical, vehicle_type, ladies_only, city)
       VALUES ($1, $2, $3,
          ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography,
          $6,
          ST_SetSRID(ST_MakePoint($7, $8), 4326)::geography,
          $9, $10, $11, $11, $12, $13, $14, $15, $16)
       RETURNING ${COLS}`,
      [
        r.driverId, r.vehicleId, r.originLabel, r.originLng, r.originLat,
        r.destLabel, r.destLng, r.destLat,
        r.departAt, r.recurringDays, r.seatsTotal, r.pricePerSeat,
        r.vertical, r.vehicleType, r.ladiesOnly, r.city
      ]
    );
    return rows[0];
  }

  async findById(id: string): Promise<RideRecord | null> {
    const { rows } = await this.pool.query(`SELECT ${COLS} FROM rides WHERE id = $1`, [id]);
    return rows[0] ?? null;
  }

  async search(p: RideSearch): Promise<RidePage> {
    // Index-backed: GiST on origin_geo/dest_geo drives ST_DWithin; btree on
    // depart_at bounds the window. Keyset pagination on (depart_at, id).
    const after = p.cursor ? decodeCursor(p.cursor) : null;
    const params: unknown[] = [
      p.pickupLng, p.pickupLat, p.dropLng, p.dropLat, p.radiusM,
      p.departAfter, p.departBefore, p.limit + 1
    ];
    let sql = `
      SELECT ${COLS} FROM rides
      WHERE status = 'open'
        AND seats_available > 0
        AND depart_at BETWEEN $6 AND $7
        AND ST_DWithin(origin_geo, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $5)
        AND ST_DWithin(dest_geo,   ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography, $5)`;
    if (p.ladiesOnly !== undefined) {
      params.push(p.ladiesOnly);
      sql += ` AND ladies_only = $${params.length}`;
    }
    if (p.vehicleType) {
      params.push(p.vehicleType);
      sql += ` AND vehicle_type = $${params.length}`;
    }
    if (p.vertical) {
      params.push(p.vertical);
      sql += ` AND vertical = $${params.length}`;
    }
    if (p.city) {
      params.push(p.city);
      sql += ` AND city = $${params.length}`;
    }
    if (after) {
      params.push(after.departAt, after.id);
      sql += ` AND (depart_at, id) > ($${params.length - 1}::timestamptz, $${params.length}::uuid)`;
    }
    sql += ` ORDER BY depart_at, id LIMIT $8`;

    const { rows } = await this.pool.query(sql, params);
    const items = rows.slice(0, p.limit);
    const nextCursor = rows.length > p.limit ? encodeCursor(items[items.length - 1]) : null;
    return { items, nextCursor };
  }

  async listByDriver(driverId: string, cursor: string | null, limit: number): Promise<RidePage> {
    const after = cursor ? decodeCursor(cursor) : null;
    const params: unknown[] = [driverId, limit + 1];
    let where = `driver_id = $1`;
    if (after) {
      params.push(after.departAt, after.id);
      where += ` AND (depart_at, id) < ($3::timestamptz, $4::uuid)`;
    }
    const { rows } = await this.pool.query(
      `SELECT ${COLS} FROM rides WHERE ${where} ORDER BY depart_at DESC, id DESC LIMIT $2`,
      params
    );
    const items = rows.slice(0, limit);
    const nextCursor = rows.length > limit ? encodeCursor(items[items.length - 1]) : null;
    return { items, nextCursor };
  }
}

/** Haversine metres — mirrors ST_DWithin semantics closely enough for dev. */
export function distanceM(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export class InMemoryRideRepository implements RideRepository {
  private readonly items = new Map<string, RideRecord>();
  private seq = 0;

  async create(r: NewRide): Promise<RideRecord> {
    const rec: RideRecord = {
      id: `ride-${String(++this.seq).padStart(4, "0")}`,
      status: "open",
      seatsAvailable: r.seatsTotal,
      paymentMethod: "cash",
      ...r
    };
    this.items.set(rec.id, rec);
    return rec;
  }

  async findById(id: string): Promise<RideRecord | null> {
    return this.items.get(id) ?? null;
  }

  async search(p: RideSearch): Promise<RidePage> {
    const after = p.cursor ? decodeCursor(p.cursor) : null;
    const all = [...this.items.values()]
      .filter(
        (r) =>
          r.status === "open" &&
          r.seatsAvailable > 0 &&
          r.departAt >= p.departAfter &&
          r.departAt <= p.departBefore &&
          distanceM(r.originLat, r.originLng, p.pickupLat, p.pickupLng) <= p.radiusM &&
          distanceM(r.destLat, r.destLng, p.dropLat, p.dropLng) <= p.radiusM &&
          (p.ladiesOnly === undefined || r.ladiesOnly === p.ladiesOnly) &&
          (!p.vehicleType || r.vehicleType === p.vehicleType) &&
          (!p.vertical || r.vertical === p.vertical) &&
          (!p.city || r.city === p.city)
      )
      .sort((a, b) => a.departAt.localeCompare(b.departAt) || a.id.localeCompare(b.id))
      .filter((r) => {
        if (!after) return true;
        const cmp = new Date(r.departAt).toISOString().localeCompare(after.departAt);
        return cmp > 0 || (cmp === 0 && r.id.localeCompare(after.id) > 0);
      });
    const items = all.slice(0, p.limit);
    const nextCursor = all.length > p.limit ? encodeCursor(items[items.length - 1]!) : null;
    return { items, nextCursor };
  }

  async listByDriver(driverId: string, cursor: string | null, limit: number): Promise<RidePage> {
    const after = cursor ? decodeCursor(cursor) : null;
    const all = [...this.items.values()]
      .filter((r) => r.driverId === driverId)
      .sort((a, b) => b.departAt.localeCompare(a.departAt) || b.id.localeCompare(a.id))
      .filter((r) => {
        if (!after) return true;
        const cmp = new Date(r.departAt).toISOString().localeCompare(after.departAt);
        return cmp < 0 || (cmp === 0 && r.id.localeCompare(after.id) < 0);
      });
    const items = all.slice(0, limit);
    const nextCursor = all.length > limit ? encodeCursor(items[items.length - 1]!) : null;
    return { items, nextCursor };
  }
}
