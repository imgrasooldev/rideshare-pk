import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { InMemoryBookingRepository } from "../bookings/bookings.repo.js";
import { InMemoryNotificationRepository } from "../notifications/notifications.repo.js";
import { NotificationsService } from "../notifications/notifications.service.js";
import { PushService } from "../push/push.service.js";
import type { AppConfig } from "../config/config.js";
import { InMemoryRideRepository } from "../rides/rides.repo.js";
import { InMemoryBus } from "../shared/bus.js";
import { InMemoryKvStore } from "../shared/kv.js";
import { InMemoryTripRepository } from "./trips.repo.js";
import { TrackingService } from "./tracking.service.js";

describe("TrackingService", () => {
  let rides: InMemoryRideRepository;
  let service: TrackingService;
  let rideId: string;
  const driverId = "driver-1";

  beforeEach(async () => {
    vi.useFakeTimers();
    rides = new InMemoryRideRepository();
    service = new TrackingService(
      new InMemoryTripRepository(),
      rides,
      new InMemoryKvStore(),
      new InMemoryBus(),
      new InMemoryBookingRepository(rides),
      new NotificationsService(
        new InMemoryNotificationRepository(),
        new PushService(null, { FIREBASE_SERVICE_ACCOUNT: "", FIREBASE_PROJECT_ID: "" } as AppConfig)
      )
    );
    const ride = await rides.create({
      driverId,
      vehicleId: null,
      originLabel: "Gulberg",
      originLat: 31.51,
      originLng: 74.34,
      destLabel: "DHA",
      destLat: 31.46,
      destLng: 74.41,
      departAt: new Date(Date.now() + 3600_000).toISOString(),
      recurringDays: [],
      seatsTotal: 3,
      pricePerSeat: 250,
      vertical: "office",
      vehicleType: "car",
      ladiesOnly: false,
      city: "lahore"
    });
    rideId = ride.id;
  });

  afterEach(() => vi.useRealTimers());

  it("only the ride's driver can start/end a trip", async () => {
    await expect(service.start("someone-else", rideId)).rejects.toThrow(/Not your ride/);
    const trip = await service.start(driverId, rideId);
    expect(trip.liveStatus).toBe("live");
    expect(trip.shareToken).toBeTruthy();
    // Starting again returns the same live trip.
    expect((await service.start(driverId, rideId)).id).toBe(trip.id);
  });

  it("publishes locations to subscribers and stores the latest", async () => {
    await service.start(driverId, rideId);
    const seen: string[] = [];
    await service.subscribe(rideId, (m) => seen.push(m));

    const accepted = await service.publishLocation(driverId, rideId, 31.5, 74.35);
    expect(accepted).toBe(true);
    expect(seen).toHaveLength(1);
    expect(JSON.parse(seen[0]!)).toMatchObject({ type: "location", lat: 31.5, lng: 74.35 });
    expect(await service.lastLocation(rideId)).toMatchObject({ lat: 31.5, lng: 74.35 });
  });

  it("throttles pings faster than 3 seconds", async () => {
    await service.start(driverId, rideId);
    expect(await service.publishLocation(driverId, rideId, 31.5, 74.35)).toBe(true);
    expect(await service.publishLocation(driverId, rideId, 31.6, 74.36)).toBe(false);
    vi.advanceTimersByTime(3100);
    expect(await service.publishLocation(driverId, rideId, 31.6, 74.36)).toBe(true);
  });

  it("rejects pings before the trip starts and from non-drivers", async () => {
    await expect(service.publishLocation(driverId, rideId, 31.5, 74.35)).rejects.toThrow(
      /Start the trip/
    );
    await service.start(driverId, rideId);
    await expect(service.publishLocation("intruder", rideId, 31.5, 74.35)).rejects.toThrow(
      /Not your ride/
    );
  });

  it("ending a trip clears the location and notifies subscribers", async () => {
    await service.start(driverId, rideId);
    await service.publishLocation(driverId, rideId, 31.5, 74.35);
    const seen: string[] = [];
    await service.subscribe(rideId, (m) => seen.push(m));

    await service.end(driverId, rideId);
    expect(await service.lastLocation(rideId)).toBeNull();
    expect(seen.map((m) => JSON.parse(m).type)).toContain("ended");
  });

  it("shared view exposes a safe subset via the share token", async () => {
    const trip = await service.start(driverId, rideId);
    await service.publishLocation(driverId, rideId, 31.52, 74.36);

    const view = await service.sharedView(trip.shareToken);
    expect(view.status).toBe("live");
    expect(view.originLabel).toBe("Gulberg");
    expect(view.location).toMatchObject({ lat: 31.52, lng: 74.36 });

    await expect(service.sharedView("bogus")).rejects.toThrow(/invalid or expired/);

    await service.end(driverId, rideId);
    const after = await service.sharedView(trip.shareToken);
    expect(after.status).toBe("ended");
    expect(after.location).toBeNull();
  });
});
