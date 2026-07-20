import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { VehiclesController } from "./vehicles.controller.js";

@Module({
  imports: [AuthModule],
  controllers: [VehiclesController]
})
export class VehiclesModule {}
