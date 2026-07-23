import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { NotificationsModule } from "../notifications/notifications.module.js";
import { TrackingGateway } from "./tracking.gateway.js";
import { TrackingService } from "./tracking.service.js";
import { TripsController } from "./trips.controller.js";

@Module({
  imports: [AuthModule, NotificationsModule],
  controllers: [TripsController],
  providers: [TrackingService, TrackingGateway],
  exports: [TrackingService]
})
export class TrackingModule {}
