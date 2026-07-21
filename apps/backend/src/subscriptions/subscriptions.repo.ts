import { ConflictException, NotFoundException } from "@nestjs/common";
import type { Pool } from "pg";

export type SubscriptionStatus = "active" | "cancelled" | "expired";

export interface SubscriptionRecord {
  id: string;
  riderId: string;
  rideId: string;
  seats: number;
  days: number[];
  pricePerMonth: number;
  status: SubscriptionStatus;
  startsOn: string;
  renewsOn: string;
  createdAt: string;
}

export interface SubscriptionWithRide extends SubscriptionRecord {
  ride: { originLabel: string; destLabel: string; departAt: string; pricePerSeat: number };
}

export interface SubscriptionRepository {
  create(
    riderId: string,
    rideId: string,
    seats: number,
    days: number[],
    pricePerMonth: number,
    renewsOn: string
  ): Promise<SubscriptionRecord>;
  listByRider(riderId: string): Promise<SubscriptionWithRide[]>;
  cancel(id: string, riderId: string): Promise<SubscriptionRecord>;
}

const COLS = `id, rider_id AS "riderId", ride_id AS "rideId", seats, days,
  price_per_month AS "pricePerMonth", status, starts_on AS "startsOn",
  renews_on AS "renewsOn", created_at AS "createdAt"`;

export class PgSubscriptionRepository implements SubscriptionRepository {
  constructor(private readonly pool: Pool) {}

  async create(riderId: string, rideId: string, seats: number, days: number[], pricePerMonth: number, renewsOn: string): Promise<SubscriptionRecord> {
    try {
      const { rows } = await this.pool.query(
        `INSERT INTO subscriptions (rider_id, ride_id, seats, days, price_per_month, renews_on)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING ${COLS}`,
        [riderId, rideId, seats, days, pricePerMonth, renewsOn]
      );
      return rows[0];
    } catch (err: unknown) {
      if ((err as { code?: string }).code === "23505") {
        throw new ConflictException("You already have an active subscription for this route");
      }
      throw err;
    }
  }

  async listByRider(riderId: string): Promise<SubscriptionWithRide[]> {
    const { rows } = await this.pool.query(
      `SELECT s.id, s.rider_id AS "riderId", s.ride_id AS "rideId", s.seats, s.days,
              s.price_per_month AS "pricePerMonth", s.status, s.starts_on AS "startsOn",
              s.renews_on AS "renewsOn", s.created_at AS "createdAt",
              r.origin_label AS "originLabel", r.dest_label AS "destLabel",
              r.depart_at AS "departAt", r.price_per_seat AS "pricePerSeat"
       FROM subscriptions s JOIN rides r ON r.id = s.ride_id
       WHERE s.rider_id = $1 ORDER BY s.created_at DESC`,
      [riderId]
    );
    return rows.map((r) => ({
      id: r.id,
      riderId: r.riderId,
      rideId: r.rideId,
      seats: r.seats,
      days: r.days,
      pricePerMonth: r.pricePerMonth,
      status: r.status,
      startsOn: r.startsOn,
      renewsOn: r.renewsOn,
      createdAt: r.createdAt,
      ride: {
        originLabel: r.originLabel,
        destLabel: r.destLabel,
        departAt: r.departAt,
        pricePerSeat: r.pricePerSeat
      }
    }));
  }

  async cancel(id: string, riderId: string): Promise<SubscriptionRecord> {
    const { rows } = await this.pool.query(
      `UPDATE subscriptions SET status = 'cancelled', updated_at = now()
       WHERE id = $1 AND rider_id = $2 AND status = 'active' RETURNING ${COLS}`,
      [id, riderId]
    );
    if (!rows[0]) throw new NotFoundException("Subscription not found or already ended");
    return rows[0];
  }
}

export class InMemorySubscriptionRepository implements SubscriptionRepository {
  private readonly items: SubscriptionWithRide[] = [];
  private seq = 0;

  async create(riderId: string, rideId: string, seats: number, days: number[], pricePerMonth: number, renewsOn: string): Promise<SubscriptionRecord> {
    if (this.items.some((s) => s.riderId === riderId && s.rideId === rideId && s.status === "active")) {
      throw new ConflictException("You already have an active subscription for this route");
    }
    const rec: SubscriptionWithRide = {
      id: `sub-${String(++this.seq).padStart(4, "0")}`,
      riderId,
      rideId,
      seats,
      days,
      pricePerMonth,
      status: "active",
      startsOn: new Date().toISOString().slice(0, 10),
      renewsOn,
      createdAt: new Date(Date.now() + this.seq).toISOString(),
      ride: { originLabel: "", destLabel: "", departAt: "", pricePerSeat: 0 }
    };
    this.items.unshift(rec);
    return rec;
  }

  async listByRider(riderId: string): Promise<SubscriptionWithRide[]> {
    return this.items.filter((s) => s.riderId === riderId);
  }

  async cancel(id: string, riderId: string): Promise<SubscriptionRecord> {
    const s = this.items.find((x) => x.id === id && x.riderId === riderId && x.status === "active");
    if (!s) throw new NotFoundException("Subscription not found or already ended");
    s.status = "cancelled";
    return s;
  }
}
