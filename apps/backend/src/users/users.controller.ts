import { Body, Controller, Get, Patch, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { parse } from "../shared/validation.js";
import { UsersService } from "./users.service.js";

const updateMeDto = z.object({
  name: z.string().trim().min(2).max(60).optional(),
  role: z.enum(["driver", "rider", "both"]).optional(),
  gender: z.enum(["female", "male", "other"]).optional(),
  cnic: z.string().min(13).max(15).optional(),
  emergencyPhone: z.string().min(10).max(20).optional()
});

@Controller("me")
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  me(@Req() req: AuthedRequest) {
    return this.users.getMe(req.user.sub);
  }

  @Patch()
  update(@Req() req: AuthedRequest, @Body() body: unknown) {
    return this.users.updateMe(req.user.sub, parse(updateMeDto, body));
  }
}
