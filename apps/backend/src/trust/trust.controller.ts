import { Body, Controller, Get, Post, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { parse } from "../shared/validation.js";
import { TrustService } from "./trust.service.js";

const submitDto = z.object({
  type: z.enum(["cnic", "license", "vehicle"]),
  docUrl: z.string().url().max(500),
  vehicleId: z.string().optional()
});

@Controller("verifications")
@UseGuards(JwtAuthGuard)
export class TrustController {
  constructor(private readonly trust: TrustService) {}

  @Post()
  submit(@Req() req: AuthedRequest, @Body() body: unknown) {
    const dto = parse(submitDto, body);
    return this.trust.submit(req.user.sub, dto.type, dto.docUrl, dto.vehicleId);
  }

  @Get("mine")
  mine(@Req() req: AuthedRequest) {
    return this.trust.listMine(req.user.sub);
  }
}
