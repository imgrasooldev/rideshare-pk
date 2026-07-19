import { Module } from "@nestjs/common";
import { HealthModule } from "./health/health.module.js";

// Modular monolith: each domain (auth, users, rides, matching, bookings,
// tracking, notifications, trust, admin) gets its own module here and talks to
// the others only through exported service interfaces — never each other's tables.
@Module({
  imports: [HealthModule]
})
export class AppModule {}
