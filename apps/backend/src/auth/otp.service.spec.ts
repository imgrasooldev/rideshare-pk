import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { loadConfig } from "../config/config.js";
import { InMemoryKvStore } from "../shared/kv.js";
import { OtpService } from "./otp.service.js";
import type { SmsSender } from "./sms.js";

const PHONE = "03001234567";

function makeService() {
  const sent: Array<{ phone: string; code: string }> = [];
  const sms: SmsSender = {
    sendOtp: async (phone, code) => {
      sent.push({ phone, code });
    }
  };
  const config = loadConfig({ OTP_DEV_MODE: "true" });
  const service = new OtpService(config, new InMemoryKvStore(), sms);
  return { service, sent, config };
}

describe("OtpService", () => {
  it("issues a 6-digit code and verifies it once", async () => {
    const { service, sent } = makeService();
    const { devCode } = await service.requestOtp(PHONE);
    expect(devCode).toMatch(/^\d{6}$/);
    expect(sent).toEqual([{ phone: "+923001234567", code: devCode }]);

    await expect(service.verifyOtp(PHONE, devCode!)).resolves.toBe("+923001234567");
    // Code is consumed — replaying it fails.
    await expect(service.verifyOtp(PHONE, devCode!)).rejects.toThrow(/Invalid or expired/);
  });

  it("rejects invalid phone numbers", async () => {
    const { service } = makeService();
    await expect(service.requestOtp("12345")).rejects.toThrow(/valid Pakistani mobile/);
  });

  it("rejects a wrong code", async () => {
    const { service } = makeService();
    const { devCode } = await service.requestOtp(PHONE);
    const wrong = devCode === "000000" ? "111111" : "000000";
    await expect(service.verifyOtp(PHONE, wrong)).rejects.toThrow(/Invalid or expired/);
  });

  it("rate-limits OTP requests per phone per hour", async () => {
    const { service, config } = makeService();
    for (let i = 0; i < config.OTP_MAX_REQUESTS_PER_HOUR; i++) {
      await service.requestOtp(PHONE);
    }
    await expect(service.requestOtp(PHONE)).rejects.toThrow(/Too many OTP requests/);
    // A different number is unaffected.
    await expect(service.requestOtp("03119876543")).resolves.toBeTruthy();
  });

  it("locks verification after 5 attempts (no brute force on 6 digits)", async () => {
    const { service } = makeService();
    const { devCode } = await service.requestOtp(PHONE);
    const wrong = devCode === "000000" ? "111111" : "000000";
    for (let i = 0; i < 5; i++) {
      await expect(service.verifyOtp(PHONE, wrong)).rejects.toThrow(/Invalid or expired/);
    }
    // 6th attempt is blocked even with the CORRECT code.
    await expect(service.verifyOtp(PHONE, devCode!)).rejects.toThrow(/Too many attempts/);
  });

  describe("expiry", () => {
    beforeEach(() => vi.useFakeTimers());
    afterEach(() => vi.useRealTimers());

    it("rejects codes older than OTP_TTL", async () => {
      const { service, config } = makeService();
      const { devCode } = await service.requestOtp(PHONE);
      vi.advanceTimersByTime((config.OTP_TTL + 1) * 1000);
      await expect(service.verifyOtp(PHONE, devCode!)).rejects.toThrow(/Invalid or expired/);
    });
  });
});
