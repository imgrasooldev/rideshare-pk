import { Body, Controller, Get, Post, Query, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { parse } from "../shared/validation.js";
import { WalletService } from "./wallet.service.js";

const settleDto = z.object({
  amount: z.number().int().positive().max(10_000_000),
  reference: z.string().trim().max(120).optional()
});

@Controller("wallet")
@UseGuards(JwtAuthGuard)
export class WalletController {
  constructor(private readonly wallet: WalletService) {}

  @Get()
  summary(@Req() req: AuthedRequest) {
    return this.wallet.summary(req.user.sub);
  }

  @Get("history")
  history(@Req() req: AuthedRequest, @Query("limit") limit?: string) {
    return this.wallet.history(req.user.sub, Number(limit) || 30);
  }

  @Post("settle")
  settle(@Req() req: AuthedRequest, @Body() body: unknown) {
    const dto = parse(settleDto, body);
    return this.wallet.settle(req.user.sub, dto.amount, dto.reference);
  }
}
