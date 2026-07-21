import { existsSync } from "node:fs";
import { join } from "node:path";
import { Module } from "@nestjs/common";
import { ServeStaticModule } from "@nestjs/serve-static";
import { AuthModule } from "./auth/auth.module.js";
import { BookingsModule } from "./bookings/bookings.module.js";
import { EarningsModule } from "./earnings/earnings.module.js";
import { HealthModule } from "./health/health.module.js";
import { InfraModule } from "./infra/infra.module.js";
import { NotificationsModule } from "./notifications/notifications.module.js";
import { PlacesModule } from "./places/places.module.js";
import { RatingsModule } from "./ratings/ratings.module.js";
import { SubscriptionsModule } from "./subscriptions/subscriptions.module.js";
import { RidesModule } from "./rides/rides.module.js";
import { TrackingModule } from "./tracking/tracking.module.js";
import { TrustModule } from "./trust/trust.module.js";
import { UsersModule } from "./users/users.module.js";
import { VehiclesModule } from "./vehicles/vehicles.module.js";

// The admin console (apps/admin, Vite build) is served at /admin when present.
const adminDist = process.env.ADMIN_STATIC_DIR ?? join(process.cwd(), "..", "admin", "dist");

// Modular monolith: each domain (auth, users, rides, matching, bookings,
// tracking, notifications, trust, admin) gets its own module here and talks to
// the others only through exported service interfaces — never each other's tables.
@Module({
  imports: [
    ...(existsSync(adminDist)
      ? [ServeStaticModule.forRoot({ rootPath: adminDist, serveRoot: "/admin" })]
      : []),
    InfraModule, HealthModule, AuthModule, UsersModule,
    VehiclesModule, TrustModule, RidesModule, BookingsModule,
    TrackingModule, RatingsModule, PlacesModule, NotificationsModule,
    SubscriptionsModule, EarningsModule
  ]
})
export class AppModule {}
