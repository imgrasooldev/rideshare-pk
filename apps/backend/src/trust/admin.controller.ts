import {
  Body,
  Controller,
  Get,
  HttpCode,
  Inject,
  Param,
  Post,
  Query,
  Req,
  UseGuards
} from "@nestjs/common";
import { z } from "zod";
import type { AuthedRequest } from "../auth/jwt-auth.guard.js";
import { ADMIN_INSIGHTS } from "../shared/tokens.js";
import { parse } from "../shared/validation.js";
import type { AdminInsightsRepository } from "./admin-insights.repo.js";
import { AdminGuard } from "./admin.guard.js";
import { TrustService } from "./trust.service.js";

const reviewDto = z.object({
  action: z.enum(["approve", "reject"]),
  notes: z.string().max(500).optional()
});

@Controller("admin")
@UseGuards(AdminGuard)
export class AdminInsightsController {
  constructor(@Inject(ADMIN_INSIGHTS) private readonly insights: AdminInsightsRepository) {}

  @Get("metrics")
  metrics() {
    return this.insights.metrics();
  }

  @Get("users")
  users(@Query("limit") limit?: string) {
    return this.insights.recentUsers(Math.min(Math.max(Number(limit) || 50, 1), 200));
  }

  @Get("rides")
  rides(@Query("limit") limit?: string) {
    return this.insights.recentRides(Math.min(Math.max(Number(limit) || 50, 1), 200));
  }
}

@Controller("admin/verifications")
@UseGuards(AdminGuard)
export class AdminController {
  constructor(private readonly trust: TrustService) {}

  @Get()
  queue(@Query("cursor") cursor?: string, @Query("limit") limit?: string) {
    const n = Math.min(Math.max(Number(limit) || 20, 1), 100);
    return this.trust.listPending(cursor ?? null, n);
  }

  @Post(":id")
  @HttpCode(200)
  review(@Req() req: AuthedRequest, @Param("id") id: string, @Body() body: unknown) {
    const dto = parse(reviewDto, body);
    return this.trust.review(id, dto.action, req.user.sub, dto.notes);
  }
}
