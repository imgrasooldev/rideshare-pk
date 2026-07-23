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
  instantBook: boolean;
  status: RideStatus;
  city: string;
  /** Driver's cached rating aggregate (from users); absent on create(). */
  driverRatingAvg?: number;
  driverRatingCount?: number;
  driverName?: string | null;
  driverGender?: "female" | "male" | "other" | null;
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
  instantBook?: boolean;
  city: string;
  /**
   * Driving polyline as [lat, lng] pairs. Optional and best-effort: when the
   * router is unreachable the ride still posts and falls back to endpoint
   * matching. This is what makes along-the-route pickups possible.
   */
  routePoints?: Array<[number, number]>;
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
  driverGender?: "female" | "male" | "other";
  city?: string;
  /**
   * Also match rides whose stored route passes near BOTH points, even when the
   * driver's own origin/destination are far away — the core of carpooling.
   * Set false to restrict to endpoint matches only.
   */
  alongRoute?: boolean;
  /** Driver ids to hide (mutual blocks) — safety, applied before paging. */
  excludeDriverIds?: string[];
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
  /** Driver adjusts total seats; available/status recomputed off reserved seats. */
  updateSeats(rideId: string, driverId: string, seatsTotal: number): Promise<RideRecord | null>;
}

/**
 * GeoJSON LineString for PostGIS, or null when there is no usable route.
 * Input is [lat, lng]; GeoJSON is [lng, lat].
 */
