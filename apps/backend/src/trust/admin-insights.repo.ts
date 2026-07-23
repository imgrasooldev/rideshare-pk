import { BadRequestException } from "@nestjs/common";
import type { Pool } from "pg";
import { COMMISSION_RATE } from "../shared/commission.js";

export interface RevenueSummary {
  commissionRate: number;
  grossFares: number; // all confirmed+completed fares across the marketplace (PKR)
  commissionAccrued: number; // platform's 10% share of those fares
  commissionCollected: number; // settlements paid back to date
  commissionOutstanding: number; // Σ per-driver owed (each floored at 0)
  collectedThisMonth: number;
  driversOwing: number; // how many drivers still owe something
}

export interface DriverSettlementRow {
  driverId: string;
  name: string | null;
  phone: string | null;
  grossFares: number;
  commissionAccrued: number;
  collected: number;
  owed: number;
  lastSettledAt: string | null;
}

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

export interface DayPoint {
  day: string; // YYYY-MM-DD
  signups: number;
  rides: number;
  bookings: number;
}

/** Read-only oversight queries for the admin console (PG-backed). */
export interface AdminInsightsRepository {
  metrics(): Promise<MarketplaceMetrics>;
  recentUsers(limit: number): Promise<AdminUserRow[]>;
  recentRides(limit: number): Promise<AdminRideRow[]>;
  timeseries(days: number): Promise<DayPoint[]>;
  revenue(): Promise<RevenueSummary>;
  driverSettlements(limit: number): Promise<DriverSettlementRow[]>;
  /** Admin records a cash commission collection from a driver (capped to owed). */
  recordCollection(
    driverId: string,
    amount: number,
    reference: string | null
  ): Promise<{ collected: number; owed: number }>;
}

// Shared SQL fragment: gross confirmed/completed fares per driver.
const FARES_CTE = `fares AS (
  SELECT r.driver_id,
    COALESCE(SUM(b.seats * COALESCE(b.offered_price, r.price_per_seat)), 0)::int AS gross
  FROM rides r JOIN bookings b ON b.ride_id = r.id
  WHERE b.status IN ('confirmed', 'completed')
  GROUP BY r.driver_id
)`;

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

  async timeseries(days: number): Promise<DayPoint[]> {
    const { rows } = await this.pool.query(
      `WITH days AS (
         SELECT generate_series(current_date - ($1::int - 1) * interval '1 day',
                                current_date, interval '1 day')::date AS day
       )
       SELECT to_char(day, 'YYYY-MM-DD') AS day,
         (SELECT count(*)::int FROM users    WHERE created_at::date = day AND deleted_at IS NULL) AS signups,
         (SELECT count(*)::int FROM rides    WHERE created_at::date = day)                        AS rides,
         (SELECT count(*)::int FROM bookings WHERE created_at::date = day)                        AS bookings
       FROM days ORDER BY day`,
      [days]
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

  async revenue(): Promise<RevenueSummary> {
    const { rows } = await this.pool.query(
      `WITH ${FARES_CTE},
       paid AS (
         SELECT driver_id, COALESCE(SUM(amount), 0)::int AS collected
         FROM settlements GROUP BY driver_id
       )
       SELECT
         COALESCE(SUM(f.gross), 0)::int                                   AS "grossFares",
         COALESCE(SUM(ROUND(f.gross * $1::numeric)), 0)::int                        AS "commissionAccrued",
         (SELECT COALESCE(SUM(amount), 0)::int FROM settlements)           AS "commissionCollected",
         COALESCE(SUM(GREATEST(0, ROUND(f.gross * $1::numeric)::int - COALESCE(p.collected, 0))), 0)::int
                                                                          AS "commissionOutstanding",
         (SELECT COALESCE(SUM(amount), 0)::int FROM settlements
            WHERE created_at >= date_trunc('month', now()))               AS "collectedThisMonth",
         COUNT(*) FILTER (
           WHERE ROUND(f.gross * $1::numeric)::int - COALESCE(p.collected, 0) > 0
         )::int                                                           AS "driversOwing"
       FROM fares f LEFT JOIN paid p ON p.driver_id = f.driver_id`,
      [COMMISSION_RATE]
    );
    return { commissionRate: COMMISSION_RATE, ...rows[0] };
  }

  async driverSettlements(limit: number): Promise<DriverSettlementRow[]> {
    const { rows } = await this.pool.query(
      `WITH ${FARES_CTE},
       paid AS (
         SELECT driver_id, COALESCE(SUM(amount), 0)::int AS collected, MAX(created_at) AS last_at
         FROM settlements GROUP BY driver_id
       )
       SELECT u.id AS "driverId", u.name, u.phone,
         COALESCE(f.gross, 0)                                            AS "grossFares",
         ROUND(COALESCE(f.gross, 0) * $1::numeric)::int                           AS "commissionAccrued",
         COALESCE(p.collected, 0)                                        AS "collected",
         GREATEST(0, ROUND(COALESCE(f.gross, 0) * $1::numeric)::int - COALESCE(p.collected, 0)) AS "owed",
         p.last_at AS "lastSettledAt"
       FROM users u
       LEFT JOIN fares f ON f.driver_id = u.id
       LEFT JOIN paid  p ON p.driver_id = u.id
       WHERE u.role IN ('driver', 'both') AND u.deleted_at IS NULL
         AND (COALESCE(f.gross, 0) > 0 OR COALESCE(p.collected, 0) > 0)
       ORDER BY "owed" DESC, "grossFares" DESC
       LIMIT $2`,
      [COMMISSION_RATE, limit]
    );
    return rows;
  }

  async recordCollection(
    driverId: string,
    amount: number,
    reference: string | null
  ): Promise<{ collected: number; owed: number }> {
    if (!Number.isInteger(amount) || amount <= 0) {
      throw new BadRequestException("Enter a valid amount");
    }
    // Compute what this driver owes right now, in one round-trip.
    const owedRes = await this.pool.query<{ owed: number; collected: number }>(
      `WITH ${FARES_CTE}
       SELECT GREATEST(0, ROUND(COALESCE((SELECT gross FROM fares WHERE driver_id = $1), 0) * $2::numeric)::int
                - COALESCE((SELECT SUM(amount)::int FROM settlements WHERE driver_id = $1), 0)) AS owed,
              COALESCE((SELECT SUM(amount)::int FROM settlements WHERE driver_id = $1), 0) AS collected`,
      [driverId, COMMISSION_RATE]
    );
    const owed = owedRes.rows[0]?.owed ?? 0;
    if (amount > owed) {
      throw new BadRequestException(`Driver only owes Rs ${owed}`);
    }
    await this.pool.query(
      `INSERT INTO settlements (driver_id, amount, method, reference)
       VALUES ($1, $2, 'cash_deposit', $3)`,
      [driverId, amount, reference]
    );
    const collected = (owedRes.rows[0]?.collected ?? 0) + amount;
    return { collected, owed: owed - amount };
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

  async timeseries(): Promise<DayPoint[]> {
    return [];
  }

  async revenue(): Promise<RevenueSummary> {
    return {
      commissionRate: COMMISSION_RATE,
      grossFares: 0,
      commissionAccrued: 0,
      commissionCollected: 0,
      commissionOutstanding: 0,
      collectedThisMonth: 0,
      driversOwing: 0
    };
  }

  async driverSettlements(): Promise<DriverSettlementRow[]> {
    return [];
  }

  async recordCollection(): Promise<{ collected: number; owed: number }> {
    throw new BadRequestException("Settlements unavailable");
  }
}
