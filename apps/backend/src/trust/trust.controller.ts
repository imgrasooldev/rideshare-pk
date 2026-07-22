import { Body, Controller, Get, Post, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { parse } from "../shared/validation.js";
import { TrustService } from "./trust.service.js";

// Either an uploaded document (docKey, from POST /uploads/sign) or, for
// backwards compatibility, an external link — but at least one of them.
const submitDto = z
  .object({
    type: z.enum(["cnic", "license", "vehicle"]),
    docUrl: z.string().url().max(500).optional(),
    docKey: z.string().min(3).max(300).optional(),
    vehicleId: z.string().optional()
  })
  .refine((v) => Boolean(v.docUrl || v.docKey), {
    message: "Attach a document: upload one (docKey) or provide a docUrl",
    path: ["docKey"]
  });

@Controller("verifications")
@UseGuards(JwtAuthGuard)
export class TrustController {
  constructor(private readonly trust: TrustService) {}

  @Post()
  submit(@Req() req: AuthedRequest, @Body() body: unknown) {
    const dto = parse(submitDto, body);
    return this.trust.submit(
      req.user.sub,
      dto.type,
      { docUrl: dto.docUrl ?? null, docKey: dto.docKey ?? null },
      dto.vehicleId
    );
  }

  @Get("mine")
  mine(@Req() req: AuthedRequest) {
    return this.trust.listMine(req.user.sub);
  }
}
