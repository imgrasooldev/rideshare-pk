import { afterEach, describe, expect, it, vi } from "vitest";
import { loadConfig } from "../config/config.js";
import {
  DevLogSmsSender,
  TwilioSmsSender,
  VeevoTechSmsSender,
  createSmsSender,
  otpMessage
} from "./sms.js";

/** Captures the outgoing HTTP call so we can assert on the vendor contract. */
function stubFetch(response: { ok: boolean; status?: number; body?: unknown }) {
  const calls: Array<{ url: string; init: RequestInit }> = [];
  const fake = vi.fn(async (url: string | URL, init: RequestInit) => {
    calls.push({ url: String(url), init });
    return {
      ok: response.ok,
      status: response.status ?? (response.ok ? 200 : 500),
      json: async () => response.body ?? {}
    } as Response;
  });
  vi.stubGlobal("fetch", fake);
  return calls;
}

afterEach(() => vi.unstubAllGlobals());

describe("otpMessage", () => {
  it("includes the code, the expiry and a do-not-share warning", () => {
    const text = otpMessage("123456", 5);
    expect(text).toContain("123456");
    expect(text).toContain("5 minutes");
    expect(text.toLowerCase()).toContain("never share");
  });
});

describe("createSmsSender", () => {
  it("defaults to dev logging", () => {
    expect(createSmsSender(loadConfig({}))).toBeInstanceOf(DevLogSmsSender);
  });

  it("builds the configured provider when credentials are present", () => {
    const veevo = createSmsSender(
      loadConfig({ SMS_PROVIDER: "veevotech", SMS_API_KEY: "hash-123" })
    );
    expect(veevo).toBeInstanceOf(VeevoTechSmsSender);

    const twilio = createSmsSender(
      loadConfig({
        SMS_PROVIDER: "twilio",
        TWILIO_ACCOUNT_SID: "AC1",
        TWILIO_AUTH_TOKEN: "tok",
        TWILIO_FROM: "+15550000"
      })
    );
    expect(twilio).toBeInstanceOf(TwilioSmsSender);
  });

  it("degrades to dev logging (not a crash) when credentials are missing", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    // Provider named but no API key — a misconfigured deploy must not 500 signups.
    expect(createSmsSender(loadConfig({ SMS_PROVIDER: "veevotech" }))).toBeInstanceOf(
      DevLogSmsSender
    );
    expect(warn).toHaveBeenCalled();
    warn.mockRestore();
  });
});

describe("VeevoTechSmsSender", () => {
  it("posts a local-format number with the code", async () => {
    const calls = stubFetch({ ok: true, body: { STATUS: "SUCCESSFUL" } });
    await new VeevoTechSmsSender("hash-123", "RideshrPK", 5).sendOtp("+923001234567", "123456");

    expect(calls).toHaveLength(1);
    const body = String(calls[0]!.init.body);
    expect(calls[0]!.url).toContain("veevotech.com");
    expect(body).toContain("hash=hash-123");
    expect(body).toContain("receivenum=03001234567"); // +92 -> 0
    expect(decodeURIComponent(body)).toContain("123456");
  });

  it("treats a 200 with a failure STATUS as a failure, without leaking the code", async () => {
    stubFetch({ ok: true, body: { STATUS: "FAILED", MESSAGE: "invalid mask" } });
    const send = new VeevoTechSmsSender("hash-123", "RideshrPK", 5).sendOtp(
      "+923001234567",
      "123456"
    );
    await expect(send).rejects.toThrow(/try again/i);
    await expect(send).rejects.not.toThrow(/123456/);
  });
});

describe("TwilioSmsSender", () => {
  it("sends over SMS with basic auth", async () => {
    const calls = stubFetch({ ok: true });
    await new TwilioSmsSender("AC1", "tok", "+15550000", "sms", 5).sendOtp(
      "+923001234567",
      "123456"
    );

    const { url, init } = calls[0]!;
    expect(url).toContain("/Accounts/AC1/Messages.json");
    expect((init.headers as Record<string, string>).authorization).toBe(
      `Basic ${Buffer.from("AC1:tok").toString("base64")}`
    );
    expect(String(init.body)).toContain("To=%2B923001234567");
  });

  it("prefixes both numbers for the WhatsApp channel", async () => {
    const calls = stubFetch({ ok: true });
    await new TwilioSmsSender("AC1", "tok", "+15550000", "whatsapp", 5).sendOtp(
      "+923001234567",
      "123456"
    );

    const body = decodeURIComponent(String(calls[0]!.init.body));
    expect(body).toContain("To=whatsapp:+923001234567");
    expect(body).toContain("From=whatsapp:+15550000");
  });

  it("surfaces a generic error on vendor failure", async () => {
    stubFetch({ ok: false, status: 400, body: { message: "unverified number" } });
    await expect(
      new TwilioSmsSender("AC1", "tok", "+15550000", "sms", 5).sendOtp("+923001234567", "123456")
    ).rejects.toThrow(/try again/i);
  });
});
