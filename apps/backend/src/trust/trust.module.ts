import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { AdminController } from "./admin.controller.js";
import { AdminGuard } from "./admin.guard.js";
import { TrustController } from "./trust.controller.js";
import { TrustService } from "./trust.service.js";

@Module({
  imports: [AuthModule],
  controllers: [TrustController, AdminController],
  providers: [TrustService, AdminGuard],
  exports: [TrustService]
})
export class TrustModule {}
