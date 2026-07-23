import { BadRequestException, Inject, Injectable } from "@nestjs/common";
import type { Pool } from "pg";
import { PG_POOL } from "../shared/tokens.js";

/** Reward, in paisa, granted to the referrer for each successful signup. */
export const REFERRAL_REWARD_PAISA = 10_000; // Rs 100

export interface CreditEntry {
  id: string;
  amountPaisa: number;
  kind: string;
  reference: string | null;
  description: string | null;
  createdAt: string;
}

export interface CreditBalance {
  balancePaisa: number;
  balanceRupees: number;
}

const ENTRY_COLS = `id, amount_paisa AS "amountPaisa", kind,
  reference, description, created_at AS "createdAt"`;

@Injectable()
export class CreditsService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool | null) {}

  async balance(userId: string): Promise<CreditBalance> {
    if (!this.pool) return { balancePaisa: 0, balanceRupees: 0 };
    const { rows } = await this.pool.query<{ sum: string | null }>(
      `SELECT COALESCE(SUM(amount_paisa), 0)::bigint AS sum
         FROM credit_ledger WHERE user_id = $1`,
      [userId]
    );
    const paisa = Number(rows[0]?.sum ?? 0);
    return { balancePaisa: paisa, balanceRupees: paisa / 100 };
  }

  async ledger(userId: string, limit = 100): Promise<CreditEntry[]> {
    if (!this.pool) return [];
    const { rows } = await this.pool.query<CreditEntry>(
      `SELECT ${ENTRY_COLS} FROM credit_ledger
        WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [userId, limit]
    );
    return rows.map((r) => ({ ...r, amountPaisa: Number(r.amountPaisa) }));
  }

  /**
   * Append a signed entry. `reference` dedupes a source event — a repeat with
   * the same (user, kind, reference) is a no-op, so callers are idempotent.
   * Returns the entry, or null when it was a duplicate.
   */
  async post(
    userId: string,
    amountPaisa: number,
    kind: string,
    reference: string | null,
    description: string | null
  ): Promise<CreditEntry | null> {
    if (!this.pool) throw new BadRequestException("Unavailable");
    const { rows } = await this.pool.query<CreditEntry>(
      `INSERT INTO credit_ledger (user_id, amount_paisa, kind, reference, description)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (user_id, kind, reference) DO NOTHING
       RETURNING ${ENTRY_COLS}`,
      [userId, Math.round(amountPaisa), kind, reference, description]
    );
    const row = rows[0];
    return row ? { ...row, amountPaisa: Number(row.amountPaisa) } : null;
  }

  /**
   * Convert this user's referral signups into wallet credit. Idempotent: each
   * referred user can only ever mint one referral_credit entry (unique on the
   * referred id as reference), so re-running only credits new referrals.
   */
  async redeemReferrals(userId: string): Promise<CreditBalance & { credited: number }> {
    if (!this.pool) return { balancePaisa: 0, balanceRupees: 0, credited: 0 };
    const { rowCount } = await this.pool.query(
      `INSERT INTO credit_ledger (user_id, amount_paisa, kind, reference, description)
       SELECT r.referrer_id, $2, 'referral_credit', r.referred_id::text, 'Referral reward'
         FROM referrals r
        WHERE r.referrer_id = $1
       ON CONFLICT (user_id, kind, reference) DO NOTHING`,
      [userId, REFERRAL_REWARD_PAISA]
    );
    const bal = await this.balance(userId);
    return { ...bal, credited: rowCount ?? 0 };
  }
}
