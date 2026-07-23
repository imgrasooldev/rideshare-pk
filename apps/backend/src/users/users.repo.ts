import type { Pool } from "pg";

// Other modules must go through this interface, never the users table.
export interface UserRecord {
  id: string;
  /** E.164, null for email/social-only accounts until they verify a phone. */
  phone: string | null;
  email: string | null;
  emailVerified: boolean;
  /** bcrypt hash — never leaves the repository layer's consumers. */
  passwordHash: string | null;
  name: string | null;
  role: "driver" | "rider" | "both";
  gender: "female" | "male" | "other" | null;
  /** Encrypted at rest (AES-GCM) — never expose raw; mask via UsersService. */
  cnic: string | null;
  verified: boolean;
  /** Set when an admin suspended the account; blocks sign-in and actions. */
  suspendedAt?: string | null;
  isAdmin: boolean;
  city: string;
  ratingAvg: number;
  ratingCount: number;
  emergencyPhone: string | null;
  /** Driver availability — offline hides their rides from search. */
  isOnline: boolean;
}

export interface ProfilePatch {
  name?: string;
  role?: UserRecord["role"];
  gender?: NonNullable<UserRecord["gender"]>;
  cnic?: string; // already encrypted by the service layer
  emergencyPhone?: string; // already normalised to E.164 by the service layer
}

export interface NewEmailUser {
  email: string | null; // null for social accounts without an email
  passwordHash: string | null; // null for social-only accounts
  name: string | null;
  emailVerified: boolean;
  city: string;
}

export interface UserRepository {
  findById(id: string): Promise<UserRecord | null>;
  findByPhone(phone: string): Promise<UserRecord | null>;
  findByEmail(email: string): Promise<UserRecord | null>;
  /** Returns the existing user for this phone, or creates a rider profile. */
  upsertByPhone(phone: string, city: string): Promise<UserRecord>;
  createWithEmail(input: NewEmailUser): Promise<UserRecord>;
  setPassword(id: string, passwordHash: string): Promise<void>;
  updateProfile(id: string, patch: ProfilePatch): Promise<UserRecord | null>;
  setVerified(id: string, verified: boolean): Promise<void>;
  setAdmin(id: string, isAdmin: boolean): Promise<void>;
  setOnline(id: string, online: boolean): Promise<UserRecord | null>;
}

const COLS = `id, phone, email, email_verified AS "emailVerified", password_hash AS "passwordHash",
  name, role, gender, cnic, verified, is_admin AS "isAdmin", city,
  rating_avg::float8 AS "ratingAvg", rating_count AS "ratingCount",
  emergency_phone AS "emergencyPhone", is_online AS "isOnline",
  suspended_at AS "suspendedAt"`;

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

  async findByEmail(email: string): Promise<UserRecord | null> {
    const { rows } = await this.pool.query(
      `SELECT ${COLS} FROM users WHERE lower(email) = lower($1) AND deleted_at IS NULL`,
      [email]
    );
    return rows[0] ?? null;
  }

  async createWithEmail(input: NewEmailUser): Promise<UserRecord> {
    const { rows } = await this.pool.query(
      `INSERT INTO users (email, email_verified, password_hash, name, city)
       VALUES ($1, $2, $3, $4, $5) RETURNING ${COLS}`,
      [input.email, input.emailVerified, input.passwordHash, input.name, input.city]
    );
    return rows[0];
  }

  async setPassword(id: string, passwordHash: string): Promise<void> {
    await this.pool.query(
      `UPDATE users SET password_hash = $2, updated_at = now() WHERE id = $1`,
      [id, passwordHash]
    );
  }

  async updateProfile(id: string, patch: ProfilePatch): Promise<UserRecord | null> {
    const { rows } = await this.pool.query(
      `UPDATE users SET
         name = COALESCE($2, name),
         role = COALESCE($3, role),
         gender = COALESCE($4, gender),
         cnic = COALESCE($5, cnic),
         emergency_phone = COALESCE($6, emergency_phone),
         updated_at = now()
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING ${COLS}`,
      [
        id,
        patch.name ?? null,
        patch.role ?? null,
        patch.gender ?? null,
        patch.cnic ?? null,
        patch.emergencyPhone ?? null
      ]
    );
    return rows[0] ?? null;
  }

  async setVerified(id: string, verified: boolean): Promise<void> {
    await this.pool.query(`UPDATE users SET verified = $2, updated_at = now() WHERE id = $1`, [
      id,
      verified
    ]);
  }

  async setAdmin(id: string, isAdmin: boolean): Promise<void> {
    await this.pool.query(`UPDATE users SET is_admin = $2, updated_at = now() WHERE id = $1`, [
      id,
      isAdmin
    ]);
  }

  async setOnline(id: string, online: boolean): Promise<UserRecord | null> {
    const { rows } = await this.pool.query(
      `UPDATE users SET is_online = $2, updated_at = now() WHERE id = $1 RETURNING ${COLS}`,
      [id, online]
    );
    return rows[0] ?? null;
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

  private blank(city: string): UserRecord {
    return {
      id: `mem-${++this.seq}`,
      phone: null,
      email: null,
      emailVerified: false,
      passwordHash: null,
      name: null,
      role: "rider",
      gender: null,
      cnic: null,
      verified: false,
      isAdmin: false,
      city,
      ratingAvg: 0,
      ratingCount: 0,
      emergencyPhone: null,
      isOnline: true
    };
  }

  async upsertByPhone(phone: string, city: string): Promise<UserRecord> {
    const existing = this.byPhone.get(phone);
    if (existing) return existing;
    const user = { ...this.blank(city), phone };
    this.byPhone.set(phone, user);
    return user;
  }

  async findByEmail(email: string): Promise<UserRecord | null> {
    for (const u of this.byPhone.values()) {
      if (u.email?.toLowerCase() === email.toLowerCase()) return u;
    }
    return null;
  }

  async createWithEmail(input: NewEmailUser): Promise<UserRecord> {
    const user = {
      ...this.blank(input.city),
      email: input.email,
      emailVerified: input.emailVerified,
      passwordHash: input.passwordHash,
      name: input.name
    };
    this.byPhone.set(`email:${user.id}`, user); // keyed arbitrarily; lookups scan values
    return user;
  }

  async setPassword(id: string, passwordHash: string): Promise<void> {
    const user = await this.findById(id);
    if (user) user.passwordHash = passwordHash;
  }

  async updateProfile(id: string, patch: ProfilePatch): Promise<UserRecord | null> {
    const user = await this.findById(id);
    if (!user) return null;
    if (patch.name !== undefined) user.name = patch.name;
    if (patch.role !== undefined) user.role = patch.role;
    if (patch.gender !== undefined) user.gender = patch.gender;
    if (patch.cnic !== undefined) user.cnic = patch.cnic;
    if (patch.emergencyPhone !== undefined) user.emergencyPhone = patch.emergencyPhone;
    return user;
  }

  async setVerified(id: string, verified: boolean): Promise<void> {
    const user = await this.findById(id);
    if (user) user.verified = verified;
  }

  async setAdmin(id: string, isAdmin: boolean): Promise<void> {
    const user = await this.findById(id);
    if (user) user.isAdmin = isAdmin;
  }

  async setOnline(id: string, online: boolean): Promise<UserRecord | null> {
    const user = await this.findById(id);
    if (user) user.isOnline = online;
    return user;
  }
}
