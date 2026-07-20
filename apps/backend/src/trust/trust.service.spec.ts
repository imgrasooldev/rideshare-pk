import { beforeEach, describe, expect, it } from "vitest";
import { InMemoryUserRepository } from "../users/users.repo.js";
import { InMemoryVehicleRepository } from "../vehicles/vehicles.repo.js";
import { TrustService } from "./trust.service.js";
import { InMemoryVerificationRepository } from "./verifications.repo.js";

describe("TrustService", () => {
  let users: InMemoryUserRepository;
  let vehicles: InMemoryVehicleRepository;
  let service: TrustService;
  let userId: string;
  let adminId: string;

  beforeEach(async () => {
    users = new InMemoryUserRepository();
    vehicles = new InMemoryVehicleRepository();
    service = new TrustService(new InMemoryVerificationRepository(), users, vehicles);
    userId = (await users.upsertByPhone("+923001111111", "lahore")).id;
    adminId = (await users.upsertByPhone("+923009999999", "lahore")).id;
  });

  it("approving a CNIC verification flips the user's verified badge", async () => {
    const v = await service.submit(userId, "cnic", "https://docs.example/cnic.jpg");
    expect(v.status).toBe("pending");
    expect((await users.findById(userId))!.verified).toBe(false);

    const reviewed = await service.review(v.id, "approve", adminId);
    expect(reviewed.status).toBe("approved");
    expect((await users.findById(userId))!.verified).toBe(true);
  });

  it("rejecting does not verify, and a verification is single-review", async () => {
    const v = await service.submit(userId, "cnic", "https://docs.example/cnic.jpg");
    await service.review(v.id, "reject", adminId, "blurry photo");
    expect((await users.findById(userId))!.verified).toBe(false);
    // Already reviewed — cannot approve afterwards.
    await expect(service.review(v.id, "approve", adminId)).rejects.toThrow(/already reviewed/);
  });

  it("vehicle verification requires owning the vehicle and verifies it on approval", async () => {
    const vehicle = await vehicles.create(userId, {
      vehicleType: "car", make: "Suzuki", model: "Alto", plate: "LEB-1234", seats: 4, docUrls: []
    });

    await expect(
      service.submit(adminId, "vehicle", "https://docs.example/car.jpg", vehicle.id)
    ).rejects.toThrow(/not yours/i);
    await expect(service.submit(userId, "vehicle", "https://docs.example/car.jpg")).rejects.toThrow(
      /vehicleId is required/
    );

    const v = await service.submit(userId, "vehicle", "https://docs.example/car.jpg", vehicle.id);
    await service.review(v.id, "approve", adminId);
    expect((await vehicles.findById(vehicle.id))!.verified).toBe(true);
  });

  it("paginates the pending queue FIFO with a working cursor", async () => {
    for (let i = 0; i < 5; i++) {
      await service.submit(userId, "cnic", `https://docs.example/${i}.jpg`);
    }
    const page1 = await service.listPending(null, 2);
    expect(page1.items).toHaveLength(2);
    expect(page1.nextCursor).not.toBeNull();

    const page2 = await service.listPending(page1.nextCursor, 2);
    const page3 = await service.listPending(page2.nextCursor, 2);
    expect(page3.items).toHaveLength(1);
    expect(page3.nextCursor).toBeNull();

    const seen = [...page1.items, ...page2.items, ...page3.items].map((v) => v.id);
    expect(new Set(seen).size).toBe(5); // no duplicates, no gaps
  });
});
