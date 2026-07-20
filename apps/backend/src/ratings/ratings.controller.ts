import { Body, Controller, Post, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { parse } from "../shared/validation.js";
import { RatingsService } from "./ratings.service.js";

const rateDto = z.object({
  rideId: z.string().min(1),
  toUserId: z.string().min(1),
  stars: z.number().int().min(1).max(5),
  comment: z.string().trim().max(500).optional()
});

@Controller("ratings")
@UseGuards(JwtAuthGuard)
export class RatingsController {
  constructor(private readonly ratings: RatingsService) {}

  @Post()
  rate(@Req() req: AuthedRequest, @Body() body: unknown) {
    const dto = parse(rateDto, body);
    return this.ratings.rate(req.user.sub, dto.rideId, dto.toUserId, dto.stars, dto.comment);
  }
}
