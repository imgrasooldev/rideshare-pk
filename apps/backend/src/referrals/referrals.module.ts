import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { ReferralsController } from "./referrals.controller.js";
import { ReferralsService } from "./referrals.service.js";

@Module({
  imports: [AuthModule],
  controllers: [ReferralsController],
  providers: [ReferralsService]
})
export class ReferralsModule {}
