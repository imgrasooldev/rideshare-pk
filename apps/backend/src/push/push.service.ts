import { createSign } from "node:crypto";
import { Inject, Injectable } from "@nestjs/common";
import type { Pool } from "pg";
import type { AppConfig } from "../config/config.js";
import { APP_CONFIG, PG_POOL } from "../shared/tokens.js";

interface ServiceAccount {
  client_email: string;
  private_key: string;
}

/**
 * Push delivery via FCM HTTP v1. Device-token registration always works;
 * actual sending is DORMANT until FIREBASE_SERVICE_ACCOUNT is configured, so
 * this degrades to a no-op instead of erroring when push isn't set up yet.
 */
@Injectable()
export class PushService {
  private readonly sa: ServiceAccount | null;
  private accessToken: { value: string; expiresAt: number } | null = null;

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool | null,
    @Inject(APP_CONFIG) private readonly config: AppConfig
  ) {
    this.sa = this.parseServiceAccount(config.FIREBASE_SERVICE_ACCOUNT);
    if (!this.sa) {
      console.warn("FIREBASE_SERVICE_ACCOUNT not set — push delivery disabled (tokens still register).");
    }
  }

  private parseServiceAccount(raw: string): ServiceAccount | null {
    if (!raw.trim()) return null;
    try {
      const j = JSON.parse(raw) as ServiceAccount;
      return j.client_email && j.private_key ? j : null;
    } catch {
      console.error("FIREBASE_SERVICE_ACCOUNT is not valid JSON — push disabled.");
      return null;
    }
  }

  /** Store (or refresh) a device's FCM token for a user. */
  async register(userId: string, token: string, platform: string): Promise<void> {
    if (!this.pool) return;
    await this.pool.query(
      `INSERT INTO device_tokens (token, user_id, platform, updated_at)
       VALUES ($1, $2, $3, now())
       ON CONFLICT (token) DO UPDATE SET user_id = $2, platform = $3, updated_at = now()`,
      [token, userId, platform]
    );
  }

  /** Best-effort push to every device a user has registered. */
  async sendToUser(
    userId: string,
    title: string,
    body: string,
    data: Record<string, string> = {}
  ): Promise<void> {
    if (!this.pool || !this.sa) return;
    let tokens: string[];
    try {
      const { rows } = await this.pool.query<{ token: string }>(
        `SELECT token FROM device_tokens WHERE user_id = $1`,
        [userId]
      );
      tokens = rows.map((r) => r.token);
    } catch {
      return;
    }
    if (tokens.length === 0) return;

    let accessToken: string;
    try {
      accessToken = await this.getAccessToken();
    } catch {
      return;
    }
    const url = `https://fcm.googleapis.com/v1/projects/${this.config.FIREBASE_PROJECT_ID}/messages:send`;
    await Promise.all(
      tokens.map((token) => this.sendOne(url, accessToken, token, title, body, data))
    );
  }

  private async sendOne(
    url: string,
    accessToken: string,
    token: string,
    title: string,
    body: string,
    data: Record<string, string>
  ): Promise<void> {
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json"
        },
        body: JSON.stringify({ message: { token, notification: { title, body }, data } }),
        signal: AbortSignal.timeout(8000)
      });
      // A 404/400 (UNREGISTERED) means a stale token — prune it.
      if ((res.status === 404 || res.status === 400) && this.pool) {
        await this.pool
          .query(`DELETE FROM device_tokens WHERE token = $1`, [token])
          .catch(() => {});
      }
    } catch {
      /* best-effort */
    }
  }

  /** OAuth2 access token from the service account (cached until ~expiry). */
  private async getAccessToken(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    if (this.accessToken && this.accessToken.expiresAt - 60 > now) {
      return this.accessToken.value;
    }
    const sa = this.sa!;
    const header = { alg: "RS256", typ: "JWT" };
    const claim = {
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600
    };
    const enc = (o: unknown) => Buffer.from(JSON.stringify(o)).toString("base64url");
    const unsigned = `${enc(header)}.${enc(claim)}`;
    const signature = createSign("RSA-SHA256")
      .update(unsigned)
      .sign(sa.private_key, "base64url");
    const jwt = `${unsigned}.${signature}`;

    const res = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt
      }).toString(),
      signal: AbortSignal.timeout(8000)
    });
    if (!res.ok) throw new Error(`token exchange failed: ${res.status}`);
    const json = (await res.json()) as { access_token: string; expires_in: number };
    this.accessToken = { value: json.access_token, expiresAt: now + json.expires_in };
    return json.access_token;
  }
}
