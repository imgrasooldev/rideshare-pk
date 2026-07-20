import type { Pool } from "pg";

export type VerificationType = "cnic" | "license" | "vehicle";
export type VerificationStatus = "pending" | "approved" | "rejected";

export interface VerificationRecord {
  id: string;
  userId: string;
  type: VerificationType;
  docUrl: string;
  vehicleId: string | null;
  status: VerificationStatus;
  reviewerId: string | null;
  notes: string | null;
  createdAt: string;
}

export interface PendingPage {
  items: VerificationRecord[];
  /** Pass back as ?cursor= to get the next page; null when exhausted. */
  nextCursor: string | null;
}

export interface VerificationRepository {
  create(userId: string, type: VerificationType, docUrl: string, vehicleId: string | null): Promise<VerificationRecord>;
  findById(id: string): Promise<VerificationRecord | null>;
  /** FIFO review queue, keyset-paginated on (created_at, id). */
  listPending(cursor: string | null, limit: number): Promise<PendingPage>;
  review(id: string, status: Exclude<VerificationStatus, "pending">, reviewerId: string, notes: string | null): Promise<VerificationRecord | null>;
}

const COLS = `id, user_id AS "userId", type, doc_url AS "docUrl", vehicle_id AS "vehicleId",
  status, reviewer_id AS "reviewerId", notes, created_at AS "createdAt"`;

function encodeCursor(item: VerificationRecord): string {
  return Buffer.from(`${new Date(item.createdAt).toISOString()}|${item.id}`).toString("base64url");
}

function decodeCursor(cursor: string): { createdAt: string; id: string } | null {
  try {
    const [createdAt, id] = Buffer.from(cursor, "base64url").toString("utf8").split("|");
    if (!createdAt || !id) return null;
    return { createdAt, id };
  } catch {
    return null;
  }
}

export class PgVerificationRepository implements VerificationRepository {
  constructor(private readonly pool: Pool) {}

  async create(userId: string, type: VerificationType, docUrl: string, vehicleId: string | null): Promise<VerificationRecord> {
    const { rows } = await this.pool.query(
      `INSERT INTO verifications (user_id, type, doc_url, vehicle_id)
       VALUES ($1, $2, $3, $4) RETURNING ${COLS}`,
      [userId, type, docUrl, vehicleId]
    );
    return rows[0];
  }

  async findById(id: string): Promise<VerificationRecord | null> {
    const { rows } = await this.pool.query(`SELECT ${COLS} FROM verifications WHERE id = $1`, [id]);
    return rows[0] ?? null;
  }

  async listPending(cursor: string | null, limit: number): Promise<PendingPage> {
    const after = cursor ? decodeCursor(cursor) : null;
    const params: unknown[] = [limit + 1];
    let where = `status = 'pending'`;
    if (after) {
      where += ` AND (created_at, id) > ($2::timestamptz, $3::uuid)`;
      params.push(after.createdAt, after.id);
    }
    const { rows } = await this.pool.query(
      `SELECT ${COLS} FROM verifications WHERE ${where} ORDER BY created_at, id LIMIT $1`,
      params
    );
    const items = rows.slice(0, limit);
    const nextCursor = rows.length > limit ? encodeCursor(items[items.length - 1]) : null;
    return { items, nextCursor };
  }

  async review(id: string, status: Exclude<VerificationStatus, "pending">, reviewerId: string, notes: string | null): Promise<VerificationRecord | null> {
    const { rows } = await this.pool.query(
      `UPDATE verifications SET status = $2, reviewer_id = $3, notes = $4, updated_at = now()
       WHERE id = $1 AND status = 'pending' RETURNING ${COLS}`,
      [id, status, reviewerId, notes]
    );
    return rows[0] ?? null;
  }
}

export class InMemoryVerificationRepository implements VerificationRepository {
  private readonly items = new Map<string, VerificationRecord>();
  private seq = 0;

  async create(userId: string, type: VerificationType, docUrl: string, vehicleId: string | null): Promise<VerificationRecord> {
    const rec: VerificationRecord = {
      id: `ver-${String(++this.seq).padStart(4, "0")}`,
      userId,
      type,
      docUrl,
      vehicleId,
      status: "pending",
      reviewerId: null,
      notes: null,
      createdAt: new Date(Date.now() + this.seq).toISOString() // strictly increasing for stable pagination
    };
    this.items.set(rec.id, rec);
    return rec;
  }

  async findById(id: string): Promise<VerificationRecord | null> {
    return this.items.get(id) ?? null;
  }

  async listPending(cursor: string | null, limit: number): Promise<PendingPage> {
    const after = cursor ? decodeCursor(cursor) : null;
    const all = [...this.items.values()]
      .filter((v) => v.status === "pending")
      .sort((a, b) => a.createdAt.localeCompare(b.createdAt) || a.id.localeCompare(b.id))
      .filter((v) => {
        if (!after) return true;
        const cmp = v.createdAt.localeCompare(after.createdAt);
        return cmp > 0 || (cmp === 0 && v.id.localeCompare(after.id) > 0);
      });
    const items = all.slice(0, limit);
    const nextCursor = all.length > limit ? encodeCursor(items[items.length - 1]!) : null;
    return { items, nextCursor };
  }

  async review(id: string, status: Exclude<VerificationStatus, "pending">, reviewerId: string, notes: string | null): Promise<VerificationRecord | null> {
    const rec = this.items.get(id);
    if (!rec || rec.status !== "pending") return null;
    rec.status = status;
    rec.reviewerId = reviewerId;
    rec.notes = notes;
    return rec;
  }
}
