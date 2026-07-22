import { Body, Controller, Get, HttpCode, Post, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { parse } from "../shared/validation.js";
import { ReferralsService } from "./referrals.service.js";

@Controller("referrals")
@UseGuards(JwtAuthGuard)
export class ReferralsController {
  constructor(private readonly referrals: ReferralsService) {}

  @Get("me")
  me(@Req() req: AuthedRequest) {
    return this.referrals.summary(req.user.sub);
  }

  @Post("apply")
  @HttpCode(200)
  apply(@Req() req: AuthedRequest, @Body() body: unknown) {
    const dto = parse(z.object({ code: z.string().trim().min(4).max(16) }), body);
    return this.referrals.apply(req.user.sub, dto.code);
  }
}
