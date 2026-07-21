import { Inject, Injectable } from "@nestjs/common";
import { NOTIFICATION_REPOSITORY } from "../shared/tokens.js";
import type { NotificationRecord, NotificationRepository } from "./notifications.repo.js";

@Injectable()
export class NotificationsService {
  constructor(
    @Inject(NOTIFICATION_REPOSITORY) private readonly repo: NotificationRepository
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
      // FCM push delivery hooks in here once a service account is configured.
    } catch {
      /* swallow */
    }
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
