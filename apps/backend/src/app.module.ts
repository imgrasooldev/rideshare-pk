import { Module } from "@nestjs/common";
import { AuthModule } from "./auth/auth.module.js";
import { BookingsModule } from "./bookings/bookings.module.js";
import { HealthModule } from "./health/health.module.js";
import { InfraModule } from "./infra/infra.module.js";
import { RatingsModule } from "./ratings/ratings.module.js";
import { RidesModule } from "./rides/rides.module.js";
import { TrackingModule } from "./tracking/tracking.module.js";
import { TrustModule } from "./trust/trust.module.js";
import { UsersModule } from "./users/users.module.js";
import { VehiclesModule } from "./vehicles/vehicles.module.js";

// Modular monolith: each domain (auth, users, rides, matching, bookings,
// tracking, notifications, trust, admin) gets its own module here and talks to
// the others only through exported service interfaces — never each other's tables.
@Module({
  imports: [
    InfraModule, HealthModule, AuthModule, UsersModule,
    VehiclesModule, TrustModule, RidesModule, BookingsModule,
    TrackingModule, RatingsModule
  ]
})
export class AppModule {}
