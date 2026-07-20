import { Global, Module } from "@nestjs/common";
import { Pool } from "pg";
import { loadConfig, type AppConfig } from "../config/config.js";
import { InMemoryKvStore } from "../shared/kv.js";
import { RedisKvStore } from "../shared/redis-kv.js";
import { InMemoryBookingRepository, PgBookingRepository } from "../bookings/bookings.repo.js";
import { InMemoryRideRepository, PgRideRepository } from "../rides/rides.repo.js";
import {
  APP_CONFIG,
  BOOKING_REPOSITORY,
  KV_STORE,
  PG_POOL,
  RIDE_REPOSITORY,
  USER_REPOSITORY,
  VEHICLE_REPOSITORY,
  VERIFICATION_REPOSITORY
} from "../shared/tokens.js";
import { InMemoryVerificationRepository, PgVerificationRepository } from "../trust/verifications.repo.js";
import { InMemoryUserRepository, PgUserRepository } from "../users/users.repo.js";
import { InMemoryVehicleRepository, PgVehicleRepository } from "../vehicles/vehicles.repo.js";

// Central wiring: real drivers when URLs are configured, in-memory fallbacks
// for zero-infra local dev. Production must always set both URLs.
@Global()
@Module({
  providers: [
    { provide: APP_CONFIG, useFactory: () => loadConfig() },
    {
      provide: KV_STORE,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) => {
        if (config.REDIS_URL) return new RedisKvStore(config.REDIS_URL);
        console.warn("REDIS_URL not set — using in-memory KV store (dev only)");
        return new InMemoryKvStore();
      }
    },
    {
      provide: PG_POOL,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) =>
        config.DATABASE_URL ? new Pool({ connectionString: config.DATABASE_URL, max: 10 }) : null
    },
    {
      provide: USER_REPOSITORY,
      inject: [PG_POOL],
      useFactory: (pool: Pool | null) => {
        if (pool) return new PgUserRepository(pool);
        console.warn("DATABASE_URL not set — using in-memory user store (dev only)");
        return new InMemoryUserRepository();
      }
    },
    {
      provide: VEHICLE_REPOSITORY,
      inject: [PG_POOL],
      useFactory: (pool: Pool | null) =>
        pool ? new PgVehicleRepository(pool) : new InMemoryVehicleRepository()
    },
    {
      provide: VERIFICATION_REPOSITORY,
      inject: [PG_POOL],
      useFactory: (pool: Pool | null) =>
        pool ? new PgVerificationRepository(pool) : new InMemoryVerificationRepository()
    },
    {
      provide: RIDE_REPOSITORY,
      inject: [PG_POOL],
      useFactory: (pool: Pool | null) =>
        pool ? new PgRideRepository(pool) : new InMemoryRideRepository()
    },
    {
      provide: BOOKING_REPOSITORY,
      inject: [PG_POOL, RIDE_REPOSITORY],
      useFactory: (pool: Pool | null, rides: InMemoryRideRepository) =>
        pool ? new PgBookingRepository(pool) : new InMemoryBookingRepository(rides)
    }
  ],
  exports: [
    APP_CONFIG, KV_STORE, PG_POOL,
    USER_REPOSITORY, VEHICLE_REPOSITORY, VERIFICATION_REPOSITORY, RIDE_REPOSITORY, BOOKING_REPOSITORY
  ]
})
export class InfraModule {}
