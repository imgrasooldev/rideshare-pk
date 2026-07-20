import { beforeEach, describe, expect, it } from "vitest";
import { loadConfig } from "../config/config.js";
import { InMemoryUserRepository } from "./users.repo.js";
import { UsersService } from "./users.service.js";

describe("UsersService", () => {
  let repo: InMemoryUserRepository;
  let service: UsersService;
  let userId: string;

  beforeEach(async () => {
    repo = new InMemoryUserRepository();
    service = new UsersService(loadConfig({}), repo);
    userId = (await repo.upsertByPhone("+923001234567", "lahore")).id;
  });

  it("returns the profile with null cnic when unset", async () => {
    const me = await service.getMe(userId);
    expect(me.phone).toBe("+923001234567");
    expect(me.cnicMasked).toBeNull();
    expect(me.verified).toBe(false);
  });

  it("updates name/role/gender and encrypts + masks the CNIC", async () => {
    const me = await service.updateMe(userId, {
      name: "Ayesha Khan",
      role: "driver",
      gender: "female",
      cnic: "35202-1234567-1"
    });
    expect(me.name).toBe("Ayesha Khan");
    expect(me.role).toBe("driver");
    expect(me.cnicMasked).toBe("*********5671"); // last 4 of 3520212345671

    // Stored value is ciphertext, not the raw digits.
    const raw = await repo.findById(userId);
    expect(raw!.cnic).not.toContain("3520212345671");
    expect(raw!.cnic).not.toContain("35202");
  });

  it("rejects malformed CNICs", async () => {
    await expect(service.updateMe(userId, { cnic: "12345" })).rejects.toThrow(/13 digits/);
    await expect(service.updateMe(userId, { cnic: "35202-1234567-1X" })).rejects.toThrow(/13 digits/);
  });

  it("leaves unspecified fields untouched", async () => {
    await service.updateMe(userId, { name: "GR" });
    const me = await service.updateMe(userId, { role: "both" });
    expect(me.name).toBe("GR");
    expect(me.role).toBe("both");
  });

  it("404s for unknown users", async () => {
    await expect(service.getMe("nope")).rejects.toThrow(/not found/i);
  });
});
