import { createHmac } from "node:crypto";
import { ServiceUnavailableException, UnauthorizedException } from "@nestjs/common";
import { OAuth2Client } from "google-auth-library";
import type { AppConfig } from "../config/config.js";

export interface SocialProfile {
  uid: string;
  email: string | null;
  emailVerified: boolean;
  name: string | null;
}

/** Verifies provider tokens server-side. Faked in tests; config-gated in prod. */
export interface OAuthVerifier {
  verifyGoogle(idToken: string): Promise<SocialProfile>;
  verifyFacebook(accessToken: string): Promise<SocialProfile>;
}

export class RealOAuthVerifier implements OAuthVerifier {
  constructor(private readonly config: AppConfig) {}

  async verifyGoogle(idToken: string): Promise<SocialProfile> {
    if (!this.config.GOOGLE_CLIENT_ID) {
      throw new ServiceUnavailableException("Google sign-in is not configured yet");
    }
    try {
      const client = new OAuth2Client(this.config.GOOGLE_CLIENT_ID);
      const ticket = await client.verifyIdToken({
        idToken,
        audience: this.config.GOOGLE_CLIENT_ID
      });
      const payload = ticket.getPayload();
      if (!payload?.sub) throw new Error("no subject");
      return {
        uid: payload.sub,
        email: payload.email ?? null,
        emailVerified: payload.email_verified ?? false,
        name: payload.name ?? null
      };
    } catch {
      throw new UnauthorizedException("Google sign-in failed — try again");
    }
  }

  async verifyFacebook(accessToken: string): Promise<SocialProfile> {
    if (!this.config.FB_APP_ID || !this.config.FB_APP_SECRET) {
      throw new ServiceUnavailableException("Facebook sign-in is not configured yet");
    }
    try {
      // appsecret_proof prevents token replay from other apps.
      const proof = createHmac("sha256", this.config.FB_APP_SECRET)
        .update(accessToken)
        .digest("hex");
      const res = await fetch(
        `https://graph.facebook.com/v19.0/me?fields=id,name,email&access_token=${encodeURIComponent(accessToken)}&appsecret_proof=${proof}`
      );
      if (!res.ok) throw new Error(`graph ${res.status}`);
      const profile = (await res.json()) as { id?: string; name?: string; email?: string };
      if (!profile.id) throw new Error("no id");
      return {
        uid: profile.id,
        email: profile.email ?? null,
        emailVerified: Boolean(profile.email), // FB emails are verified by FB
        name: profile.name ?? null
      };
    } catch (err) {
      if (err instanceof ServiceUnavailableException) throw err;
      throw new UnauthorizedException("Facebook sign-in failed — try again");
    }
  }
}
