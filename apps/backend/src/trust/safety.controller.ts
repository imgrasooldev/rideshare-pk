import { Body, Controller, HttpCode, Inject, Post, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import type { SmsSender } from "../auth/sms.js";
import { SAFETY_REPOSITORY, SMS_SENDER, USER_REPOSITORY } from "../shared/tokens.js";
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
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
    @Inject(SMS_SENDER) private readonly sms: SmsSender
  ) {}

  /**
   * SOS: durable log + best-effort SMS alert to the user's emergency contact
   * with their live location. The SMS is fire-and-forget — a delivery failure
   * (or dev mode) never fails the SOS itself.
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

    let contactAlerted = false;
    if (user?.emergencyPhone && this.sms.send) {
      const who = user.name ?? "Your contact";
      const where =
        dto.lat != null && dto.lng != null
          ? ` Live location: https://maps.google.com/?q=${dto.lat},${dto.lng}`
          : "";
      try {
        await this.sms.send(
          user.emergencyPhone,
          `SOS: ${who} triggered an emergency alert on Rideshare PK. Please check on them.${where}`
        );
        contactAlerted = true;
      } catch {
        /* best-effort — the SOS is already logged */
      }
    }

    return {
      logged: true,
      eventId: event.id,
      emergencyContactOnFile: Boolean(user?.emergencyPhone),
      contactAlerted
    };
  }
}
