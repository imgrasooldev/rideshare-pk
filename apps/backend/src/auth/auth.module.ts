import { Module } from "@nestjs/common";
import { SMS_SENDER } from "../shared/tokens.js";
import { AuthController } from "./auth.controller.js";
import { AuthService } from "./auth.service.js";
import { JwtAuthGuard } from "./jwt-auth.guard.js";
import { OtpService } from "./otp.service.js";
import { DevLogSmsSender } from "./sms.js";
import { TokenService } from "./token.service.js";

@Module({
  controllers: [AuthController],
  providers: [
    AuthService,
    OtpService,
    TokenService,
    JwtAuthGuard,
    // Real SMS aggregator adapter replaces this via config with the
    // notifications module (build step 7+).
    { provide: SMS_SENDER, useClass: DevLogSmsSender }
  ],
  exports: [TokenService, JwtAuthGuard]
})
export class AuthModule {}
