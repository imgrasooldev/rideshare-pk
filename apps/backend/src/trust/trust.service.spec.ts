import { beforeEach, describe, expect, it } from "vitest";
import type { DocumentStorage } from "../storage/storage.provider.js";
import { InMemoryUserRepository } from "../users/users.repo.js";
import { InMemoryVehicleRepository } from "../vehicles/vehicles.repo.js";
import { TrustService } from "./trust.service.js";
import { InMemoryVerificationRepository } from "./verifications.repo.js";

/** An external (legacy) document link. */
const link = (file: string) => ({ docUrl: `https://docs.example/${file}`, docKey: null });
/** A document uploaded to private storage, namespaced by user id. */
const upload = (userId: string, file: string) => ({ docUrl: null, docKey: `${userId}/${file}` });

const fakeStorage: DocumentStorage = {
  enabled: true,
  createUploadUrl: async () => ({ uploadUrl: "https://upload", key: "k", expiresInSeconds: 300 }),
  createViewUrl: async (key, ttl) => `https://signed/${key}?ttl=${ttl}`
};

describe("TrustService", () => {
  let users: InMemoryUserRepository;
  let vehicles: InMemoryVehicleRepository;
  let service: TrustService;
  let userId: string;
  let adminId: string;

  beforeEach(async () => {
    users = new InMemoryUserRepository();
    vehicles = new InMemoryVehicleRepository();
    service = new TrustService(
      new InMemoryVerificationRepository(),
      users,
      vehicles,
      fakeStorage
    );
    userId = (await users.upsertByPhone("+923001111111", "lahore")).id;
    adminId = (await users.upsertByPhone("+923009999999", "lahore")).id;
  });

  it("approving a CNIC verification flips the user's verified badge", async () => {
    const v = await service.submit(userId, "cnic", link("cnic.jpg"));
    expect(v.status).toBe("pending");
    expect((await users.findById(userId))!.verified).toBe(false);

    const reviewed = await service.review(v.id, "approve", adminId);
    expect(reviewed.status).toBe("approved");
    expect((await users.findById(userId))!.verified).toBe(true);
  });

  it("rejecting does not verify, and a verification is single-review", async () => {
    const v = await service.submit(userId, "cnic", link("cnic.jpg"));
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
      service.submit(adminId, "vehicle", link("car.jpg"), vehicle.id)
    ).rejects.toThrow(/not yours/i);
    await expect(service.submit(userId, "vehicle", link("car.jpg"))).rejects.toThrow(
      /vehicleId is required/
    );

    const v = await service.submit(userId, "vehicle", link("car.jpg"), vehicle.id);
    await service.review(v.id, "approve", adminId);
    expect((await vehicles.findById(vehicle.id))!.verified).toBe(true);
  });

  describe("uploaded documents", () => {
    it("accepts an upload key owned by the submitter", async () => {
      const v = await service.submit(userId, "cnic", upload(userId, "cnic-1.jpg"));
      expect(v.docKey).toBe(`${userId}/cnic-1.jpg`);
      expect(v.docUrl).toBeNull();
    });

    it("refuses an upload key belonging to another user", async () => {
      await expect(
        service.submit(userId, "cnic", upload(adminId, "cnic-1.jpg"))
      ).rejects.toThrow(/does not belong to you/i);
    });

    it("resolves a private key to a short-lived signed URL for reviewers", async () => {
      const v = await service.submit(userId, "cnic", upload(userId, "cnic-1.jpg"));
      const { url } = await service.documentUrl(v.id, 300);
      expect(url).toBe(`https://signed/${userId}/cnic-1.jpg?ttl=300`);
    });

    it("passes external links through unchanged", async () => {
      const v = await service.submit(userId, "cnic", link("cnic.jpg"));
      const { url } = await service.documentUrl(v.id, 300);
      expect(url).toBe("https://docs.example/cnic.jpg");
    });
  });

  it("paginates the pending queue FIFO with a working cursor", async () => {
    for (let i = 0; i < 5; i++) {
      await service.submit(userId, "cnic", link(`${i}.jpg`));
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
