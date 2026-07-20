import { Body, Controller, HttpCode, Inject, Post, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { SAFETY_REPOSITORY, USER_REPOSITORY } from "../shared/tokens.js";
import { parse } from "../shared/validation.js";
import type { UserRepository } from "../users/users.repo.js";
import type { SafetyRepository } from "./safety.repo.js";

const sosDto = z.object({
  rideId: z.string().optional(),
  lat: z.number().min(-90).max(90).optional(),
  lng: z.number().min(-180).max(180).optional()
});

@Controller("safety")
@UseGuards(JwtAuthGuard)
export class SafetyController {
  constructor(
    @Inject(SAFETY_REPOSITORY) private readonly safety: SafetyRepository,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository
  ) {}

  /**
   * SOS: Phase 1 = durable log + tell the app whether an emergency contact is
   * on file. Real escalation (SMS to the contact) lands with the SMS provider
   * in the notifications module.
   */
  @Post("sos")
  @HttpCode(200)
  async sos(@Req() req: AuthedRequest, @Body() body: unknown) {
    const dto = parse(sosDto, body);
    const event = await this.safety.logSos(
      req.user.sub,
      dto.rideId ?? null,
      dto.lat ?? null,
      dto.lng ?? null
    );
    const user = await this.users.findById(req.user.sub);
    return {
      logged: true,
      eventId: event.id,
      emergencyContactOnFile: Boolean(user?.emergencyPhone)
    };
  }
}
