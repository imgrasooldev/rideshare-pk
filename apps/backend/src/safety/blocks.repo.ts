import type { Pool } from "pg";

/** A person the current user has blocked. */
export interface BlockedUser {
  userId: string;
  name: string | null;
  reason: string | null;
  createdAt: string;
}

export interface BlocksRepository {
  block(blockerId: string, blockedId: string, reason: string | null): Promise<void>;
  unblock(blockerId: string, blockedId: string): Promise<void>;
  list(blockerId: string): Promise<BlockedUser[]>;
  /**
   * True when either user has blocked the other. Blocking is expressed by one
   * side but enforced both ways — the blocker must not be matched with the
   * person they avoided, and that person must not be able to reach them.
   */
  isBlockedEitherWay(a: string, b: string): Promise<boolean>;
  /** Every user id in a mutual-block relationship with this user. */
  blockedIdsFor(userId: string): Promise<string[]>;
}

export class PgBlocksRepository implements BlocksRepository {
  constructor(private readonly pool: Pool) {}

  async block(blockerId: string, blockedId: string, reason: string | null): Promise<void> {
    await this.pool.query(
      `INSERT INTO user_blocks (blocker_id, blocked_id, reason) VALUES ($1, $2, $3)
       ON CONFLICT (blocker_id, blocked_id) DO UPDATE SET reason = EXCLUDED.reason`,
      [blockerId, blockedId, reason]
    );
  }

  async unblock(blockerId: string, blockedId: string): Promise<void> {
    await this.pool.query(
      `DELETE FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2`,
      [blockerId, blockedId]
    );
  }

  async list(blockerId: string): Promise<BlockedUser[]> {
    const { rows } = await this.pool.query(
      `SELECT b.blocked_id AS "userId", u.name, b.reason, b.created_at AS "createdAt"
       FROM user_blocks b JOIN users u ON u.id = b.blocked_id
       WHERE b.blocker_id = $1 ORDER BY b.created_at DESC`,
      [blockerId]
    );
    return rows;
  }

  async isBlockedEitherWay(a: string, b: string): Promise<boolean> {
    const { rows } = await this.pool.query(
      `SELECT 1 FROM user_blocks
       WHERE (blocker_id = $1 AND blocked_id = $2)
          OR (blocker_id = $2 AND blocked_id = $1) LIMIT 1`,
      [a, b]
    );
    return rows.length > 0;
  }

  async blockedIdsFor(userId: string): Promise<string[]> {
    const { rows } = await this.pool.query(
      `SELECT blocked_id AS id FROM user_blocks WHERE blocker_id = $1
       UNION
       SELECT blocker_id AS id FROM user_blocks WHERE blocked_id = $1`,
      [userId]
    );
    return rows.map((r) => r.id);
  }
}

export class InMemoryBlocksRepository implements BlocksRepository {
  private readonly pairs = new Map<string, { reason: string | null; createdAt: string }>();
  private readonly key = (a: string, b: string) => `${a}|${b}`;

  async block(blockerId: string, blockedId: string, reason: string | null): Promise<void> {
    this.pairs.set(this.key(blockerId, blockedId), {
      reason,
      createdAt: new Date().toISOString()
    });
  }

  async unblock(blockerId: string, blockedId: string): Promise<void> {
    this.pairs.delete(this.key(blockerId, blockedId));
  }

  async list(blockerId: string): Promise<BlockedUser[]> {
    const out: BlockedUser[] = [];
    for (const [k, v] of this.pairs) {
      const [blocker, blocked] = k.split("|");
      if (blocker === blockerId) {
        out.push({ userId: blocked!, name: null, reason: v.reason, createdAt: v.createdAt });
      }
    }
    return out.sort((x, y) => y.createdAt.localeCompare(x.createdAt));
  }

  async isBlockedEitherWay(a: string, b: string): Promise<boolean> {
    return this.pairs.has(this.key(a, b)) || this.pairs.has(this.key(b, a));
  }

  async blockedIdsFor(userId: string): Promise<string[]> {
    const out = new Set<string>();
    for (const k of this.pairs.keys()) {
      const [blocker, blocked] = k.split("|");
      if (blocker === userId) out.add(blocked!);
      if (blocked === userId) out.add(blocker!);
    }
    return [...out];
  }
}
