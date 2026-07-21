import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { NotificationsModule } from "../notifications/notifications.module.js";
import { BookingsController } from "./bookings.controller.js";
import { BookingsService } from "./bookings.service.js";

@Module({
  imports: [AuthModule, NotificationsModule],
  controllers: [BookingsController],
  providers: [BookingsService],
  exports: [BookingsService]
})
export class BookingsModule {}
