import { Controller, Get, HttpCode, Param, Post, Query, Req, UseGuards } from "@nestjs/common";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { NotificationsService } from "./notifications.service.js";

@Controller("notifications")
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  async list(@Req() req: AuthedRequest, @Query("limit") limit?: string) {
    const n = Math.min(Math.max(Number(limit) || 30, 1), 100);
    const [items, unread] = await Promise.all([
      this.notifications.list(req.user.sub, n),
      this.notifications.unread(req.user.sub)
    ]);
    return { items, unread };
  }

  @Post("read-all")
  @HttpCode(200)
  async readAll(@Req() req: AuthedRequest) {
    await this.notifications.markAllRead(req.user.sub);
    return { ok: true };
  }

  @Post(":id/read")
  @HttpCode(200)
  async read(@Req() req: AuthedRequest, @Param("id") id: string) {
    await this.notifications.markRead(id, req.user.sub);
    return { ok: true };
  }
}
