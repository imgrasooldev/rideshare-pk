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

const email = z.string().trim().toLowerCase().email().max(120);
const password = z.string().min(8, "password must be at least 8 characters").max(100);

const registerDto = z.object({
  name: z.string().trim().min(2).max(60).optional(),
  email,
  password
});
const loginDto = z.object({ email, password: z.string().min(1).max(100) });
const forgotDto = z.object({ email });
const resetDto = z.object({ token: z.string().min(20).max(100), password });
const googleDto = z.object({ idToken: z.string().min(20) });
const facebookDto = z.object({ accessToken: z.string().min(20) });

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

  @Post("register")
  async register(@Body() body: unknown) {
    const dto = parse(registerDto, body);
    return this.auth.register(dto.email, dto.password, dto.name ?? null);
  }

  @Post("login")
  @HttpCode(200)
  async login(@Body() body: unknown) {
    const dto = parse(loginDto, body);
    return this.auth.loginWithPassword(dto.email, dto.password);
  }

  @Post("password/forgot")
  @HttpCode(200)
  async forgot(@Body() body: unknown) {
    const dto = parse(forgotDto, body);
    const { devResetToken } = await this.auth.forgotPassword(dto.email);
    return {
      message: "If that email has an account, a reset link is on its way",
      ...(devResetToken ? { devResetToken } : {})
    };
  }

  @Post("password/reset")
  @HttpCode(200)
  async reset(@Body() body: unknown) {
    const dto = parse(resetDto, body);
    await this.auth.resetPassword(dto.token, dto.password);
    return { message: "Password updated — log in with your new password" };
  }

  @Post("oauth/google")
  @HttpCode(200)
  async google(@Body() body: unknown) {
    const dto = parse(googleDto, body);
    return this.auth.loginWithGoogle(dto.idToken);
  }

  @Post("oauth/facebook")
  @HttpCode(200)
  async facebook(@Body() body: unknown) {
    const dto = parse(facebookDto, body);
    return this.auth.loginWithFacebook(dto.accessToken);
  }
}
