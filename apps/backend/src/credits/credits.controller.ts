import { Body, Controller, Get, HttpCode, Post, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { parse } from "../shared/validation.js";
import { CreditsService } from "./credits.service.js";

const topupDto = z.object({
  amountRupees: z.number().int().positive().max(100_000)
});

@Controller("credits")
@UseGuards(JwtAuthGuard)
export class CreditsController {
  constructor(private readonly credits: CreditsService) {}

  @Get()
  async summary(@Req() req: AuthedRequest) {
    const [balance, entries] = await Promise.all([
      this.credits.balance(req.user.sub),
      this.credits.ledger(req.user.sub)
    ]);
    return { ...balance, entries };
  }

  @Get("ledger")
  ledger(@Req() req: AuthedRequest) {
    return this.credits.ledger(req.user.sub);
  }

  @Post("redeem-referrals")
  @HttpCode(200)
  redeemReferrals(@Req() req: AuthedRequest) {
    return this.credits.redeemReferrals(req.user.sub);
  }

  /**
   * Gateway-agnostic stub. No payment provider is wired yet, so we don't mint
   * money — we acknowledge the intent and return the current balance. When a
   * gateway (JazzCash / Easypaisa / Raast / card) is added, this endpoint
   * initiates the charge and credit lands only after the provider confirms.
   */
  @Post("topup")
  @HttpCode(200)
  async topup(@Req() req: AuthedRequest, @Body() body: unknown) {
    parse(topupDto, body);
    const balance = await this.credits.balance(req.user.sub);
    return {
      status: "unavailable" as const,
      message: "Online top-up is coming soon. You'll be able to add credit here.",
      ...balance
    };
  }
}
