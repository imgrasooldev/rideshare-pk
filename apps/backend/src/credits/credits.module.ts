import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
// PARKED (money feature): rider credit wallet routes disabled for MVP —
// platform handles no money. Service is kept so the routes can be restored
// (uncomment the controller) once payment gateways are live.
// import { CreditsController } from "./credits.controller.js";
import { CreditsService } from "./credits.service.js";

@Module({
  imports: [AuthModule],
  controllers: [/* PARKED: CreditsController */],
  providers: [CreditsService],
  exports: [CreditsService] // future: bookings debit fares, refunds credit back
})
export class CreditsModule {}
