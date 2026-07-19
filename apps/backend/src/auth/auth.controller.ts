import { BadRequestException, Body, Controller, HttpCode, Post } from "@nestjs/common";
import { z } from "zod";
import { AuthService } from "./auth.service.js";
import { OtpService } from "./otp.service.js";

const otpRequestDto = z.object({ phone: z.string().min(10).max(20) });
const otpVerifyDto = z.object({
  phone: z.string().min(10).max(20),
  code: z.string().regex(/^\d{6}$/, "code must be 6 digits")
});
const refreshDto = z.object({ refreshToken: z.string().min(20) });

function parse<T>(schema: z.ZodType<T>, body: unknown): T {
  const result = schema.safeParse(body);
  if (!result.success) {
    throw new BadRequestException({
      error: "validation_error",
      message: "Invalid request body",
      details: result.error.flatten().fieldErrors
    });
  }
  return result.data;
}

@Controller("auth")
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly otp: OtpService
  ) {}

  @Post("otp/request")
  @HttpCode(200)
  async requestOtp(@Body() body: unknown) {
    const { phone } = parse(otpRequestDto, body);
    const { devCode } = await this.otp.requestOtp(phone);
    return { message: "OTP sent", ...(devCode ? { devCode } : {}) };
  }

  @Post("otp/verify")
  @HttpCode(200)
  async verifyOtp(@Body() body: unknown) {
    const { phone, code } = parse(otpVerifyDto, body);
    return this.auth.loginWithOtp(phone, code);
  }

  @Post("refresh")
  @HttpCode(200)
  async refresh(@Body() body: unknown) {
    const { refreshToken } = parse(refreshDto, body);
    return this.auth.refresh(refreshToken);
  }
}
