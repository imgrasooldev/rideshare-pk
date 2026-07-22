import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { AdminGuard } from "../trust/admin.guard.js";
import { DisputesController } from "./disputes.controller.js";
import { DisputesService } from "./disputes.service.js";

@Module({
  imports: [AuthModule], // exports TokenService (needed by AdminGuard) + JwtAuthGuard
  controllers: [DisputesController],
  providers: [DisputesService, AdminGuard]
})
export class DisputesModule {}
