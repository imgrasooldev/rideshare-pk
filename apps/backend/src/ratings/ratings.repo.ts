import type { Pool } from "pg";

export interface RatingRecord {
  id: string;
  rideId: string;
  fromUserId: string;
  toUserId: string;
  stars: number;
  comment: string | null;
  createdAt: string;
}

export class DuplicateRatingError extends Error {
  constructor() {
    super("You have already rated this person for this ride");
  }
}

export interface RatingRepository {
  /**
   * Inserts the rating and updates the target's rating aggregate atomically.
   * Throws DuplicateRatingError on a second rating for the same (ride, from, to).
   */
  create(rideId: string, fromUserId: string, toUserId: string, stars: number, comment: string | null): Promise<RatingRecord>;
  listForUser(userId: string, limit: number): Promise<RatingRecord[]>;
}

const COLS = `id, ride_id AS "rideId", from_user_id AS "fromUserId", to_user_id AS "toUserId",
  stars, comment, created_at AS "createdAt"`;

export class PgRatingRepository implements RatingRepository {
  constructor(private readonly pool: Pool) {}

  async create(rideId: string, fromUserId: string, toUserId: string, stars: number, comment: string | null): Promise<RatingRecord> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const ins = await client.query(
        `INSERT INTO ratings (ride_id, from_user_id, to_user_id, stars, comment)
         VALUES ($1, $2, $3, $4, $5) RETURNING ${COLS}`,
        [rideId, fromUserId, toUserId, stars, comment]
      );
      await client.query(
        `UPDATE users SET
           rating_avg = ROUND(((rating_avg * rating_count) + $2)::numeric / (rating_count + 1), 2),
           rating_count = rating_count + 1,
           updated_at = now()
         WHERE id = $1`,
        [toUserId, stars]
      );
      await client.query("COMMIT");
      return ins.rows[0];
    } catch (err: unknown) {
      await client.query("ROLLBACK").catch(() => {});
      if ((err as { code?: string }).code === "23505") throw new DuplicateRatingError();
      throw err;
    } finally {
      client.release();
    }
  }

  async listForUser(userId: string, limit: number): Promise<RatingRecord[]> {
    const { rows } = await this.pool.query(
      `SELECT ${COLS} FROM ratings WHERE to_user_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [userId, limit]
    );
    return rows;
  }
}

export class InMemoryRatingRepository implements RatingRepository {
  private readonly items: RatingRecord[] = [];
  /** Aggregates mirrored here so tests can assert avg/count updates. */
  readonly aggregates = new Map<string, { avg: number; count: number }>();

  async create(rideId: string, fromUserId: string, toUserId: string, stars: number, comment: string | null): Promise<RatingRecord> {
    if (this.items.some((r) => r.rideId === rideId && r.fromUserId === fromUserId && r.toUserId === toUserId)) {
      throw new DuplicateRatingError();
    }
    const rec: RatingRecord = {
      id: `rat-${this.items.length + 1}`,
      rideId,
      fromUserId,
      toUserId,
      stars,
      comment,
      createdAt: new Date().toISOString()
    };
    this.items.push(rec);
    const agg = this.aggregates.get(toUserId) ?? { avg: 0, count: 0 };
    const nextCount = agg.count + 1;
    this.aggregates.set(toUserId, {
      avg: Math.round(((agg.avg * agg.count + stars) / nextCount) * 100) / 100,
      count: nextCount
    });
    return rec;
  }

  async listForUser(userId: string, limit: number): Promise<RatingRecord[]> {
    return this.items
      .filter((r) => r.toUserId === userId)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .slice(0, limit);
  }
}
