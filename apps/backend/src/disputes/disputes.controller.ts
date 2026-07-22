import { Body, Controller, Get, HttpCode, Param, Post, Query, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { AdminGuard } from "../trust/admin.guard.js";
import { parse } from "../shared/validation.js";
import { DisputesService } from "./disputes.service.js";

const fileDto = z.object({
  bookingId: z.string().min(1).optional(),
  category: z.string().trim().min(2).max(60),
  message: z.string().trim().min(1).max(2000)
});

@Controller("disputes")
export class DisputesController {
  constructor(private readonly disputes: DisputesService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  file(@Req() req: AuthedRequest, @Body() body: unknown) {
    const dto = parse(fileDto, body);
    return this.disputes.file(req.user.sub, dto.category, dto.message, dto.bookingId);
  }

  @Get("mine")
  @UseGuards(JwtAuthGuard)
  mine(@Req() req: AuthedRequest) {
    return this.disputes.mine(req.user.sub);
  }

  // --- Admin queue ---

  @Get("admin")
  @UseGuards(AdminGuard)
  listOpen(@Query("limit") limit?: string) {
    return this.disputes.listOpen(Number(limit) || 100);
  }

  @Post(":id/resolve")
  @UseGuards(AdminGuard)
  @HttpCode(200)
  resolve(@Param("id") id: string, @Body() body: unknown) {
    const dto = parse(
      z.object({
        status: z.enum(["resolved", "dismissed"]).default("resolved"),
        resolution: z.string().trim().max(2000).optional()
      }),
      body
    );
    return this.disputes.resolve(id, dto.status, dto.resolution);
  }
}
