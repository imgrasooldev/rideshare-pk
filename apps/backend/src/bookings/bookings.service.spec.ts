import { beforeEach, describe, expect, it } from "vitest";
import { InMemoryNotificationRepository } from "../notifications/notifications.repo.js";
import { NotificationsService } from "../notifications/notifications.service.js";
import { PushService } from "../push/push.service.js";
import type { AppConfig } from "../config/config.js";
import { InMemoryRideRepository, type RideRecord } from "../rides/rides.repo.js";
import { InMemoryUserRepository } from "../users/users.repo.js";
import { InMemoryBookingRepository } from "./bookings.repo.js";
import { BookingsService } from "./bookings.service.js";

describe("BookingsService", () => {
  let users: InMemoryUserRepository;
  let rides: InMemoryRideRepository;
  let service: BookingsService;
  let driverId: string;
  let riderId: string;
  let ride: RideRecord;

  async function makeRide(overrides: Partial<Parameters<InMemoryRideRepository["create"]>[0]> = {}) {
    return rides.create({
      driverId,
      vehicleId: null,
      originLabel: "Gulberg",
      originLat: 31.51,
      originLng: 74.34,
      destLabel: "DHA 5",
      destLat: 31.46,
      destLng: 74.41,
      departAt: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
      recurringDays: [],
      seatsTotal: 3,
      pricePerSeat: 250,
      vertical: "office",
      vehicleType: "car",
      ladiesOnly: false,
      city: "lahore",
      ...overrides
    });
  }

  beforeEach(async () => {
    users = new InMemoryUserRepository();
    rides = new InMemoryRideRepository();
    service = new BookingsService(
      new InMemoryBookingRepository(rides),
      rides,
      users,
      new NotificationsService(
        new InMemoryNotificationRepository(),
        new PushService(null, { FIREBASE_SERVICE_ACCOUNT: "", FIREBASE_PROJECT_ID: "" } as AppConfig)
      )
    );
    driverId = (await users.upsertByPhone("+923001111111", "lahore")).id;
    riderId = (await users.upsertByPhone("+923002222222", "lahore")).id;
    ride = await makeRide();
  });

  it("request holds no seat; driver accept confirms and decrements to full", async () => {
    const b = await service.book(riderId, ride.id, 2, "key-1");
    expect(b.status).toBe("requested");
    // A pending request never blocks the ride.
    expect((await rides.findById(ride.id))!.seatsAvailable).toBe(3);

    const accepted = await service.respond(driverId, b.id, "accept");
    expect(accepted.status).toBe("confirmed");
    expect((await rides.findById(ride.id))!.seatsAvailable).toBe(1);

    const b2 = await service.book(riderId, ride.id, 1, "key-2");
    await service.respond(driverId, b2.id, "accept");
    const after = await rides.findById(ride.id);
    expect(after!.seatsAvailable).toBe(0);
    expect(after!.status).toBe("full");
  });

  it("idempotency: same key replays the original request", async () => {
    const first = await service.book(riderId, ride.id, 1, "same-key");
    const replay = await service.book(riderId, ride.id, 1, "same-key");
    expect(replay.id).toBe(first.id);
    expect(first.status).toBe("requested");
    expect((await rides.findById(ride.id))!.seatsAvailable).toBe(3);
  });

  it("race: N concurrent accepts for limited seats - exactly seats_total win", async () => {
    const riders = await Promise.all(
      Array.from({ length: 6 }, (_, i) => users.upsertByPhone(`+9230099900${i}${i}`, "lahore"))
    );
    const requests = await Promise.all(
      riders.map((r, i) => service.book(r.id, ride.id, 1, `race-${i}`))
    );
    const results = await Promise.allSettled(
      requests.map((b) => service.respond(driverId, b.id, "accept"))
    );
    const won = results.filter((r) => r.status === "fulfilled").length;
    const lost = results.filter((r) => r.status === "rejected").length;
    expect(won).toBe(3); // seats_total
    expect(lost).toBe(3);
    const after = await rides.findById(ride.id);
    expect(after!.seatsAvailable).toBe(0);
    expect(after!.status).toBe("full");
  });

  it("rejects own-ride requests, departed rides, and unknown rides", async () => {
    await expect(service.book(driverId, ride.id, 1, "k")).rejects.toThrow(/own ride/);
    const past = await makeRide({ departAt: new Date(Date.now() - 3600_000).toISOString() });
    await expect(service.book(riderId, past.id, 1, "k3")).rejects.toThrow(/already departed/);
    await expect(service.book(riderId, "nope", 1, "k4")).rejects.toThrow(/Ride not found/);
    // Over-capacity is allowed as a request but fails on accept.
    const over = await service.book(riderId, ride.id, 4, "k2");
    await expect(service.respond(driverId, over.id, "accept")).rejects.toThrow(/Not enough seats/);
  });

  it("driver can reject; rider can accept a counter-offer at the new price", async () => {
    const r1 = await service.book(riderId, ride.id, 1, "r-1");
    const rejected = await service.respond(driverId, r1.id, "reject");
    expect(rejected.status).toBe("rejected");
    expect((await rides.findById(ride.id))!.seatsAvailable).toBe(3);

    const r2 = await service.book(riderId, ride.id, 1, "r-2");
    const countered = await service.respond(driverId, r2.id, "counter", 400);
    expect(countered.status).toBe("countered");
    expect(countered.offeredPrice).toBe(400);

    const confirmed = await service.respondToCounter(riderId, r2.id, true);
    expect(confirmed.status).toBe("confirmed");
    expect((await rides.findById(ride.id))!.seatsAvailable).toBe(2);
  });

  it("driver marks a confirmed rider a no-show, freeing the seat", async () => {
    const b = await service.book(riderId, ride.id, 1, "ns1");
    await service.respond(driverId, b.id, "accept");
    expect((await rides.findById(ride.id))!.seatsAvailable).toBe(2);
    const ns = await service.noShow(driverId, b.id);
    expect(ns.status).toBe("no_show");
    expect((await rides.findById(ride.id))!.seatsAvailable).toBe(3);
  });

  it("ladies-only rides are requestable only by women", async () => {
    const lo = await makeRide({ ladiesOnly: true });
    await expect(service.book(riderId, lo.id, 1, "k5")).rejects.toThrow(/ladies-only/);
    const woman = await users.upsertByPhone("+923003333333", "lahore");
    await users.updateProfile(woman.id, { gender: "female" });
    await expect(service.book(woman.id, lo.id, 1, "k6")).resolves.toBeTruthy();
  });

  it("cancel restores seats only for confirmed bookings, and is single-shot", async () => {
    const b1 = await service.book(riderId, ride.id, 3, "k7");
    await service.respond(driverId, b1.id, "accept");
    expect((await rides.findById(ride.id))!.status).toBe("full");

    await service.cancel(b1.id, riderId);
    const after = await rides.findById(ride.id);
    expect(after!.seatsAvailable).toBe(3);
    expect(after!.status).toBe("open");

    await expect(service.cancel(b1.id, riderId)).rejects.toThrow(/already finished/);

    // Cancelling a still-pending request frees nothing (it held no seat).
    const pending = await service.book(riderId, ride.id, 2, "k7b");
    await service.cancel(pending.id, riderId);
    expect((await rides.findById(ride.id))!.seatsAvailable).toBe(3);

    // Someone else's booking cannot be cancelled.
    const b2 = await service.book(riderId, ride.id, 1, "k8");
    await expect(service.cancel(b2.id, driverId)).rejects.toThrow(/not yours|not found/i);
  });

  it("lists my bookings newest-first with a working cursor", async () => {
    const r2 = await makeRide();
    const r3 = await makeRide();
    await service.book(riderId, ride.id, 1, "l1");
    await service.book(riderId, r2.id, 1, "l2");
    await service.book(riderId, r3.id, 1, "l3");

    const page1 = await service.mine(riderId, null, 2);
    expect(page1.items).toHaveLength(2);
    expect(page1.items[0]!.ride.originLabel).toBe("Gulberg");
    const page2 = await service.mine(riderId, page1.nextCursor, 2);
    expect(page2.items).toHaveLength(1);
    expect(page2.nextCursor).toBeNull();
    const ids = [...page1.items, ...page2.items].map((b) => b.id);
    expect(new Set(ids).size).toBe(3);
  });
});
