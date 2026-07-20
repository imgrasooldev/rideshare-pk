import { describe, expect, it } from "vitest";
import { loadConfig } from "../config/config.js";
import { InMemoryKvStore } from "../shared/kv.js";
import { InMemoryUserRepository } from "../users/users.repo.js";
import { AuthService } from "./auth.service.js";
import { InMemoryIdentityRepository } from "./identities.repo.js";
import type { OAuthVerifier, SocialProfile } from "./oauth.verifier.js";
import { OtpService } from "./otp.service.js";
import { TokenService } from "./token.service.js";

const PHONE = "03001234567";

class FakeOAuthVerifier implements OAuthVerifier {
  googleProfile: SocialProfile = {
    uid: "g-123",
    email: "ali@gmail.com",
    emailVerified: true,
    name: "Ali G"
  };

  async verifyGoogle(): Promise<SocialProfile> {
    return this.googleProfile;
  }

  async verifyFacebook(): Promise<SocialProfile> {
    return { uid: "fb-9", email: null, emailVerified: false, name: "FB User" };
  }
}

function makeAuth() {
  const config = loadConfig({});
  const kv = new InMemoryKvStore();
  const users = new InMemoryUserRepository();
  const identities = new InMemoryIdentityRepository();
  const oauth = new FakeOAuthVerifier();
  const otp = new OtpService(config, kv, { sendOtp: async () => {} });
  const tokens = new TokenService(config);
  const auth = new AuthService(config, kv, users, identities, oauth, otp, tokens);
  return { auth, otp, tokens, users, oauth };
}

async function login(ctx: ReturnType<typeof makeAuth>) {
  const { devCode } = await ctx.otp.requestOtp(PHONE);
  return ctx.auth.loginWithOtp(PHONE, devCode!);
}

describe("AuthService", () => {
  it("creates a user on first OTP login and returns working tokens", async () => {
    const ctx = makeAuth();
    const result = await login(ctx);

    expect(result.user.phone).toBe("+923001234567");
    expect(result.user.role).toBe("rider");
    const claims = ctx.tokens.verifyAccess(result.accessToken);
    expect(claims.sub).toBe(result.user.id);
    expect(claims.phone).toBe("+923001234567");
  });

  it("returns the same user on repeat logins (no duplicates)", async () => {
    const ctx = makeAuth();
    const first = await login(ctx);
    const second = await login(ctx);
    expect(second.user.id).toBe(first.user.id);
  });

  it("refresh rotates the token pair and revokes the spent one", async () => {
    const ctx = makeAuth();
    const first = await login(ctx);

    const rotated = await ctx.auth.refresh(first.refreshToken);
    expect(rotated.user.id).toBe(first.user.id);
    expect(rotated.refreshToken).not.toBe(first.refreshToken);
    expect(ctx.tokens.verifyAccess(rotated.accessToken).sub).toBe(first.user.id);

    // Replaying the already-spent refresh token must fail (rotation).
    await expect(ctx.auth.refresh(first.refreshToken)).rejects.toThrow(/revoked or already used/);
    // The new one still works.
    await expect(ctx.auth.refresh(rotated.refreshToken)).resolves.toBeTruthy();
  });

  it("rejects garbage refresh tokens", async () => {
    const ctx = makeAuth();
    await expect(ctx.auth.refresh("not-a-jwt")).rejects.toThrow(/Invalid or expired token/);
  });

  it("rejects an access token used as a refresh token", async () => {
    const ctx = makeAuth();
    const result = await login(ctx);
    await expect(ctx.auth.refresh(result.accessToken)).rejects.toThrow(/Invalid or expired token/);
  });

  describe("email/password", () => {
    it("registers, then logs in with the right password only", async () => {
      const ctx = makeAuth();
      const reg = await ctx.auth.register("sara@example.com", "hunter2secure", "Sara");
      expect(reg.user.email).toBe("sara@example.com");
      expect(reg.user.passwordHash).not.toContain("hunter2secure");
      expect(ctx.tokens.verifyAccess(reg.accessToken).sub).toBe(reg.user.id);

      const login2 = await ctx.auth.loginWithPassword("sara@example.com", "hunter2secure");
      expect(login2.user.id).toBe(reg.user.id);
      await expect(
        ctx.auth.loginWithPassword("sara@example.com", "wrong-password")
      ).rejects.toThrow(/Incorrect email or password/);
    });

    it("rejects duplicate emails with 409", async () => {
      const ctx = makeAuth();
      await ctx.auth.register("dup@example.com", "hunter2secure", null);
      await expect(ctx.auth.register("dup@example.com", "otherpass123", null)).rejects.toThrow(
        /already exists/
      );
    });

    it("rate-limits password logins after 5 failures", async () => {
      const ctx = makeAuth();
      await ctx.auth.register("rl@example.com", "hunter2secure", null);
      for (let i = 0; i < 5; i++) {
        await expect(ctx.auth.loginWithPassword("rl@example.com", "nope")).rejects.toThrow(
          /Incorrect/
        );
      }
      await expect(
        ctx.auth.loginWithPassword("rl@example.com", "hunter2secure")
      ).rejects.toThrow(/Too many attempts/);
    });

    it("forgot → reset flow rotates the password", async () => {
      const ctx = makeAuth();
      await ctx.auth.register("reset@example.com", "oldpassword1", null);

      // Unknown emails return silently (no enumeration).
      expect(await ctx.auth.forgotPassword("nobody@example.com")).toEqual({});

      const { devResetToken } = await ctx.auth.forgotPassword("reset@example.com");
      expect(devResetToken).toBeTruthy();
      await ctx.auth.resetPassword(devResetToken!, "newpassword9");

      await expect(
        ctx.auth.loginWithPassword("reset@example.com", "oldpassword1")
      ).rejects.toThrow(/Incorrect/);
      await expect(
        ctx.auth.loginWithPassword("reset@example.com", "newpassword9")
      ).resolves.toBeTruthy();
      // Token is single-use.
      await expect(ctx.auth.resetPassword(devResetToken!, "again12345")).rejects.toThrow(
        /invalid or expired/
      );
    });
  });

  describe("social sign-in", () => {
    it("creates an account on first Google login and reuses it after", async () => {
      const ctx = makeAuth();
      const first = await ctx.auth.loginWithGoogle("fake-id-token");
      expect(first.user.email).toBe("ali@gmail.com");
      expect(first.user.emailVerified).toBe(true);

      const again = await ctx.auth.loginWithGoogle("fake-id-token");
      expect(again.user.id).toBe(first.user.id);
    });

    it("links Google to an existing email/password account (same verified email)", async () => {
      const ctx = makeAuth();
      const reg = await ctx.auth.register("ali@gmail.com", "somepassword1", "Ali");
      const social = await ctx.auth.loginWithGoogle("fake-id-token");
      expect(social.user.id).toBe(reg.user.id);
    });

    it("handles Facebook accounts without an email", async () => {
      const ctx = makeAuth();
      const result = await ctx.auth.loginWithFacebook("fake-fb-token");
      expect(result.user.email).toBeNull();
      expect(result.user.name).toBe("FB User");
      const again = await ctx.auth.loginWithFacebook("fake-fb-token");
      expect(again.user.id).toBe(result.user.id);
    });
  });
});
