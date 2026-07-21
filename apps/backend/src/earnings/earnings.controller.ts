import { Controller, Get, Req, UseGuards } from "@nestjs/common";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { EarningsService } from "./earnings.service.js";

@Controller("earnings")
@UseGuards(JwtAuthGuard)
export class EarningsController {
  constructor(private readonly earnings: EarningsService) {}

  @Get()
  mine(@Req() req: AuthedRequest) {
    return this.earnings.forDriver(req.user.sub);
  }
}
