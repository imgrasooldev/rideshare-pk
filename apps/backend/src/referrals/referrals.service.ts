import { BadRequestException, Inject, Injectable, NotFoundException } from "@nestjs/common";
import type { Pool } from "pg";
import { PG_POOL } from "../shared/tokens.js";

export interface ReferralSummary {
  code: string;
  count: number; // how many users joined with my code
  referredBy: string | null; // code I used, if any
}

// Unambiguous alphabet (no 0/O/1/I) for shareable codes.
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

@Injectable()
export class ReferralsService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool | null) {}

  private codeFrom(userId: string): string {
    // Deterministic 6-char code from the user id — stable and collision-rare.
    let hash = 0;
    for (const ch of userId) hash = (hash * 31 + ch.charCodeAt(0)) >>> 0;
    let code = "";
    for (let i = 0; i < 6; i++) {
      code += ALPHABET[hash % ALPHABET.length];
      hash = Math.floor(hash / ALPHABET.length) + (i + 1) * 2654435761;
      hash >>>= 0;
    }
    return code;
  }

  /** Returns the user's code (assigning one on first call), their referral
   *  count, and the code they were referred by (if any). */
  async summary(userId: string): Promise<ReferralSummary> {
    if (!this.pool) return { code: this.codeFrom(userId), count: 0, referredBy: null };
    const existing = await this.pool.query<{ referral_code: string | null }>(
      `SELECT referral_code FROM users WHERE id = $1`,
      [userId]
    );
    let code = existing.rows[0]?.referral_code ?? null;
    if (!code) {
      code = this.codeFrom(userId);
      // Assign; retry with a random suffix on the rare unique collision.
      for (let attempt = 0; attempt < 5; attempt++) {
        try {
          await this.pool.query(`UPDATE users SET referral_code = $2 WHERE id = $1`, [userId, code]);
          break;
        } catch {
          code = this.codeFrom(userId + attempt) + ALPHABET[attempt];
        }
      }
    }
    const count = await this.pool.query<{ n: number }>(
      `SELECT COUNT(*)::int AS n FROM referrals WHERE referrer_id = $1`,
      [userId]
    );
    const referredBy = await this.pool.query<{ referral_code: string | null }>(
      `SELECT u.referral_code FROM referrals r JOIN users u ON u.id = r.referrer_id
       WHERE r.referred_id = $1`,
      [userId]
    );
    return {
      code: code!,
      count: count.rows[0]?.n ?? 0,
      referredBy: referredBy.rows[0]?.referral_code ?? null
    };
  }

  /** A new user credits the owner of `code` (once, not themselves). */
  async apply(userId: string, code: string): Promise<{ ok: true }> {
    if (!this.pool) return { ok: true };
    const clean = code.trim().toUpperCase();
    const owner = await this.pool.query<{ id: string }>(
      `SELECT id FROM users WHERE referral_code = $1`,
      [clean]
    );
    const ownerId = owner.rows[0]?.id;
    if (!ownerId) throw new NotFoundException("That referral code isn't valid");
    if (ownerId === userId) throw new BadRequestException("You can't use your own code");
    try {
      await this.pool.query(
        `INSERT INTO referrals (referrer_id, referred_id) VALUES ($1, $2)`,
        [ownerId, userId]
      );
    } catch {
      throw new BadRequestException("You've already used a referral code");
    }
    return { ok: true };
  }
}
