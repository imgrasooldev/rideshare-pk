import { ServiceUnavailableException } from "@nestjs/common";
import type { AppConfig } from "../config/config.js";

// SMS/WhatsApp delivery adapter (rule 9: provider is config, not code).
// Swapping VeevoTech -> Twilio -> anything else is an env change, never a
// code change. Dev mode logs the code so local/E2E flows work with no vendor.

export interface SmsSender {
  sendOtp(phone: string, code: string): Promise<void>;
  /** Generic transactional SMS (e.g. an SOS alert). Optional so lightweight
   *  test doubles need only implement sendOtp. */
  send?(phone: string, message: string): Promise<void>;
}

/** The text a user actually receives. Kept short — PK gateways bill per 160 chars. */
export function otpMessage(code: string, minutes: number): string {
  return `${code} is your Rideshare PK verification code. It expires in ${minutes} minutes. Never share this code with anyone.`;
}

/** Local/dev: never sends, just logs. The API also returns the code in dev mode. */
export class DevLogSmsSender implements SmsSender {
  async sendOtp(phone: string, code: string): Promise<void> {
    console.log(JSON.stringify({ level: "info", msg: "dev OTP (not sent)", phone, code }));
  }

  async send(phone: string, message: string): Promise<void> {
    console.log(JSON.stringify({ level: "info", msg: "dev SMS (not sent)", phone, message }));
  }
}

const SEND_TIMEOUT_MS = 10_000;

/** Never let a vendor's error text (which can echo the code) reach the client. */
function deliveryFailed(provider: string, detail: unknown): never {
  console.error(
    JSON.stringify({ level: "error", msg: "OTP delivery failed", provider, detail: String(detail) })
  );
  throw new ServiceUnavailableException(
    "Could not send the code right now. Please try again in a moment."
  );
}

/**
 * VeevoTech — widely used Pakistani SMS gateway. Auth is a per-account hash;
 * `sender_id` must be a mask approved by the operator (PTA-registered).
 */
export class VeevoTechSmsSender implements SmsSender {
  constructor(
    private readonly apiKey: string,
    private readonly senderId: string,
    private readonly ttlMinutes: number
  ) {}

  async sendOtp(phone: string, code: string): Promise<void> {
    return this.send(phone, otpMessage(code, this.ttlMinutes));
  }

  async send(phone: string, message: string): Promise<void> {
    // VeevoTech expects a local-format number (03xxxxxxxxx), not E.164.
    const receiver = phone.replace(/^\+92/, "0");
    const params = new URLSearchParams({
      hash: this.apiKey,
      receivenum: receiver,
      sender_id: this.senderId,
      textmessage: message
    });

    try {
      const res = await fetch("https://api.veevotech.com/v3/sendsms", {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: params.toString(),
        signal: AbortSignal.timeout(SEND_TIMEOUT_MS)
      });
      if (!res.ok) deliveryFailed("veevotech", `HTTP ${res.status}`);

      // VeevoTech returns 200 even on logical failures — inspect the payload.
      const body = (await res.json().catch(() => ({}))) as { STATUS?: string; MESSAGE?: string };
      const status = (body.STATUS ?? "").toUpperCase();
      if (status && !["SUCCESSFUL", "SUCCESS", "OK"].includes(status)) {
        deliveryFailed("veevotech", body.MESSAGE ?? status);
      }
    } catch (err) {
      if (err instanceof ServiceUnavailableException) throw err;
      deliveryFailed("veevotech", err);
    }
  }
}

/**
 * Twilio — SMS or WhatsApp depending on TWILIO_CHANNEL. WhatsApp is often the
 * cheaper/more reliable path in Pakistan; its templates must be pre-approved.
 */
export class TwilioSmsSender implements SmsSender {
  constructor(
    private readonly accountSid: string,
    private readonly authToken: string,
    private readonly from: string,
    private readonly channel: "sms" | "whatsapp",
    private readonly ttlMinutes: number
  ) {}

  async sendOtp(phone: string, code: string): Promise<void> {
    return this.send(phone, otpMessage(code, this.ttlMinutes));
  }

  async send(phone: string, message: string): Promise<void> {
    const prefix = this.channel === "whatsapp" ? "whatsapp:" : "";
    const body = new URLSearchParams({
      To: `${prefix}${phone}`,
      From: `${prefix}${this.from}`,
      Body: message
    });

    try {
      const res = await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${this.accountSid}/Messages.json`,
        {
          method: "POST",
          headers: {
            authorization: `Basic ${Buffer.from(`${this.accountSid}:${this.authToken}`).toString("base64")}`,
            "content-type": "application/x-www-form-urlencoded"
          },
          body: body.toString(),
          signal: AbortSignal.timeout(SEND_TIMEOUT_MS)
        }
      );
      if (!res.ok) {
        const detail = (await res.json().catch(() => ({}))) as { message?: string };
        deliveryFailed("twilio", detail.message ?? `HTTP ${res.status}`);
      }
    } catch (err) {
      if (err instanceof ServiceUnavailableException) throw err;
      deliveryFailed("twilio", err);
    }
  }
}

/**
 * Picks the sender from config. Falls back to dev logging (loudly) when a
 * provider is named but its credentials are missing, so a misconfigured
 * deploy degrades to "no SMS" instead of 500ing every signup.
 */
export function createSmsSender(config: AppConfig): SmsSender {
  const minutes = Math.max(1, Math.round(config.OTP_TTL / 60));

  switch (config.SMS_PROVIDER) {
    case "veevotech":
      if (!config.SMS_API_KEY) break;
      return new VeevoTechSmsSender(config.SMS_API_KEY, config.SMS_SENDER_ID, minutes);
    case "twilio":
      if (!config.TWILIO_ACCOUNT_SID || !config.TWILIO_AUTH_TOKEN || !config.TWILIO_FROM) break;
      return new TwilioSmsSender(
        config.TWILIO_ACCOUNT_SID,
        config.TWILIO_AUTH_TOKEN,
        config.TWILIO_FROM,
        config.TWILIO_CHANNEL,
        minutes
      );
    default:
      return new DevLogSmsSender();
  }

  console.warn(
    `SMS_PROVIDER="${config.SMS_PROVIDER}" is missing credentials — falling back to dev logging. ` +
      "Real OTPs will NOT be delivered."
  );
  return new DevLogSmsSender();
}
