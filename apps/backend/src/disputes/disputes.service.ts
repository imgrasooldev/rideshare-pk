import { BadRequestException, Inject, Injectable } from "@nestjs/common";
import type { Pool } from "pg";
import { PG_POOL } from "../shared/tokens.js";

export interface Dispute {
  id: string;
  bookingId: string | null;
  userId: string;
  category: string;
  message: string;
  status: "open" | "resolved" | "dismissed";
  resolution: string | null;
  createdAt: string;
}

const COLS = `id, booking_id AS "bookingId", user_id AS "userId", category, message,
  status, resolution, created_at AS "createdAt"`;

@Injectable()
export class DisputesService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool | null) {}

  async file(
    userId: string,
    category: string,
    message: string,
    bookingId?: string
  ): Promise<Dispute> {
    if (!this.pool) throw new BadRequestException("Unavailable");
    const { rows } = await this.pool.query(
      `INSERT INTO disputes (booking_id, user_id, category, message)
       VALUES ($1, $2, $3, $4) RETURNING ${COLS}`,
      [bookingId ?? null, userId, category, message.trim()]
    );
    return rows[0];
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
