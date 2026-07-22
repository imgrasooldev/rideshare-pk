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
import type { AppConfig } from "../config/config.js";
import { ADMIN_INSIGHTS, APP_CONFIG } from "../shared/tokens.js";
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

  @Get("timeseries")
  timeseries(@Query("days") days?: string) {
    return this.insights.timeseries(Math.min(Math.max(Number(days) || 14, 7), 90));
  }
}

@Controller("admin/verifications")
@UseGuards(AdminGuard)
export class AdminController {
  constructor(
    private readonly trust: TrustService,
    @Inject(APP_CONFIG) private readonly config: AppConfig
  ) {}

  @Get()
  queue(@Query("cursor") cursor?: string, @Query("limit") limit?: string) {
    const n = Math.min(Math.max(Number(limit) || 20, 1), 100);
    return this.trust.listPending(cursor ?? null, n);
  }

  /**
   * Short-lived signed URL so a reviewer can open a private document.
   * Minted per request and never stored — the bucket stays private.
   */
  @Get(":id/document")
  document(@Param("id") id: string) {
    return this.trust.documentUrl(id, this.config.DOC_VIEW_TTL);
  }

  @Post(":id")
  @HttpCode(200)
  review(@Req() req: AuthedRequest, @Param("id") id: string, @Body() body: unknown) {
    const dto = parse(reviewDto, body);
    return this.trust.review(id, dto.action, req.user.sub, dto.notes);
  }
}
