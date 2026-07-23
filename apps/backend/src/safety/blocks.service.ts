import { BadRequestException, Inject, Injectable, NotFoundException } from "@nestjs/common";
import { BLOCKS_REPOSITORY, USER_REPOSITORY } from "../shared/tokens.js";
import type { UserRepository } from "../users/users.repo.js";
import type { BlockedUser, BlocksRepository } from "./blocks.repo.js";

@Injectable()
export class BlocksService {
  constructor(
    @Inject(BLOCKS_REPOSITORY) private readonly blocks: BlocksRepository,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository
  ) {}

  async block(blockerId: string, blockedId: string, reason?: string): Promise<{ blocked: true }> {
    if (blockerId === blockedId) {
      throw new BadRequestException("You cannot block yourself");
    }
    if (!(await this.users.findById(blockedId))) {
      throw new NotFoundException("That user does not exist");
    }
    await this.blocks.block(blockerId, blockedId, reason ?? null);
    return { blocked: true };
  }

  async unblock(blockerId: string, blockedId: string): Promise<{ blocked: false }> {
    await this.blocks.unblock(blockerId, blockedId);
    return { blocked: false };
  }

  list(blockerId: string): Promise<BlockedUser[]> {
    return this.blocks.list(blockerId);
  }
}