function routeLineGeoJson(points?: Array<[number, number]>): string | null {
  if (!points || points.length < 2) return null;
  return JSON.stringify({
    type: "LineString",
    coordinates: points.map(([lat, lng]) => [lng, lat])
  });
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
  payment_method AS "paymentMethod", ladies_only AS "ladiesOnly", status, city,
  instant_book AS "instantBook"`;

// Same columns, table-qualified with `r`, plus the driver's rating aggregate
// via a join on users. Used by reads that surface the driver to riders.
const COLS_R = `r.id, r.driver_id AS "driverId", r.vehicle_id AS "vehicleId",
  r.origin_label AS "originLabel",
  ST_Y(r.origin_geo::geometry) AS "originLat", ST_X(r.origin_geo::geometry) AS "originLng",
  r.dest_label AS "destLabel",
  ST_Y(r.dest_geo::geometry) AS "destLat", ST_X(r.dest_geo::geometry) AS "destLng",
  r.depart_at AS "departAt", r.recurring_days AS "recurringDays",
  r.seats_total AS "seatsTotal", r.seats_available AS "seatsAvailable",
  r.price_per_seat AS "pricePerSeat", r.vertical, r.vehicle_type AS "vehicleType",
  r.payment_method AS "paymentMethod", r.ladies_only AS "ladiesOnly", r.status, r.city,
  COALESCE(u.rating_avg, 0)::float8 AS "driverRatingAvg",
  COALESCE(u.rating_count, 0) AS "driverRatingCount",
  u.name AS "driverName", u.gender AS "driverGender", r.instant_book AS "instantBook"`;

export class PgRideRepository implements RideRepository {
  constructor(private readonly pool: Pool) {}

  async create(r: NewRide): Promise<RideRecord> {
    const { rows } = await this.pool.query(
      `INSERT INTO rides
         (driver_id, vehicle_id, origin_label, origin_geo, dest_label, dest_geo,
          depart_at, recurring_days, seats_total, seats_available, price_per_seat,
          vertical, vehicle_type, ladies_only, city, route_line, instant_book)
       VALUES ($1, $2, $3,
          ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography,
          $6,
          ST_SetSRID(ST_MakePoint($7, $8), 4326)::geography,
          $9, $10, $11, $11, $12, $13, $14, $15, $16,
          CASE WHEN $17::jsonb IS NULL THEN NULL
               ELSE ST_SetSRID(ST_GeomFromGeoJSON($17::jsonb), 4326)::geography END,
          $18)
       RETURNING ${COLS}`,
      [
        r.driverId, r.vehicleId, r.originLabel, r.originLng, r.originLat,
        r.destLabel, r.destLng, r.destLat,
        r.departAt, r.recurringDays, r.seatsTotal, r.pricePerSeat,
        r.vertical, r.vehicleType, r.ladiesOnly, r.city,
        routeLineGeoJson(r.routePoints), r.instantBook ?? false
      ]
    );
    return rows[0];
  }

  async findById(id: string): Promise<RideRecord | null> {
    const { rows } = await this.pool.query(
      `SELECT ${COLS_R} FROM rides r LEFT JOIN users u ON u.id = r.driver_id WHERE r.id = $1`,
      [id]
    );
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
    // Endpoint match: the driver starts and ends near the rider (the classic
    // case). Corridor match: the rider joins somewhere ALONG the driver's
    // route — ST_LineLocatePoint gives each point's 0..1 position on the line,
    // and requiring pickup < drop rejects riders travelling the opposite way.
    // Both branches are GiST-index-backed (origin/dest_geo and route_line).
    const endpointMatch = `(
          ST_DWithin(r.origin_geo, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $5)
      AND ST_DWithin(r.dest_geo,   ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography, $5)
    )`;
    const corridorMatch = `(
          r.route_line IS NOT NULL
      AND ST_DWithin(r.route_line, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $5)
      AND ST_DWithin(r.route_line, ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography, $5)
      AND ST_LineLocatePoint(r.route_line::geometry, ST_SetSRID(ST_MakePoint($1, $2), 4326))
        < ST_LineLocatePoint(r.route_line::geometry, ST_SetSRID(ST_MakePoint($3, $4), 4326))
    )`;
    const geoMatch =
      p.alongRoute === false ? endpointMatch : `(${endpointMatch} OR ${corridorMatch})`;

    let sql = `
      SELECT ${COLS_R} FROM rides r LEFT JOIN users u ON u.id = r.driver_id
      WHERE r.status = 'open'
        AND r.seats_available > 0
        AND COALESCE(u.is_online, true) = true
        AND r.depart_at BETWEEN $6 AND $7
        AND ${geoMatch}`;
    if (p.ladiesOnly !== undefined) {
      params.push(p.ladiesOnly);
      sql += ` AND r.ladies_only = $${params.length}`;
    }
    if (p.excludeDriverIds?.length) {
      params.push(p.excludeDriverIds);
      sql += ` AND r.driver_id <> ALL($${params.length}::uuid[])`;
    }
    if (p.vehicleType) {
      params.push(p.vehicleType);
      sql += ` AND r.vehicle_type = $${params.length}`;
    }
    if (p.vertical) {
      params.push(p.vertical);
      sql += ` AND r.vertical = $${params.length}`;
    }
    if (p.driverGender) {
      params.push(p.driverGender);
      sql += ` AND u.gender = $${params.length}`;
    }
    if (p.city) {
      params.push(p.city);
      sql += ` AND r.city = $${params.length}`;
    }
    if (after) {
      params.push(after.departAt, after.id);
      sql += ` AND (r.depart_at, r.id) > ($${params.length - 1}::timestamptz, $${params.length}::uuid)`;
    }
    sql += ` ORDER BY r.depart_at, r.id LIMIT $8`;

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

  async updateSeats(rideId: string, driverId: string, seatsTotal: number): Promise<RideRecord | null> {
    // reserved = old seats_total − old seats_available (RHS sees pre-update row).
    const { rows } = await this.pool.query(
      `UPDATE rides SET
         seats_total = $3,
         seats_available = GREATEST(0, $3 - (seats_total - seats_available)),
         status = CASE WHEN GREATEST(0, $3 - (seats_total - seats_available)) = 0
                       THEN 'full' ELSE 'open' END,
         updated_at = now()
       WHERE id = $1 AND driver_id = $2 AND status IN ('open', 'full')
       RETURNING ${COLS}`,
      [rideId, driverId, seatsTotal]
    );
    return rows[0] ?? null;
  }
}

/**
 * Distance from a point to a polyline, plus how far along that line the
 * closest position sits (0..1) — the in-memory stand-in for ST_DWithin +
 * ST_LineLocatePoint. Segments are short enough in a city that treating
 * lat/lng as planar (scaled for longitude) is accurate to a few metres.
 */
export function pointOnRoute(
  points: Array<[number, number]>,
  lat: number,
  lng: number
): { distanceM: number; position: number } {
  let best = { distanceM: Number.POSITIVE_INFINITY, position: 0 };
  const lengths: number[] = [];
  let total = 0;
  for (let i = 1; i < points.length; i++) {
    const seg = distanceM(points[i - 1]![0], points[i - 1]![1], points[i]![0], points[i]![1]);
    lengths.push(seg);
    total += seg;
  }

  let travelled = 0;
  for (let i = 1; i < points.length; i++) {
    const [aLat, aLng] = points[i - 1]!;
    const [bLat, bLng] = points[i]!;
    // Project onto the segment in a locally-planar frame.
    const scale = Math.cos((aLat * Math.PI) / 180);
    const ax = aLng * scale;
    const ay = aLat;
    const bx = bLng * scale;
    const by = bLat;
    const px = lng * scale;
    const py = lat;
    const dx = bx - ax;
    const dy = by - ay;
    const lenSq = dx * dx + dy * dy;
    const t = lenSq === 0 ? 0 : Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / lenSq));
    const closestLat = ay + t * dy;
    const closestLng = (ax + t * dx) / scale;
    const d = distanceM(lat, lng, closestLat, closestLng);
    if (d < best.distanceM) {
      best = {
        distanceM: d,
        position: total === 0 ? 0 : (travelled + lengths[i - 1]! * t) / total
      };
    }
    travelled += lengths[i - 1]!;
  }
  return best;
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

/** Mirrors the SQL geo predicate: endpoint match OR along-the-route match. */
function matchesGeo(r: RideRecord & { routePoints?: Array<[number, number]> }, p: RideSearch): boolean {
  const endpoint =
    distanceM(r.originLat, r.originLng, p.pickupLat, p.pickupLng) <= p.radiusM &&
    distanceM(r.destLat, r.destLng, p.dropLat, p.dropLng) <= p.radiusM;
  if (endpoint) return true;
  if (p.alongRoute === false) return false;

  const route = r.routePoints;
  if (!route || route.length < 2) return false;
  const pickup = pointOnRoute(route, p.pickupLat, p.pickupLng);
  const drop = pointOnRoute(route, p.dropLat, p.dropLng);
  return (
    pickup.distanceM <= p.radiusM &&
    drop.distanceM <= p.radiusM &&
    pickup.position < drop.position // same direction of travel
  );
}

export class InMemoryRideRepository implements RideRepository {
  private readonly items = new Map<string, RideRecord & { routePoints?: Array<[number, number]> }>();
  private seq = 0;

  async create(r: NewRide): Promise<RideRecord> {
    // routePoints is kept alongside the record so the in-memory search can
    // mirror the SQL corridor predicate; it is not part of the public record.
    const rec: RideRecord & { routePoints?: Array<[number, number]> } = {
      id: `ride-${String(++this.seq).padStart(4, "0")}`,
      status: "open",
      seatsAvailable: r.seatsTotal,
      paymentMethod: "cash",
      ...r,
      instantBook: r.instantBook ?? false,
      routePoints: r.routePoints
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
          matchesGeo(r, p) &&
          !(p.excludeDriverIds ?? []).includes(r.driverId) &&
          (p.ladiesOnly === undefined || r.ladiesOnly === p.ladiesOnly) &&
          (!p.vehicleType || r.vehicleType === p.vehicleType) &&
          (!p.vertical || r.vertical === p.vertical) &&
          (!p.driverGender || r.driverGender === p.driverGender) &&
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

  async updateSeats(rideId: string, driverId: string, seatsTotal: number): Promise<RideRecord | null> {
    const r = this.items.get(rideId);
    if (!r || r.driverId !== driverId || (r.status !== "open" && r.status !== "full")) return null;
    const reserved = r.seatsTotal - r.seatsAvailable;
    const available = Math.max(0, seatsTotal - reserved);
    r.seatsTotal = seatsTotal;
    r.seatsAvailable = available;
    r.status = available === 0 ? "full" : "open";
    return r;
  }
}
