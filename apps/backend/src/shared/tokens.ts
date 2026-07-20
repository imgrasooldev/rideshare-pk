// DI tokens. Modules depend on these interfaces, never on concrete drivers,
// so infra (Redis vs memory, Postgres vs memory) is a wiring decision.
export const APP_CONFIG = Symbol("APP_CONFIG");
export const KV_STORE = Symbol("KV_STORE");
export const USER_REPOSITORY = Symbol("USER_REPOSITORY");
export const VEHICLE_REPOSITORY = Symbol("VEHICLE_REPOSITORY");
export const VERIFICATION_REPOSITORY = Symbol("VERIFICATION_REPOSITORY");
export const SMS_SENDER = Symbol("SMS_SENDER");
export const PG_POOL = Symbol("PG_POOL");
