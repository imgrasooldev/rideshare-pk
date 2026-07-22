import { z } from "zod";

// z.coerce.boolean() would treat "false" as true (non-empty string); env
// booleans need real string semantics.
const envBool = (def: boolean) =>
  z.preprocess(
    (v) => (typeof v === "string" ? !["false", "0", "no", "off", ""].includes(v.toLowerCase()) : v),
    z.boolean().default(def)
  );

// Every runtime knob lives here (rule 9: config over code). Fail fast on boot
// if the environment is malformed rather than at first use.
const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().positive().default(4000),
  // Empty string = in-memory dev driver (single instance only, data lost on
  // restart). Set real URLs for anything beyond local experimentation.
  DATABASE_URL: z.string().default(""),
  REDIS_URL: z.string().default(""),

  JWT_ACCESS_SECRET: z.string().default("dev-only-secret"),
  JWT_REFRESH_SECRET: z.string().default("dev-only-secret-2"),
  JWT_ACCESS_TTL: z.coerce.number().int().positive().default(900),
  JWT_REFRESH_TTL: z.coerce.number().int().positive().default(2_592_000),

  CNIC_ENC_KEY: z.string().default("dev-only-cnic-key"),

  // Social sign-in (empty = provider disabled; endpoint returns 503)
  GOOGLE_CLIENT_ID: z.string().default(""),
  FB_APP_ID: z.string().default(""),
  FB_APP_SECRET: z.string().default(""),

  OTP_TTL: z.coerce.number().int().positive().default(300),
  OTP_MAX_REQUESTS_PER_HOUR: z.coerce.number().int().positive().default(3),
  // true = OTP is logged and echoed in the API response (local/E2E only).
  // MUST be false in production once a real SMS provider is configured.
  OTP_DEV_MODE: envBool(true),

  // OTP delivery. "dev" logs only; the others need their credentials below,
  // and fall back to logging (with a warning) if those are missing.
  SMS_PROVIDER: z.enum(["dev", "veevotech", "twilio"]).default("dev"),
  SMS_API_KEY: z.string().default(""), // VeevoTech account hash
  SMS_SENDER_ID: z.string().default("RideshrPK"), // PTA-approved sender mask
  TWILIO_ACCOUNT_SID: z.string().default(""),
  TWILIO_AUTH_TOKEN: z.string().default(""),
  TWILIO_FROM: z.string().default(""),
  TWILIO_CHANNEL: z.enum(["sms", "whatsapp"]).default("sms"),

  // Verification document storage. "none" = uploads disabled (503).
  // The bucket MUST be private — these are CNIC/licence photos.
  STORAGE_PROVIDER: z.enum(["none", "supabase"]).default("none"),
  SUPABASE_URL: z.string().default(""), // https://<project-ref>.supabase.co
  SUPABASE_SERVICE_KEY: z.string().default(""), // service_role key, server-side only
  STORAGE_BUCKET: z.string().default("verification-docs"),
  DOC_VIEW_TTL: z.coerce.number().int().positive().default(300),

  MAPS_PROVIDER: z.enum(["osm", "google"]).default("osm"),
  CITY_DEFAULT: z.string().default("lahore"),

  FEATURE_BOOKING_ACCEPT_DECLINE: envBool(false),
  FEATURE_PAYMENTS: envBool(false),
  FEATURE_LADIES_ONLY: envBool(true),
  REQUIRE_DRIVER_VERIFICATION_TO_POST: envBool(true),
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
