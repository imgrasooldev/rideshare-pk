import { Inject, Injectable } from "@nestjs/common";
import type { Pool } from "pg";
import { PG_POOL } from "../shared/tokens.js";
import { COMMISSION_RATE } from "../shared/commission.js";

export interface EarningsSummary {
  today: number;
  thisMonth: number;
  allTime: number;
  tripsThisMonth: number;
  activeSubscribers: number;
  monthlyRecurring: number;
  openRides: number;
  commissionRate: number;
  commissionThisMonth: number;
  netThisMonth: number;
  ratingAvg: number;
  ratingCount: number;
}

@Injectable()
export class EarningsService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool | null) {}

  async forDriver(driverId: string): Promise<EarningsSummary> {
    const empty: EarningsSummary = {
      today: 0, thisMonth: 0, allTime: 0, tripsThisMonth: 0, activeSubscribers: 0,
      monthlyRecurring: 0, openRides: 0, commissionRate: COMMISSION_RATE,
      commissionThisMonth: 0, netThisMonth: 0, ratingAvg: 0, ratingCount: 0
    };
    if (!this.pool) return empty;

    const fares = await this.pool.query(
      `SELECT
         COALESCE(SUM(b.seats * r.price_per_seat) FILTER (WHERE r.depart_at::date = current_date), 0)::int AS today,
         COALESCE(SUM(b.seats * r.price_per_seat) FILTER (WHERE r.depart_at >= date_trunc('month', now())), 0)::int AS month,
         COALESCE(SUM(b.seats * r.price_per_seat), 0)::int AS all_time,
         COUNT(*) FILTER (WHERE r.depart_at >= date_trunc('month', now()))::int AS trips_month
       FROM bookings b JOIN rides r ON r.id = b.ride_id
       WHERE r.driver_id = $1 AND b.status IN ('confirmed', 'completed')`,
      [driverId]
    );
    const subs = await this.pool.query(
      `SELECT COALESCE(SUM(s.price_per_month), 0)::int AS mrr, COUNT(*)::int AS active
       FROM subscriptions s JOIN rides r ON r.id = s.ride_id
       WHERE r.driver_id = $1 AND s.status = 'active'`,
      [driverId]
    );
    const meta = await this.pool.query(
      `SELECT u.rating_avg::float AS rating, u.rating_count::int AS rating_count,
              (SELECT COUNT(*) FROM rides WHERE driver_id = $1 AND status = 'open')::int AS open_rides
       FROM users u WHERE u.id = $1`,
      [driverId]
    );

    const thisMonth = fares.rows[0].month as number;
    const commission = Math.round(thisMonth * COMMISSION_RATE);
    return {
      today: fares.rows[0].today,
      thisMonth,
      allTime: fares.rows[0].all_time,
      tripsThisMonth: fares.rows[0].trips_month,
      activeSubscribers: subs.rows[0].active,
      monthlyRecurring: subs.rows[0].mrr,
      openRides: meta.rows[0]?.open_rides ?? 0,
      commissionRate: COMMISSION_RATE,
      commissionThisMonth: commission,
      netThisMonth: thisMonth - commission,
      ratingAvg: meta.rows[0]?.rating ?? 0,
      ratingCount: meta.rows[0]?.rating_count ?? 0
    };
  }
}
