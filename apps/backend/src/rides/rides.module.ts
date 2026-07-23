import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { PlacesModule } from "../places/places.module.js";
import { RidesController } from "./rides.controller.js";
import { RidesService } from "./rides.service.js";

@Module({
  imports: [AuthModule, PlacesModule],
  controllers: [RidesController],
  providers: [RidesService],
  exports: [RidesService]
})
export class RidesModule {}
