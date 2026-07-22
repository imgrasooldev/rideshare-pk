import { Body, Controller, Get, HttpCode, Param, Post, Query, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { parse } from "../shared/validation.js";
import { BookingsService } from "./bookings.service.js";

const bookDto = z.object({
  rideId: z.string().min(1),
  seats: z.number().int().min(1).max(20).default(1),
  idempotencyKey: z.string().min(8).max(100)
});

const counterDto = z.object({ offeredPrice: z.number().int().min(0).max(100_000) });
const respondDto = z.object({ accept: z.boolean() });

@Controller("bookings")
@UseGuards(JwtAuthGuard)
export class BookingsController {
  constructor(private readonly bookings: BookingsService) {}

  @Post()
  book(@Req() req: AuthedRequest, @Body() body: unknown) {
    const dto = parse(bookDto, body);
    return this.bookings.book(req.user.sub, dto.rideId, dto.seats, dto.idempotencyKey);
  }

  @Get("mine")
  mine(@Req() req: AuthedRequest, @Query("cursor") cursor?: string, @Query("limit") limit?: string) {
    const n = Math.min(Math.max(Number(limit) || 20, 1), 50);
    return this.bookings.mine(req.user.sub, cursor ?? null, n);
  }

  /** Driver's dispatch inbox: open seat requests across their rides. */
  @Get("requests")
  requests(@Req() req: AuthedRequest, @Query("limit") limit?: string) {
    return this.bookings.requests(req.user.sub, Number(limit) || 50);
  }

  @Post(":id/accept")
  @HttpCode(200)
  accept(@Req() req: AuthedRequest, @Param("id") id: string) {
    return this.bookings.respond(req.user.sub, id, "accept");
  }

  @Post(":id/reject")
  @HttpCode(200)
  reject(@Req() req: AuthedRequest, @Param("id") id: string) {
    return this.bookings.respond(req.user.sub, id, "reject");
  }

  @Post(":id/counter")
  @HttpCode(200)
  counter(@Req() req: AuthedRequest, @Param("id") id: string, @Body() body: unknown) {
    const dto = parse(counterDto, body);
    return this.bookings.respond(req.user.sub, id, "counter", dto.offeredPrice);
  }

  /** Rider accepts/declines a driver counter-offer. */
  @Post(":id/respond")
  @HttpCode(200)
  respond(@Req() req: AuthedRequest, @Param("id") id: string, @Body() body: unknown) {
    const dto = parse(respondDto, body);
    return this.bookings.respondToCounter(req.user.sub, id, dto.accept);
  }

  @Post(":id/cancel")
  @HttpCode(200)
  cancel(@Req() req: AuthedRequest, @Param("id") id: string) {
    return this.bookings.cancel(id, req.user.sub);
  }
}
