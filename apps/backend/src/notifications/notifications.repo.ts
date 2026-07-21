import type { Pool } from "pg";

export interface NotificationRecord {
  id: string;
  userId: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
  readAt: string | null;
  createdAt: string;
}

export interface NotificationRepository {
  create(
    userId: string,
    type: string,
    title: string,
    body: string,
    data?: Record<string, unknown>
  ): Promise<NotificationRecord>;
  listForUser(userId: string, limit: number): Promise<NotificationRecord[]>;
  unreadCount(userId: string): Promise<number>;
  markRead(id: string, userId: string): Promise<void>;
  markAllRead(userId: string): Promise<void>;
}

const COLS = `id, user_id AS "userId", type, title, body, data,
  read_at AS "readAt", created_at AS "createdAt"`;

export class PgNotificationRepository implements NotificationRepository {
  constructor(private readonly pool: Pool) {}

  async create(userId: string, type: string, title: string, body: string, data = {}): Promise<NotificationRecord> {
    const { rows } = await this.pool.query(
      `INSERT INTO notifications (user_id, type, title, body, data)
       VALUES ($1, $2, $3, $4, $5) RETURNING ${COLS}`,
      [userId, type, title, body, JSON.stringify(data)]
    );
    return rows[0];
  }

  async listForUser(userId: string, limit: number): Promise<NotificationRecord[]> {
    const { rows } = await this.pool.query(
      `SELECT ${COLS} FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [userId, limit]
    );
    return rows;
  }

  async unreadCount(userId: string): Promise<number> {
    const { rows } = await this.pool.query(
      `SELECT COUNT(*)::int AS n FROM notifications WHERE user_id = $1 AND read_at IS NULL`,
      [userId]
    );
    return rows[0]?.n ?? 0;
  }

  async markRead(id: string, userId: string): Promise<void> {
    await this.pool.query(
      `UPDATE notifications SET read_at = now() WHERE id = $1 AND user_id = $2 AND read_at IS NULL`,
      [id, userId]
    );
  }

  async markAllRead(userId: string): Promise<void> {
    await this.pool.query(
      `UPDATE notifications SET read_at = now() WHERE user_id = $1 AND read_at IS NULL`,
      [userId]
    );
  }
}

export class InMemoryNotificationRepository implements NotificationRepository {
  private readonly items: NotificationRecord[] = [];
  private seq = 0;

  async create(userId: string, type: string, title: string, body: string, data = {}): Promise<NotificationRecord> {
    const rec: NotificationRecord = {
      id: `ntf-${String(++this.seq).padStart(4, "0")}`,
      userId,
      type,
      title,
      body,
      data,
      readAt: null,
      createdAt: new Date(Date.now() + this.seq).toISOString()
    };
    this.items.unshift(rec);
    return rec;
  }

  async listForUser(userId: string, limit: number): Promise<NotificationRecord[]> {
    return this.items.filter((n) => n.userId === userId).slice(0, limit);
  }

  async unreadCount(userId: string): Promise<number> {
    return this.items.filter((n) => n.userId === userId && !n.readAt).length;
  }

  async markRead(id: string, userId: string): Promise<void> {
    const n = this.items.find((x) => x.id === id && x.userId === userId);
    if (n && !n.readAt) n.readAt = new Date().toISOString();
  }

  async markAllRead(userId: string): Promise<void> {
    for (const n of this.items) if (n.userId === userId && !n.readAt) n.readAt = new Date().toISOString();
  }
}
