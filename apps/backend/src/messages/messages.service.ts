import { BadRequestException, Inject, Injectable } from "@nestjs/common";
import { MESSAGE_REPOSITORY } from "../shared/tokens.js";
import { NotificationsService } from "../notifications/notifications.service.js";
import type { MessageRecord, MessageRepository, ThreadSummary } from "./messages.repo.js";

@Injectable()
export class MessagesService {
  constructor(
    @Inject(MESSAGE_REPOSITORY) private readonly repo: MessageRepository,
    private readonly notifications: NotificationsService
  ) {}

  async send(senderId: string, rideId: string, recipientId: string, body: string): Promise<MessageRecord> {
    const clean = body.trim();
    if (!clean) throw new BadRequestException("Message cannot be empty");
    if (recipientId === senderId) throw new BadRequestException("Cannot message yourself");
    const msg = await this.repo.send(rideId, senderId, recipientId, clean);
    // Fire-and-forget push/notification to the recipient.
    await this.notifications.notify(
      recipientId,
      "message",
      "New message",
      clean.length > 80 ? `${clean.slice(0, 77)}…` : clean,
      { rideId, fromId: senderId }
    );
    return msg;
  }

  async thread(userId: string, rideId: string, otherId: string, limit: number): Promise<MessageRecord[]> {
    // Opening a thread marks the counterparty's messages as read.
    await this.repo.markThreadRead(rideId, userId, otherId);
    return this.repo.thread(rideId, userId, otherId, Math.min(Math.max(limit, 1), 200));
  }

  listThreads(userId: string): Promise<ThreadSummary[]> {
    return this.repo.listThreads(userId);
  }

  unread(userId: string): Promise<number> {
    return this.repo.unreadCount(userId);
  }
}
