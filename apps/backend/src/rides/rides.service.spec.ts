import { beforeEach, describe, expect, it } from "vitest";
import { loadConfig } from "../config/config.js";
import { InMemoryUserRepository } from "../users/users.repo.js";
import { InMemoryVehicleRepository } from "../vehicles/vehicles.repo.js";
import { InMemoryRideRepository } from "./rides.repo.js";
import { RidesService, type PostRideInput } from "./rides.service.js";

// Gulberg → DHA Phase 5, tomorrow.
const tomorrow = new Date(Date.now() + 24 * 3600 * 1000).toISOString();
const baseRide: PostRideInput = {
  originLabel: "Gulberg Liberty",
  originLat: 31.5102,
  originLng: 74.3441,
  destLabel: "DHA Phase 5",
  destLat: 31.4622,
  destLng: 74.4082,
  departAt: tomorrow,
  recurringDays: [1, 2, 3, 4, 5],
  seatsTotal: 3,
  pricePerSeat: 250,
  vehicleId: null,
  vertical: "office",
  vehicleType: "car",
  ladiesOnly: false
};

describe("RidesService", () => {
  let users: InMemoryUserRepository;
  let vehicles: InMemoryVehicleRepository;
  let service: RidesService;
  let driverId: string;

  beforeEach(async () => {
    users = new InMemoryUserRepository();
    vehicles = new InMemoryVehicleRepository();
    service = new RidesService(loadConfig({}), new InMemoryRideRepository(), users, vehicles);
    const driver = await users.upsertByPhone("+923001111111", "lahore");
    driverId = driver.id;
    await users.updateProfile(driverId, { role: "driver", gender: "female" });
    await users.setVerified(driverId, true);
  });

  it("verified driver posts a ride; seats_available = seats_total; cash-only", async () => {
    const ride = await service.post(driverId, baseRide);
    expect(ride.status).toBe("open");
    expect(ride.seatsAvailable).toBe(3);
    expect(ride.city).toBe("lahore");
    expect(ride.paymentMethod).toBe("cash");
  });

  it("marketplace vehicle types: bike rides carry max 1 passenger", async () => {
    await expect(
      service.post(driverId, { ...baseRide, vehicleType: "bike", seatsTotal: 3 })
    ).rejects.toThrow(/only 1 passenger seat/);
    const bike = await service.post(driverId, { ...baseRide, vehicleType: "bike", seatsTotal: 1 });
    expect(bike.vehicleType).toBe("bike");
    const hiace = await service.post(driverId, { ...baseRide, vehicleType: "hiace", seatsTotal: 12 });
    expect(hiace.seatsAvailable).toBe(12);
  });

  it("blocks unverified drivers when the gate is on", async () => {
    await users.setVerified(driverId, false);
    await expect(service.post(driverId, baseRide)).rejects.toThrow(/CNIC verification/);
  });

  it("allows unverified drivers when the gate is configured off", async () => {
    const open = new RidesService(
      loadConfig({ REQUIRE_DRIVER_VERIFICATION_TO_POST: "false" }),
      new InMemoryRideRepository(),
      users,
      vehicles
    );
    await users.setVerified(driverId, false);
    await expect(open.post(driverId, baseRide)).resolves.toBeTruthy();
  });

  it("blocks riders from posting", async () => {
    const rider = await users.upsertByPhone("+923002222222", "lahore");
    await users.setVerified(rider.id, true);
    await expect(service.post(rider.id, baseRide)).rejects.toThrow(/role to driver/);
  });

  it("ladies-only rides require a female driver", async () => {
    const male = await users.upsertByPhone("+923003333333", "lahore");
    await users.updateProfile(male.id, { role: "driver", gender: "male" });
    await users.setVerified(male.id, true);
    await expect(service.post(male.id, { ...baseRide, ladiesOnly: true })).rejects.toThrow(/women/);
    await expect(service.post(driverId, { ...baseRide, ladiesOnly: true })).resolves.toBeTruthy();
  });

  it("rejects past departures and over-seating the vehicle", async () => {
    await expect(
      service.post(driverId, { ...baseRide, departAt: new Date(Date.now() - 60_000).toISOString() })
    ).rejects.toThrow(/future/);

    const car = await vehicles.create(driverId, {
      vehicleType: "car", make: "Suzuki", model: "Alto", plate: "LEB-1", seats: 3, docUrls: []
    });
    await expect(
      service.post(driverId, { ...baseRide, vehicleId: car.id, seatsTotal: 5 })
    ).rejects.toThrow(/only 3 seats/);
  });

  describe("search", () => {
    const window = {
      departAfter: new Date(Date.now() + 12 * 3600 * 1000).toISOString(),
      departBefore: new Date(Date.now() + 36 * 3600 * 1000).toISOString()
    };
    const nearGulbergToDha = {
      pickupLat: 31.5150, pickupLng: 74.3500, // ~800m from Liberty
      dropLat: 31.4650, dropLng: 74.4050,     // inside DHA 5
      radiusM: 3000,
      ...window,
      cursor: null,
      limit: 20
    };

    it("finds rides whose origin AND destination are within the radius", async () => {
      const ride = await service.post(driverId, baseRide);
      const found = await service.search(nearGulbergToDha);
      expect(found.items.map((r) => r.id)).toContain(ride.id);
    });

    it("excludes rides outside the pickup radius or time window", async () => {
      await service.post(driverId, baseRide);
      // Pickup in Bahria Town (~20 km away) — same drop.
      const far = await service.search({ ...nearGulbergToDha, pickupLat: 31.367, pickupLng: 74.1845 });
      expect(far.items).toHaveLength(0);
      // Window that ends before the ride departs.
      const early = await service.search({
        ...nearGulbergToDha,
        departAfter: new Date(Date.now() + 1 * 3600 * 1000).toISOString(),
        departBefore: new Date(Date.now() + 2 * 3600 * 1000).toISOString()
      });
      expect(early.items).toHaveLength(0);
    });

    // Gulberg -> Johar Town -> DHA: a rider joining at Johar Town is nowhere
    // near either endpoint, so only corridor matching can find this ride.
    const viaJoharTown: Array<[number, number]> = [
      [31.5102, 74.3441], // Gulberg (origin)
      [31.4900, 74.3100],
      [31.4676, 74.2664], // Johar Town (mid-route)
      [31.4650, 74.3400],
      [31.4622, 74.4082] // DHA Phase 5 (destination)
    ];

    it("matches a rider joining mid-route, which endpoint matching misses", async () => {
      const ride = await service.post(driverId, { ...baseRide, routePoints: viaJoharTown });

      // Johar Town -> DHA: pickup is ~8km from the driver's origin.
      const midRoute = {
        ...nearGulbergToDha,
        pickupLat: 31.4676,
        pickupLng: 74.2664,
        dropLat: 31.4622,
        dropLng: 74.4082
      };

      const found = await service.search(midRoute);
      expect(found.items.map((r) => r.id)).toContain(ride.id);

      // Endpoint-only search cannot see it — this is the gain.
      const endpointOnly = await service.search({ ...midRoute, alongRoute: false });
      expect(endpointOnly.items).toHaveLength(0);
    });

    it("does not match a rider travelling the opposite way along the route", async () => {
      await service.post(driverId, { ...baseRide, routePoints: viaJoharTown });

      // DHA -> Johar Town: both points are on the corridor, but backwards.
      const reversed = await service.search({
        ...nearGulbergToDha,
        pickupLat: 31.4622,
        pickupLng: 74.4082,
        dropLat: 31.4676,
        dropLng: 74.2664
      });
      expect(reversed.items).toHaveLength(0);
    });

    it("ignores rides whose corridor passes nowhere near the rider", async () => {
      await service.post(driverId, { ...baseRide, routePoints: viaJoharTown });

      // Bahria Town — ~20km off the corridor.
      const offCorridor = await service.search({
        ...nearGulbergToDha,
        pickupLat: 31.367,
        pickupLng: 74.1845,
        dropLat: 31.4622,
        dropLng: 74.4082
      });
      expect(offCorridor.items).toHaveLength(0);
    });

    it("filters by vehicle type", async () => {
      await service.post(driverId, baseRide);
      await service.post(driverId, { ...baseRide, vehicleType: "hiace", seatsTotal: 12 });
      const hiaceOnly = await service.search({ ...nearGulbergToDha, vehicleType: "hiace" });
      expect(hiaceOnly.items).toHaveLength(1);
      expect(hiaceOnly.items[0]!.vehicleType).toBe("hiace");
    });

    it("filters ladies-only and paginates with a cursor", async () => {
      for (let i = 0; i < 3; i++) {
        await service.post(driverId, {
          ...baseRide,
          departAt: new Date(Date.now() + (24 + i) * 3600 * 1000).toISOString(),
          ladiesOnly: i === 0
        });
      }
      const ladies = await service.search({ ...nearGulbergToDha, ladiesOnly: true });
      expect(ladies.items).toHaveLength(1);
      expect(ladies.items[0]!.ladiesOnly).toBe(true);

      const page1 = await service.search({ ...nearGulbergToDha, limit: 2 });
      expect(page1.items).toHaveLength(2);
      expect(page1.nextCursor).not.toBeNull();
      const page2 = await service.search({ ...nearGulbergToDha, limit: 2, cursor: page1.nextCursor });
      expect(page2.items).toHaveLength(1);
      expect(page2.nextCursor).toBeNull();
    });
  });
});
