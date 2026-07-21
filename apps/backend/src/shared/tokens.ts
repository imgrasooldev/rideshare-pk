// DI tokens. Modules depend on these interfaces, never on concrete drivers,
// so infra (Redis vs memory, Postgres vs memory) is a wiring decision.
export const APP_CONFIG = Symbol("APP_CONFIG");
export const KV_STORE = Symbol("KV_STORE");
export const USER_REPOSITORY = Symbol("USER_REPOSITORY");
export const VEHICLE_REPOSITORY = Symbol("VEHICLE_REPOSITORY");
export const VERIFICATION_REPOSITORY = Symbol("VERIFICATION_REPOSITORY");
export const RIDE_REPOSITORY = Symbol("RIDE_REPOSITORY");
export const BOOKING_REPOSITORY = Symbol("BOOKING_REPOSITORY");
export const TRIP_REPOSITORY = Symbol("TRIP_REPOSITORY");
export const RATING_REPOSITORY = Symbol("RATING_REPOSITORY");
export const SAFETY_REPOSITORY = Symbol("SAFETY_REPOSITORY");
export const BUS = Symbol("BUS");
export const IDENTITY_REPOSITORY = Symbol("IDENTITY_REPOSITORY");
export const OAUTH_VERIFIER = Symbol("OAUTH_VERIFIER");
export const ADMIN_INSIGHTS = Symbol("ADMIN_INSIGHTS");
export const SMS_SENDER = Symbol("SMS_SENDER");
export const PG_POOL = Symbol("PG_POOL");
export const NOTIFICATION_REPOSITORY = Symbol("NOTIFICATION_REPOSITORY");
