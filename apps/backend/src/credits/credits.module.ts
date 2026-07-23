import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { CreditsController } from "./credits.controller.js";
import { CreditsService } from "./credits.service.js";

@Module({
  imports: [AuthModule],
  controllers: [CreditsController],
  providers: [CreditsService],
  exports: [CreditsService] // future: bookings debit fares, refunds credit back
})
export class CreditsModule {}
