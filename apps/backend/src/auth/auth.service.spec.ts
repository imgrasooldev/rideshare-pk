import { describe, expect, it } from "vitest";
import { loadConfig } from "../config/config.js";
import { InMemoryKvStore } from "../shared/kv.js";
import { InMemoryUserRepository } from "../users/users.repo.js";
import { AuthService } from "./auth.service.js";
import { OtpService } from "./otp.service.js";
import { TokenService } from "./token.service.js";

const PHONE = "03001234567";

function makeAuth() {
  const config = loadConfig({});
  const kv = new InMemoryKvStore();
  const users = new InMemoryUserRepository();
  const otp = new OtpService(config, kv, { sendOtp: async () => {} });
  const tokens = new TokenService(config);
  const auth = new AuthService(config, kv, users, otp, tokens);
  return { auth, otp, tokens, users };
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
});
