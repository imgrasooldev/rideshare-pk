import type { Pool } from "pg";

// Minimal user shape auth needs. The users module grows in build step 3;
// other modules must go through this interface, never the table.
export interface UserRecord {
  id: string;
  phone: string;
  name: string | null;
  role: "driver" | "rider" | "both";
  verified: boolean;
  city: string;
}

export interface UserRepository {
  findById(id: string): Promise<UserRecord | null>;
  findByPhone(phone: string): Promise<UserRecord | null>;
  /** Returns the existing user for this phone, or creates a rider profile. */
  upsertByPhone(phone: string, city: string): Promise<UserRecord>;
}

const COLS = "id, phone, name, role, verified, city";

export class PgUserRepository implements UserRepository {
  constructor(private readonly pool: Pool) {}

  async findById(id: string): Promise<UserRecord | null> {
    const { rows } = await this.pool.query(
      `SELECT ${COLS} FROM users WHERE id = $1 AND deleted_at IS NULL`,
      [id]
    );
    return rows[0] ?? null;
  }

  async findByPhone(phone: string): Promise<UserRecord | null> {
    const { rows } = await this.pool.query(
      `SELECT ${COLS} FROM users WHERE phone = $1 AND deleted_at IS NULL`,
      [phone]
    );
    return rows[0] ?? null;
  }

  async upsertByPhone(phone: string, city: string): Promise<UserRecord> {
    const { rows } = await this.pool.query(
      `INSERT INTO users (phone, city) VALUES ($1, $2)
       ON CONFLICT (phone) DO UPDATE SET updated_at = now()
       RETURNING ${COLS}`,
      [phone, city]
    );
    return rows[0];
  }
}

export class InMemoryUserRepository implements UserRepository {
  private readonly byPhone = new Map<string, UserRecord>();
  private seq = 0;

  async findById(id: string): Promise<UserRecord | null> {
    for (const u of this.byPhone.values()) if (u.id === id) return u;
    return null;
  }

  async findByPhone(phone: string): Promise<UserRecord | null> {
    return this.byPhone.get(phone) ?? null;
  }

  async upsertByPhone(phone: string, city: string): Promise<UserRecord> {
    const existing = this.byPhone.get(phone);
    if (existing) return existing;
    const user: UserRecord = {
      id: `mem-${++this.seq}`,
      phone,
      name: null,
      role: "rider",
      verified: false,
      city
    };
    this.byPhone.set(phone, user);
    return user;
  }
}
