import { Global, Module } from "@nestjs/common";
import { Pool } from "pg";
import { loadConfig, type AppConfig } from "../config/config.js";
import { InMemoryKvStore } from "../shared/kv.js";
import { RedisKvStore } from "../shared/redis-kv.js";
import { APP_CONFIG, KV_STORE, PG_POOL, USER_REPOSITORY } from "../shared/tokens.js";
import { InMemoryUserRepository, PgUserRepository } from "../users/users.repo.js";

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
    }
  ],
  exports: [APP_CONFIG, KV_STORE, PG_POOL, USER_REPOSITORY]
})
export class InfraModule {}
