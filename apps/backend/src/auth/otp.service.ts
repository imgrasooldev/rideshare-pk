import { createHmac, randomInt, timingSafeEqual } from "node:crypto";
import {
  BadRequestException,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  UnauthorizedException
} from "@nestjs/common";
import type { AppConfig } from "../config/config.js";
import type { KeyValueStore } from "../shared/kv.js";
import { APP_CONFIG, KV_STORE, SMS_SENDER } from "../shared/tokens.js";
import { normalizePkPhone } from "./phone.js";
import type { SmsSender } from "./sms.js";

const VERIFY_ATTEMPT_LIMIT = 5; // a 6-digit code must not be brute-forceable

@Injectable()
export class OtpService {
  constructor(
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(KV_STORE) private readonly kv: KeyValueStore,
    @Inject(SMS_SENDER) private readonly sms: SmsSender
  ) {}

  /** Throws 400 on bad numbers so every caller shares one normalisation. */
  requirePkPhone(raw: string): string {
    const phone = normalizePkPhone(raw);
    if (!phone) {
      throw new BadRequestException("Enter a valid Pakistani mobile number (03XXXXXXXXX)");
    }
    return phone;
  }

  async requestOtp(rawPhone: string): Promise<{ devCode?: string }> {
    const phone = this.requirePkPhone(rawPhone);

    // OTP send is the true per-signup cost and an abuse vector — hard cap.
    const sends = await this.kv.incr(`otp:rl:${phone}`, 3600);
    if (sends > this.config.OTP_MAX_REQUESTS_PER_HOUR) {
      throw new HttpException(
        "Too many OTP requests for this number. Try again in an hour.",
        HttpStatus.TOO_MANY_REQUESTS
      );
    }

    const code = randomInt(0, 1_000_000).toString().padStart(6, "0");
    await this.kv.set(`otp:code:${phone}`, this.hash(phone, code), this.config.OTP_TTL);
    await this.kv.del(`otp:att:${phone}`);
    await this.sms.sendOtp(phone, code);

    // Dev mode surfaces the code in the response so local/E2E flows work
    // without an SMS provider. Never enabled in production.
    return this.config.OTP_DEV_MODE ? { devCode: code } : {};
  }

  /** Returns the normalised phone on success; throws otherwise. */
  async verifyOtp(rawPhone: string, code: string): Promise<string> {
    const phone = this.requirePkPhone(rawPhone);

    const attempts = await this.kv.incr(`otp:att:${phone}`, this.config.OTP_TTL);
    if (attempts > VERIFY_ATTEMPT_LIMIT) {
      throw new HttpException(
        "Too many attempts. Request a new code.",
        HttpStatus.TOO_MANY_REQUESTS
      );
    }

    const stored = await this.kv.get(`otp:code:${phone}`);
    if (!stored || !this.safeEqual(stored, this.hash(phone, code))) {
      throw new UnauthorizedException("Invalid or expired code");
    }

    await this.kv.del(`otp:code:${phone}`);
    await this.kv.del(`otp:att:${phone}`);
    return phone;
  }

  private hash(phone: string, code: string): string {
    // HMAC so a leaked KV snapshot doesn't expose live codes.
    return createHmac("sha256", this.config.JWT_ACCESS_SECRET).update(`${phone}:${code}`).digest("hex");
  }

  private safeEqual(a: string, b: string): boolean {
    const ba = Buffer.from(a);
    const bb = Buffer.from(b);
    return ba.length === bb.length && timingSafeEqual(ba, bb);
  }
}
