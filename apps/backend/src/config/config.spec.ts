import { describe, expect, it } from "vitest";
import { loadConfig } from "./config.js";

describe("loadConfig", () => {
  it("applies safe defaults for local dev", () => {
    const cfg = loadConfig({});
    expect(cfg.PORT).toBe(4000);
    expect(cfg.OTP_DEV_MODE).toBe(true);
    expect(cfg.MAPS_PROVIDER).toBe("osm");
    expect(cfg.FEATURE_PAYMENTS).toBe(false);
  });

  it("parses overrides from the environment", () => {
    const cfg = loadConfig({ PORT: "8080", MAPS_PROVIDER: "google", CITY_DEFAULT: "karachi" });
    expect(cfg.PORT).toBe(8080);
    expect(cfg.MAPS_PROVIDER).toBe("google");
    expect(cfg.CITY_DEFAULT).toBe("karachi");
  });

  it('parses boolean env strings correctly ("false" must mean false)', () => {
    const cfg = loadConfig({ OTP_DEV_MODE: "false", REQUIRE_DRIVER_VERIFICATION_TO_POST: "0" });
    expect(cfg.OTP_DEV_MODE).toBe(false);
    expect(cfg.REQUIRE_DRIVER_VERIFICATION_TO_POST).toBe(false);
    expect(loadConfig({ OTP_DEV_MODE: "true" }).OTP_DEV_MODE).toBe(true);
  });

  it("rejects malformed values instead of booting broken", () => {
    expect(() => loadConfig({ PORT: "not-a-port" })).toThrow(/Invalid environment/);
    expect(() => loadConfig({ MAPS_PROVIDER: "apple" })).toThrow(/Invalid environment/);
  });
});
