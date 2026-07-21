import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { EarningsController } from "./earnings.controller.js";
import { EarningsService } from "./earnings.service.js";

@Module({
  imports: [AuthModule],
  controllers: [EarningsController],
  providers: [EarningsService]
})
export class EarningsModule {}
