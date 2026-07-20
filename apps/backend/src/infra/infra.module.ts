import { Global, Module } from "@nestjs/common";
import { Pool } from "pg";
import { loadConfig, type AppConfig } from "../config/config.js";
import { InMemoryKvStore } from "../shared/kv.js";
import { RedisKvStore } from "../shared/redis-kv.js";
import { InMemoryIdentityRepository, PgIdentityRepository } from "../auth/identities.repo.js";
import { InMemoryBookingRepository, PgBookingRepository } from "../bookings/bookings.repo.js";
import { InMemoryRatingRepository, PgRatingRepository } from "../ratings/ratings.repo.js";
import { InMemoryRideRepository, PgRideRepository } from "../rides/rides.repo.js";
import { InMemoryBus, RedisBus } from "../shared/bus.js";
import {
  APP_CONFIG,
  BOOKING_REPOSITORY,
  BUS,
  IDENTITY_REPOSITORY,
  KV_STORE,
  PG_POOL,
  RATING_REPOSITORY,
  RIDE_REPOSITORY,
  SAFETY_REPOSITORY,
  TRIP_REPOSITORY,
  USER_REPOSITORY,
  VEHICLE_REPOSITORY,
  VERIFICATION_REPOSITORY
} from "../shared/tokens.js";
import { InMemoryTripRepository, PgTripRepository } from "../tracking/trips.repo.js";
import { InMemorySafetyRepository, PgSafetyRepository } from "../trust/safety.repo.js";
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
    },
    {
      provide: TRIP_REPOSITORY,
      inject: [PG_POOL],
      useFactory: (pool: Pool | null) =>
        pool ? new PgTripRepository(pool) : new InMemoryTripRepository()
    },
    {
      provide: RATING_REPOSITORY,
      inject: [PG_POOL],
      useFactory: (pool: Pool | null) =>
        pool ? new PgRatingRepository(pool) : new InMemoryRatingRepository()
    },
    {
      provide: SAFETY_REPOSITORY,
      inject: [PG_POOL],
      useFactory: (pool: Pool | null) =>
        pool ? new PgSafetyRepository(pool) : new InMemorySafetyRepository()
    },
    {
      provide: IDENTITY_REPOSITORY,
      inject: [PG_POOL],
      useFactory: (pool: Pool | null) =>
        pool ? new PgIdentityRepository(pool) : new InMemoryIdentityRepository()
    },
    {
      provide: BUS,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) => {
        if (config.REDIS_URL) return new RedisBus(config.REDIS_URL);
        console.warn("REDIS_URL not set — using in-process pub/sub (single instance only)");
        return new InMemoryBus();
      }
    }
  ],
  exports: [
    APP_CONFIG, KV_STORE, PG_POOL, BUS, IDENTITY_REPOSITORY,
    USER_REPOSITORY, VEHICLE_REPOSITORY, VERIFICATION_REPOSITORY, RIDE_REPOSITORY,
    BOOKING_REPOSITORY, TRIP_REPOSITORY, RATING_REPOSITORY, SAFETY_REPOSITORY
  ]
})
export class InfraModule {}
