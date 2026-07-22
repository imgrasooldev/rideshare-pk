import { Body, Controller, HttpCode, Post, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { parse } from "../shared/validation.js";
import { PushService } from "./push.service.js";

const registerDto = z.object({
  token: z.string().min(10).max(4096),
  platform: z.enum(["android", "ios", "web"]).default("android")
});

@Controller("devices")
@UseGuards(JwtAuthGuard)
export class PushController {
  constructor(private readonly push: PushService) {}

  @Post()
  @HttpCode(200)
  async register(@Req() req: AuthedRequest, @Body() body: unknown) {
    const dto = parse(registerDto, body);
    await this.push.register(req.user.sub, dto.token, dto.platform);
    return { registered: true };
  }
}
