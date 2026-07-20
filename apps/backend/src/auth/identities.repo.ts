import type { Pool } from "pg";

export type SocialProvider = "google" | "facebook";
// (email may be null — some Facebook accounts expose no email)

export interface IdentityRecord {
  id: string;
  userId: string;
  provider: SocialProvider;
  providerUid: string;
  email: string | null;
}

export interface IdentityRepository {
  find(provider: SocialProvider, providerUid: string): Promise<IdentityRecord | null>;
  link(userId: string, provider: SocialProvider, providerUid: string, email: string | null): Promise<IdentityRecord>;
}

const COLS = `id, user_id AS "userId", provider, provider_uid AS "providerUid", email`;

export class PgIdentityRepository implements IdentityRepository {
  constructor(private readonly pool: Pool) {}

  async find(provider: SocialProvider, providerUid: string): Promise<IdentityRecord | null> {
    const { rows } = await this.pool.query(
      `SELECT ${COLS} FROM user_identities WHERE provider = $1 AND provider_uid = $2`,
      [provider, providerUid]
    );
    return rows[0] ?? null;
  }

  async link(userId: string, provider: SocialProvider, providerUid: string, email: string | null): Promise<IdentityRecord> {
    const { rows } = await this.pool.query(
      `INSERT INTO user_identities (user_id, provider, provider_uid, email)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (provider, provider_uid) DO UPDATE SET email = EXCLUDED.email
       RETURNING ${COLS}`,
      [userId, provider, providerUid, email]
    );
    return rows[0];
  }
}

export class InMemoryIdentityRepository implements IdentityRepository {
  private readonly items = new Map<string, IdentityRecord>();
  private seq = 0;

  async find(provider: SocialProvider, providerUid: string): Promise<IdentityRecord | null> {
    return this.items.get(`${provider}:${providerUid}`) ?? null;
  }

  async link(userId: string, provider: SocialProvider, providerUid: string, email: string | null): Promise<IdentityRecord> {
    const key = `${provider}:${providerUid}`;
    const rec: IdentityRecord = {
      id: `idn-${++this.seq}`,
      userId,
      provider,
      providerUid,
      email
    };
    this.items.set(key, rec);
    return rec;
  }
}
