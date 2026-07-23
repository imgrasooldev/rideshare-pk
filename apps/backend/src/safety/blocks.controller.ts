import { Body, Controller, Delete, Get, HttpCode, Param, Post, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { parse } from "../shared/validation.js";
import { BlocksService } from "./blocks.service.js";

const blockDto = z.object({ reason: z.string().trim().max(200).optional() });

@Controller("blocks")
@UseGuards(JwtAuthGuard)
export class BlocksController {
  constructor(private readonly blocks: BlocksService) {}

  /** People this user has blocked. */
  @Get()
  list(@Req() req: AuthedRequest) {
    return this.blocks.list(req.user.sub);
  }

  @Post(":userId")
  @HttpCode(200)
  block(@Req() req: AuthedRequest, @Param("userId") userId: string, @Body() body: unknown) {
    const dto = parse(blockDto, body ?? {});
    return this.blocks.block(req.user.sub, userId, dto.reason);
  }

  @Delete(":userId")
  unblock(@Req() req: AuthedRequest, @Param("userId") userId: string) {
    return this.blocks.unblock(req.user.sub, userId);
  }
}
