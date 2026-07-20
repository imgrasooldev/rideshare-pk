import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { AdminController, AdminInsightsController } from "./admin.controller.js";
import { AdminGuard } from "./admin.guard.js";
import { SafetyController } from "./safety.controller.js";
import { TrustController } from "./trust.controller.js";
import { TrustService } from "./trust.service.js";

@Module({
  imports: [AuthModule],
  controllers: [TrustController, AdminController, AdminInsightsController, SafetyController],
  providers: [TrustService, AdminGuard],
  exports: [TrustService]
})
export class TrustModule {}
