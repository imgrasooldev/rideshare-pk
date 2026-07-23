import { BadRequestException, Inject, Injectable } from "@nestjs/common";
import type { Pool } from "pg";
import { PG_POOL } from "../shared/tokens.js";

export interface Dispute {
  id: string;
  bookingId: string | null;
  userId: string;
  /** The person being reported, when the complaint is about someone. */
  reportedUserId: string | null;
  category: string;
  message: string;
  status: "open" | "resolved" | "dismissed";
  resolution: string | null;
  createdAt: string;
}

/** A reported user with their complaint history — what an admin acts on. */
export interface ReportedUserSummary {
  userId: string;
  name: string | null;
  phone: string | null;
  reportCount: number;
  suspendedAt: string | null;
  lastReportedAt: string;
}

const COLS = `id, booking_id AS "bookingId", user_id AS "userId",
  reported_user_id AS "reportedUserId", category, message,
  status, resolution, created_at AS "createdAt"`;

@Injectable()
export class DisputesService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool | null) {}

  async file(
    userId: string,
    category: string,
    message: string,
    bookingId?: string,
    reportedUserId?: string
  ): Promise<Dispute> {
    if (!this.pool) throw new BadRequestException("Unavailable");
    if (reportedUserId && reportedUserId === userId) {
      throw new BadRequestException("You cannot report yourself");
    }
    const { rows } = await this.pool.query(
      `INSERT INTO disputes (booking_id, user_id, category, message, reported_user_id)
       VALUES ($1, $2, $3, $4, $5) RETURNING ${COLS}`,
      [bookingId ?? null, userId, category, message.trim(), reportedUserId ?? null]
    );
    return rows[0];
  }

  /**
   * Repeat-offender view: who is being reported, how often, and whether they
   * are already suspended. One complaint is noise; a pattern is a signal.
   */
  async reportedUsers(limit: number): Promise<ReportedUserSummary[]> {
    if (!this.pool) return [];
    const { rows } = await this.pool.query(
      `SELECT d.reported_user_id AS "userId", u.name, u.phone,
              count(*)::int AS "reportCount",
              u.suspended_at AS "suspendedAt",
              max(d.created_at) AS "lastReportedAt"
       FROM disputes d JOIN users u ON u.id = d.reported_user_id
       WHERE d.reported_user_id IS NOT NULL
       GROUP BY d.reported_user_id, u.name, u.phone, u.suspended_at
       ORDER BY count(*) DESC, max(d.created_at) DESC
       LIMIT $1`,
      [Math.min(Math.max(limit, 1), 200)]
    );
    return rows;
  }

  async mine(userId: string): Promise<Dispute[]> {
    if (!this.pool) return [];
    const { rows } = await this.pool.query(
      `SELECT ${COLS} FROM disputes WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50`,
      [userId]
    );
    return rows;
  }

  async listOpen(limit: number): Promise<Dispute[]> {
    if (!this.pool) return [];
    const { rows } = await this.pool.query(
      `SELECT ${COLS} FROM disputes WHERE status = 'open' ORDER BY created_at ASC LIMIT $1`,
      [Math.min(Math.max(limit, 1), 200)]
    );
    return rows;
  }

  /**
   * Suspend or restore an account. A suspended user cannot sign in, post a
   * ride, or book — enforced where the user record is already loaded, so no
   * extra database round-trip is added to every request.
   */
  async setSuspended(
    userId: string,
    suspended: boolean,
    reason?: string
  ): Promise<{ userId: string; suspendedAt: string | null }> {
    if (!this.pool) throw new BadRequestException("Unavailable");
    const { rows } = await this.pool.query(
      `UPDATE users
          SET suspended_at = CASE WHEN $2 THEN now() ELSE NULL END,
              suspension_reason = CASE WHEN $2 THEN $3 ELSE NULL END,
              updated_at = now()
        WHERE id = $1
        RETURNING id AS "userId", suspended_at AS "suspendedAt"`,
      [userId, suspended, reason ?? null]
    );
    if (!rows[0]) throw new BadRequestException("User not found");
    return rows[0];
  }

  async resolve(
    id: string,
    status: "resolved" | "dismissed",
    resolution?: string
  ): Promise<Dispute> {
    if (!this.pool) throw new BadRequestException("Unavailable");
    const { rows } = await this.pool.query(
      `UPDATE disputes SET status = $2, resolution = $3, resolved_at = now()
       WHERE id = $1 AND status = 'open' RETURNING ${COLS}`,
      [id, status, resolution ?? null]
    );
    if (!rows[0]) throw new BadRequestException("Dispute not found or already handled");
    return rows[0];
  }
}
