import { Body, Controller, Get, Post, Query, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { parse } from "../shared/validation.js";
import { MessagesService } from "./messages.service.js";

const sendDto = z.object({
  rideId: z.string().min(1),
  recipientId: z.string().min(1),
  body: z.string().trim().min(1).max(2000)
});

const threadDto = z.object({
  rideId: z.string().min(1),
  otherId: z.string().min(1),
  limit: z.coerce.number().int().min(1).max(200).default(100)
});

@Controller("messages")
@UseGuards(JwtAuthGuard)
export class MessagesController {
  constructor(private readonly messages: MessagesService) {}

  @Post()
  send(@Req() req: AuthedRequest, @Body() body: unknown) {
    const dto = parse(sendDto, body);
    return this.messages.send(req.user.sub, dto.rideId, dto.recipientId, dto.body);
  }

  @Get("threads")
  threads(@Req() req: AuthedRequest) {
    return this.messages.listThreads(req.user.sub);
  }

  @Get("unread-count")
  async unread(@Req() req: AuthedRequest) {
    return { count: await this.messages.unread(req.user.sub) };
  }

  @Get("thread")
  thread(@Req() req: AuthedRequest, @Query() query: unknown) {
    const dto = parse(threadDto, query);
    return this.messages.thread(req.user.sub, dto.rideId, dto.otherId, dto.limit);
  }
}
