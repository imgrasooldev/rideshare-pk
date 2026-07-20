import { beforeEach, describe, expect, it } from "vitest";
import { InMemoryBookingRepository } from "../bookings/bookings.repo.js";
import { InMemoryRideRepository } from "../rides/rides.repo.js";
import { InMemoryRatingRepository } from "./ratings.repo.js";
import { RatingsService } from "./ratings.service.js";

describe("RatingsService", () => {
  let rides: InMemoryRideRepository;
  let bookings: InMemoryBookingRepository;
  let ratingsRepo: InMemoryRatingRepository;
  let service: RatingsService;
  let rideId: string;
  const driverId = "driver-1";
  const riderId = "rider-1";

  beforeEach(async () => {
    rides = new InMemoryRideRepository();
    bookings = new InMemoryBookingRepository(rides);
    ratingsRepo = new InMemoryRatingRepository();
    service = new RatingsService(ratingsRepo, rides, bookings);
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
    await bookings.create(riderId, rideId, 1, "key-1");
  });

  it("booked rider rates the driver; aggregate updates", async () => {
    const rating = await service.rate(riderId, rideId, driverId, 5, "Great drive");
    expect(rating.stars).toBe(5);
    expect(ratingsRepo.aggregates.get(driverId)).toEqual({ avg: 5, count: 1 });
  });

  it("driver rates a booked rider; average accumulates correctly", async () => {
    await service.rate(driverId, rideId, riderId, 4);
    const ride2 = await rides.create({
      driverId,
      vehicleId: null,
      originLabel: "A",
      originLat: 31.5,
      originLng: 74.3,
      destLabel: "B",
      destLat: 31.4,
      destLng: 74.4,
      departAt: new Date(Date.now() + 7200_000).toISOString(),
      recurringDays: [],
      seatsTotal: 3,
      pricePerSeat: 200,
      vertical: "office",
      vehicleType: "car",
      ladiesOnly: false,
      city: "lahore"
    });
    await bookings.create(riderId, ride2.id, 1, "key-2");
    await service.rate(driverId, ride2.id, riderId, 5);
    expect(ratingsRepo.aggregates.get(riderId)).toEqual({ avg: 4.5, count: 2 });
  });

  it("rejects non-participants, self-ratings, and rating strangers", async () => {
    await expect(service.rate("stranger", rideId, driverId, 5)).rejects.toThrow(
      /Book this ride/
    );
    await expect(service.rate(riderId, rideId, riderId, 5)).rejects.toThrow(/rate yourself/);
    await expect(service.rate(riderId, rideId, "other-user", 5)).rejects.toThrow(
      /only rate the driver/
    );
    await expect(service.rate(driverId, rideId, "never-booked", 5)).rejects.toThrow(
      /riders who booked/
    );
  });

  it("one rating per (ride, from, to)", async () => {
    await service.rate(riderId, rideId, driverId, 5);
    await expect(service.rate(riderId, rideId, driverId, 1)).rejects.toThrow(/already rated/);
    expect(ratingsRepo.aggregates.get(driverId)).toEqual({ avg: 5, count: 1 });
  });
});
