import { z } from "zod";

// Every runtime knob lives here (rule 9: config over code). Fail fast on boot
// if the environment is malformed rather than at first use.
const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().positive().default(4000),
  DATABASE_URL: z.string().default("postgresql://rideshare:rideshare@localhost:5432/rideshare"),
  REDIS_URL: z.string().default("redis://localhost:6379"),

  JWT_ACCESS_SECRET: z.string().default("dev-only-secret"),
  JWT_REFRESH_SECRET: z.string().default("dev-only-secret-2"),
  JWT_ACCESS_TTL: z.coerce.number().int().positive().default(900),
  JWT_REFRESH_TTL: z.coerce.number().int().positive().default(2_592_000),

  OTP_TTL: z.coerce.number().int().positive().default(300),
  OTP_MAX_REQUESTS_PER_HOUR: z.coerce.number().int().positive().default(3),
  OTP_DEV_MODE: z.coerce.boolean().default(true),

  MAPS_PROVIDER: z.enum(["osm", "google"]).default("osm"),
  CITY_DEFAULT: z.string().default("lahore"),

  FEATURE_BOOKING_ACCEPT_DECLINE: z.coerce.boolean().default(false),
  FEATURE_PAYMENTS: z.coerce.boolean().default(false),
  FEATURE_LADIES_ONLY: z.coerce.boolean().default(true),
  REQUIRE_DRIVER_VERIFICATION_TO_POST: z.coerce.boolean().default(true),
  BOOKING_FEE_PKR: z.coerce.number().int().min(0).default(0),

  LOG_LEVEL: z.enum(["debug", "info", "warn", "error"]).default("info")
});

export type AppConfig = z.infer<typeof envSchema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = envSchema.safeParse(env);
  if (!parsed.success) {
    throw new Error(`Invalid environment: ${parsed.error.message}`);
  }
  return parsed.data;
}
