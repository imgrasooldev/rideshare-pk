import { BadRequestException, Inject, Injectable } from "@nestjs/common";
import type { Pool } from "pg";
import { PG_POOL } from "../shared/tokens.js";
import { COMMISSION_RATE } from "../shared/commission.js";

export interface WalletSummary {
  commissionRate: number;
  grossFares: number; // total cash fares from confirmed bookings on this driver's rides
  commissionAccrued: number; // platform's share of those fares
  settledTotal: number; // commission the driver has already paid back
  commissionOwed: number; // accrued − settled (what the driver still owes)
  cashKept: number; // driver's net after commission
}

export interface SettlementRecord {
  id: string;
  amount: number;
  method: string;
  reference: string | null;
  createdAt: string;
}

@Injectable()
export class WalletService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool | null) {}

  private empty(): WalletSummary {
    return {
      commissionRate: COMMISSION_RATE,
      grossFares: 0,
      commissionAccrued: 0,
      settledTotal: 0,
      commissionOwed: 0,
      cashKept: 0
    };
  }

  async summary(driverId: string): Promise<WalletSummary> {
    if (!this.pool) return this.empty();
    const fares = await this.pool.query(
      `SELECT COALESCE(SUM(b.seats * COALESCE(b.offered_price, r.price_per_seat)), 0)::int AS gross
       FROM bookings b JOIN rides r ON r.id = b.ride_id
       WHERE r.driver_id = $1 AND b.status IN ('confirmed', 'completed')`,
      [driverId]
    );
    const settled = await this.pool.query(
      `SELECT COALESCE(SUM(amount), 0)::int AS total FROM settlements WHERE driver_id = $1`,
      [driverId]
    );
    const grossFares = fares.rows[0].gross as number;
    const settledTotal = settled.rows[0].total as number;
    const commissionAccrued = Math.round(grossFares * COMMISSION_RATE);
    return {
      commissionRate: COMMISSION_RATE,
      grossFares,
      commissionAccrued,
      settledTotal,
      commissionOwed: Math.max(0, commissionAccrued - settledTotal),
      cashKept: grossFares - commissionAccrued
    };
  }

  async history(driverId: string, limit: number): Promise<SettlementRecord[]> {
    if (!this.pool) return [];
    const { rows } = await this.pool.query(
      `SELECT id, amount, method, reference, created_at AS "createdAt"
       FROM settlements WHERE driver_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [driverId, Math.min(Math.max(limit, 1), 100)]
    );
    return rows;
  }

  /** Record a driver settling (paying back) accrued commission. */
  async settle(driverId: string, amount: number, reference?: string): Promise<SettlementRecord> {
    if (!this.pool) throw new BadRequestException("Wallet unavailable");
    if (!Number.isInteger(amount) || amount <= 0) {
      throw new BadRequestException("Enter a valid amount");
    }
    const { commissionOwed } = await this.summary(driverId);
    if (amount > commissionOwed) {
      throw new BadRequestException(`You only owe Rs ${commissionOwed}`);
    }
    const { rows } = await this.pool.query(
      `INSERT INTO settlements (driver_id, amount, method, reference)
       VALUES ($1, $2, 'cash_deposit', $3)
       RETURNING id, amount, method, reference, created_at AS "createdAt"`,
      [driverId, amount, reference ?? null]
    );
    return rows[0];
  }
}
