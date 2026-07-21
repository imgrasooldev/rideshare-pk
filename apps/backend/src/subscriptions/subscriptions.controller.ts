import { Body, Controller, Get, HttpCode, Param, Post, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { parse } from "../shared/validation.js";
import { SubscriptionsService } from "./subscriptions.service.js";

const subscribeDto = z.object({
  rideId: z.string().min(1),
  seats: z.number().int().min(1).max(8).default(1)
});

@Controller("subscriptions")
@UseGuards(JwtAuthGuard)
export class SubscriptionsController {
  constructor(private readonly subscriptions: SubscriptionsService) {}

  @Post()
  subscribe(@Req() req: AuthedRequest, @Body() body: unknown) {
    const dto = parse(subscribeDto, body);
    return this.subscriptions.subscribe(req.user.sub, dto.rideId, dto.seats);
  }

  @Get("mine")
  mine(@Req() req: AuthedRequest) {
    return this.subscriptions.mine(req.user.sub);
  }

  @Post(":id/cancel")
  @HttpCode(200)
  cancel(@Req() req: AuthedRequest, @Param("id") id: string) {
    return this.subscriptions.cancel(id, req.user.sub);
  }
}
