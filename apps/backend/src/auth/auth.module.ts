import { Module } from "@nestjs/common";
import type { AppConfig } from "../config/config.js";
import { APP_CONFIG, OAUTH_VERIFIER, SMS_SENDER } from "../shared/tokens.js";
import { AuthController } from "./auth.controller.js";
import { AuthService } from "./auth.service.js";
import { JwtAuthGuard } from "./jwt-auth.guard.js";
import { RealOAuthVerifier } from "./oauth.verifier.js";
import { OtpService } from "./otp.service.js";
import { createSmsSender } from "./sms.js";
import { TokenService } from "./token.service.js";

@Module({
  controllers: [AuthController],
  providers: [
    AuthService,
    OtpService,
    TokenService,
    JwtAuthGuard,
    // Provider chosen by SMS_PROVIDER at boot (dev | veevotech | twilio).
    {
      provide: SMS_SENDER,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) => createSmsSender(config)
    },
    {
      provide: OAUTH_VERIFIER,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) => new RealOAuthVerifier(config)
    }
  ],
  exports: [TokenService, JwtAuthGuard, SMS_SENDER]
})
export class AuthModule {}
