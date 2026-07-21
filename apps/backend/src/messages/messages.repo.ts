import type { Pool } from "pg";

export interface MessageRecord {
  id: string;
  rideId: string;
  senderId: string;
  recipientId: string;
  body: string;
  readAt: string | null;
  createdAt: string;
}

/** One conversation summary for the inbox. */
export interface ThreadSummary {
  rideId: string;
  otherId: string;
  otherName: string | null;
  originLabel: string;
  destLabel: string;
  lastBody: string;
  lastAt: string;
  lastFromMe: boolean;
  unread: number;
}

export interface MessageRepository {
  send(rideId: string, senderId: string, recipientId: string, body: string): Promise<MessageRecord>;
  /** Messages for a ride between two users, oldest first. */
  thread(rideId: string, userId: string, otherId: string, limit: number): Promise<MessageRecord[]>;
  /** Mark messages TO userId (from otherId) in this ride's thread as read. */
  markThreadRead(rideId: string, userId: string, otherId: string): Promise<void>;
  listThreads(userId: string): Promise<ThreadSummary[]>;
  unreadCount(userId: string): Promise<number>;
}

const COLS = `id, ride_id AS "rideId", sender_id AS "senderId",
  recipient_id AS "recipientId", body, read_at AS "readAt", created_at AS "createdAt"`;

export class PgMessageRepository implements MessageRepository {
  constructor(private readonly pool: Pool) {}

  async send(rideId: string, senderId: string, recipientId: string, body: string): Promise<MessageRecord> {
    const { rows } = await this.pool.query(
      `INSERT INTO messages (ride_id, sender_id, recipient_id, body)
       VALUES ($1, $2, $3, $4) RETURNING ${COLS}`,
      [rideId, senderId, recipientId, body]
    );
    return rows[0];
  }

  async thread(rideId: string, userId: string, otherId: string, limit: number): Promise<MessageRecord[]> {
    const { rows } = await this.pool.query(
      `SELECT ${COLS} FROM messages
       WHERE ride_id = $1
         AND ((sender_id = $2 AND recipient_id = $3) OR (sender_id = $3 AND recipient_id = $2))
       ORDER BY created_at ASC
       LIMIT $4`,
      [rideId, userId, otherId, limit]
    );
    return rows;
  }

  async markThreadRead(rideId: string, userId: string, otherId: string): Promise<void> {
    await this.pool.query(
      `UPDATE messages SET read_at = now()
       WHERE ride_id = $1 AND recipient_id = $2 AND sender_id = $3 AND read_at IS NULL`,
      [rideId, userId, otherId]
    );
  }

  async listThreads(userId: string): Promise<ThreadSummary[]> {
    // Newest message per (ride, counterparty), plus that thread's unread count.
    const { rows } = await this.pool.query(
      `WITH convo AS (
         SELECT m.*,
           CASE WHEN sender_id = $1 THEN recipient_id ELSE sender_id END AS other_id
         FROM messages m
         WHERE sender_id = $1 OR recipient_id = $1
       ),
       last AS (
         SELECT DISTINCT ON (ride_id, other_id)
           ride_id, other_id, id, body, created_at, sender_id
         FROM convo
         ORDER BY ride_id, other_id, created_at DESC
       ),
       unread AS (
         SELECT ride_id, sender_id AS other_id, COUNT(*)::int AS n
         FROM messages
         WHERE recipient_id = $1 AND read_at IS NULL
         GROUP BY ride_id, sender_id
       )
       SELECT l.ride_id AS "rideId", l.other_id AS "otherId", u.name AS "otherName",
         r.origin_label AS "originLabel", r.dest_label AS "destLabel",
         l.body AS "lastBody", l.created_at AS "lastAt",
         (l.sender_id = $1) AS "lastFromMe",
         COALESCE(un.n, 0) AS "unread"
       FROM last l
       JOIN users u ON u.id = l.other_id
       JOIN rides r ON r.id = l.ride_id
       LEFT JOIN unread un ON un.ride_id = l.ride_id AND un.other_id = l.other_id
       ORDER BY l.created_at DESC`,
      [userId]
    );
    return rows;
  }

  async unreadCount(userId: string): Promise<number> {
    const { rows } = await this.pool.query(
      `SELECT COUNT(*)::int AS n FROM messages WHERE recipient_id = $1 AND read_at IS NULL`,
      [userId]
    );
    return rows[0]?.n ?? 0;
  }
}

export class InMemoryMessageRepository implements MessageRepository {
  private readonly items: MessageRecord[] = [];
  private seq = 0;

  async send(rideId: string, senderId: string, recipientId: string, body: string): Promise<MessageRecord> {
    const rec: MessageRecord = {
      id: `msg-${String(++this.seq).padStart(4, "0")}`,
      rideId,
      senderId,
      recipientId,
      body,
      readAt: null,
      createdAt: new Date(Date.now() + this.seq).toISOString()
    };
    this.items.push(rec);
    return rec;
  }

  async thread(rideId: string, userId: string, otherId: string, limit: number): Promise<MessageRecord[]> {
    return this.items
      .filter(
        (m) =>
          m.rideId === rideId &&
          ((m.senderId === userId && m.recipientId === otherId) ||
            (m.senderId === otherId && m.recipientId === userId))
      )
      .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
      .slice(0, limit);
  }

  async markThreadRead(rideId: string, userId: string, otherId: string): Promise<void> {
    for (const m of this.items) {
      if (m.rideId === rideId && m.recipientId === userId && m.senderId === otherId && !m.readAt) {
        m.readAt = new Date().toISOString();
      }
    }
  }

  async listThreads(userId: string): Promise<ThreadSummary[]> {
    const byThread = new Map<string, MessageRecord>();
    for (const m of this.items) {
      if (m.senderId !== userId && m.recipientId !== userId) continue;
      const other = m.senderId === userId ? m.recipientId : m.senderId;
      const key = `${m.rideId}|${other}`;
      const cur = byThread.get(key);
      if (!cur || m.createdAt > cur.createdAt) byThread.set(key, m);
    }
    const summaries: ThreadSummary[] = [];
    for (const last of byThread.values()) {
      const other = last.senderId === userId ? last.recipientId : last.senderId;
      const unread = this.items.filter(
        (m) => m.rideId === last.rideId && m.recipientId === userId && m.senderId === other && !m.readAt
      ).length;
      summaries.push({
        rideId: last.rideId,
        otherId: other,
        otherName: null,
        originLabel: "",
        destLabel: "",
        lastBody: last.body,
        lastAt: last.createdAt,
        lastFromMe: last.senderId === userId,
        unread
      });
    }
    return summaries.sort((a, b) => b.lastAt.localeCompare(a.lastAt));
  }

  async unreadCount(userId: string): Promise<number> {
    return this.items.filter((m) => m.recipientId === userId && !m.readAt).length;
  }
}
