import { Body, Controller, HttpCode, Inject, Post, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { DOCUMENT_STORAGE } from "../shared/tokens.js";
import { parse } from "../shared/validation.js";
import { ALLOWED_DOC_TYPES, type DocumentStorage } from "./storage.provider.js";

const signDto = z.object({
  purpose: z.enum(["cnic", "license", "vehicle"]),
  contentType: z.enum(ALLOWED_DOC_TYPES as [string, ...string[]])
});

@Controller("uploads")
@UseGuards(JwtAuthGuard)
export class UploadsController {
  constructor(@Inject(DOCUMENT_STORAGE) private readonly storage: DocumentStorage) {}

  /**
   * Hands the app a short-lived signed URL so the photo goes straight to
   * storage. The returned `key` is what gets submitted to /verifications.
   */
  @Post("sign")
  @HttpCode(200)
  sign(@Req() req: AuthedRequest, @Body() body: unknown) {
    const dto = parse(signDto, body);
    return this.storage.createUploadUrl(req.user.sub, dto.purpose, dto.contentType);
  }
}
