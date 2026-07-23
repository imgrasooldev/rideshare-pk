import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
// PARKED (money feature): commission settlement routes disabled for MVP —
// platform takes no commission. Service is kept so the routes can be restored
// (uncomment the controller) once payment gateways are live.
// import { WalletController } from "./wallet.controller.js";
import { WalletService } from "./wallet.service.js";

@Module({
  imports: [AuthModule],
  controllers: [/* PARKED: WalletController */],
  providers: [WalletService],
  exports: [WalletService]
})
export class WalletModule {}
