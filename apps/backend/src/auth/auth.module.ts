import { Module } from "@nestjs/common";
import type { AppConfig } from "../config/config.js";
import { APP_CONFIG, OAUTH_VERIFIER, SMS_SENDER } from "../shared/tokens.js";
import { AuthController } from "./auth.controller.js";
import { AuthService } from "./auth.service.js";
import { JwtAuthGuard } from "./jwt-auth.guard.js";
import { RealOAuthVerifier } from "./oauth.verifier.js";
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
    { provide: SMS_SENDER, useClass: DevLogSmsSender },
    {
      provide: OAUTH_VERIFIER,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) => new RealOAuthVerifier(config)
    }
  ],
  exports: [TokenService, JwtAuthGuard]
})
export class AuthModule {}
