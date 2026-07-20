import type { Pool } from "pg";

export interface MarketplaceMetrics {
  totalUsers: number;
  verifiedUsers: number;
  drivers: number;
  totalRides: number;
  openRides: number;
  totalBookings: number;
  activeBookings: number;
  seatsOffered: number;
  seatsBooked: number;
  /** Booked seats / offered seats on open+full rides — the liquidity KPI. */
  fillRate: number;
  pendingVerifications: number;
  sosEvents: number;
}

export interface AdminUserRow {
  id: string;
  phone: string | null;
  email: string | null;
  name: string | null;
  role: string;
  verified: boolean;
  city: string;
  ratingAvg: number;
  createdAt: string;
}

export interface AdminRideRow {
  id: string;
  originLabel: string;
  destLabel: string;
  departAt: string;
  seatsTotal: number;
  seatsAvailable: number;
  pricePerSeat: number;
  vehicleType: string;
  status: string;
  driverPhone: string | null;
  driverName: string | null;
}

/** Read-only oversight queries for the admin console (PG-backed). */
export interface AdminInsightsRepository {
  metrics(): Promise<MarketplaceMetrics>;
  recentUsers(limit: number): Promise<AdminUserRow[]>;
  recentRides(limit: number): Promise<AdminRideRow[]>;
}

export class PgAdminInsightsRepository implements AdminInsightsRepository {
  constructor(private readonly pool: Pool) {}

  async metrics(): Promise<MarketplaceMetrics> {
    const { rows } = await this.pool.query(`
      SELECT
        (SELECT count(*) FROM users WHERE deleted_at IS NULL)::int                          AS "totalUsers",
        (SELECT count(*) FROM users WHERE verified AND deleted_at IS NULL)::int             AS "verifiedUsers",
        (SELECT count(*) FROM users WHERE role IN ('driver','both') AND deleted_at IS NULL)::int AS "drivers",
        (SELECT count(*) FROM rides)::int                                                   AS "totalRides",
        (SELECT count(*) FROM rides WHERE status = 'open')::int                             AS "openRides",
        (SELECT count(*) FROM bookings)::int                                                AS "totalBookings",
        (SELECT count(*) FROM bookings WHERE status = 'confirmed')::int                     AS "activeBookings",
        (SELECT coalesce(sum(seats_total), 0) FROM rides WHERE status IN ('open','full'))::int     AS "seatsOffered",
        (SELECT coalesce(sum(seats_total - seats_available), 0) FROM rides WHERE status IN ('open','full'))::int AS "seatsBooked",
        (SELECT count(*) FROM verifications WHERE status = 'pending')::int                  AS "pendingVerifications",
        (SELECT count(*) FROM safety_events)::int                                           AS "sosEvents"
    `);
    const m = rows[0];
    return {
      ...m,
      fillRate: m.seatsOffered > 0 ? Math.round((m.seatsBooked / m.seatsOffered) * 100) / 100 : 0
    };
  }

  async recentUsers(limit: number): Promise<AdminUserRow[]> {
    const { rows } = await this.pool.query(
      `SELECT id, phone, email, name, role, verified, city,
              rating_avg::float8 AS "ratingAvg", created_at AS "createdAt"
       FROM users WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT $1`,
      [limit]
    );
    return rows;
  }

  async recentRides(limit: number): Promise<AdminRideRow[]> {
    const { rows } = await this.pool.query(
      `SELECT r.id, r.origin_label AS "originLabel", r.dest_label AS "destLabel",
              r.depart_at AS "departAt", r.seats_total AS "seatsTotal",
              r.seats_available AS "seatsAvailable", r.price_per_seat AS "pricePerSeat",
              r.vehicle_type AS "vehicleType", r.status,
              u.phone AS "driverPhone", u.name AS "driverName"
       FROM rides r JOIN users u ON u.id = r.driver_id
       ORDER BY r.created_at DESC LIMIT $1`,
      [limit]
    );
    return rows;
  }
}

/** Dev fallback when no database is configured — console shows an empty state. */
export class StubAdminInsightsRepository implements AdminInsightsRepository {
  async metrics(): Promise<MarketplaceMetrics> {
    return {
      totalUsers: 0, verifiedUsers: 0, drivers: 0, totalRides: 0, openRides: 0,
      totalBookings: 0, activeBookings: 0, seatsOffered: 0, seatsBooked: 0,
      fillRate: 0, pendingVerifications: 0, sosEvents: 0
    };
  }

  async recentUsers(): Promise<AdminUserRow[]> {
    return [];
  }

  async recentRides(): Promise<AdminRideRow[]> {
    return [];
  }
}
