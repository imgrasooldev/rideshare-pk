import { Inject, Injectable } from "@nestjs/common";
import { NOTIFICATION_REPOSITORY } from "../shared/tokens.js";
import { PushService } from "../push/push.service.js";
import type { NotificationRecord, NotificationRepository } from "./notifications.repo.js";

@Injectable()
export class NotificationsService {
  constructor(
    @Inject(NOTIFICATION_REPOSITORY) private readonly repo: NotificationRepository,
    private readonly push: PushService
  ) {}

  /** Fire-and-forget: a notification failure must never break the source action. */
  async notify(
    userId: string,
    type: string,
    title: string,
    body: string,
    data: Record<string, unknown> = {}
  ): Promise<void> {
    try {
      await this.repo.create(userId, type, title, body, data);
    } catch {
      /* swallow */
    }
    // Best-effort push (no-op until a Firebase service account is configured).
    const stringData: Record<string, string> = { type };
    for (const [k, v] of Object.entries(data)) stringData[k] = String(v);
    void this.push.sendToUser(userId, title, body, stringData);
  }

  list(userId: string, limit: number): Promise<NotificationRecord[]> {
    return this.repo.listForUser(userId, Math.min(Math.max(limit, 1), 100));
  }

  unread(userId: string): Promise<number> {
    return this.repo.unreadCount(userId);
  }

  markRead(id: string, userId: string): Promise<void> {
    return this.repo.markRead(id, userId);
  }

  markAllRead(userId: string): Promise<void> {
    return this.repo.markAllRead(userId);
  }
}
