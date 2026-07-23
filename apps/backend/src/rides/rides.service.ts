import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException
} from "@nestjs/common";
import type { AppConfig } from "../config/config.js";
import { PlacesRepository } from "../places/places.repo.js";
import { APP_CONFIG, RIDE_REPOSITORY, USER_REPOSITORY, VEHICLE_REPOSITORY } from "../shared/tokens.js";
import type { UserRepository } from "../users/users.repo.js";
import type { VehicleRepository } from "../vehicles/vehicles.repo.js";
import type { NewRide, RidePage, RideRecord, RideRepository, RideSearch } from "./rides.repo.js";

export type PostRideInput = Omit<NewRide, "driverId" | "city">;

@Injectable()
export class RidesService {
  constructor(
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(RIDE_REPOSITORY) private readonly rides: RideRepository,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
    @Inject(VEHICLE_REPOSITORY) private readonly vehicles: VehicleRepository,
    private readonly places?: PlacesRepository
  ) {}

  async post(driverId: string, input: PostRideInput): Promise<RideRecord> {
    const user = await this.users.findById(driverId);
    if (!user) throw new NotFoundException("User not found");

    if (user.role !== "driver" && user.role !== "both") {
      throw new ForbiddenException("Set your role to driver in your profile first");
    }
    // Trust gate (configurable): unverified drivers cannot post (rule: build
    // trust in, not bolt on). Verification = approved CNIC via admin queue.
    if (this.config.REQUIRE_DRIVER_VERIFICATION_TO_POST && !user.verified) {
      throw new ForbiddenException("Complete CNIC verification before posting rides");
    }
    if (input.ladiesOnly && user.gender !== "female") {
      throw new ForbiddenException("Ladies-only rides can only be posted by verified women");
    }
    if (new Date(input.departAt).getTime() <= Date.now()) {
      throw new BadRequestException("departAt must be in the future");
    }
    // Marketplace reality: a bike carries one passenger.
    if (input.vehicleType === "bike" && input.seatsTotal > 1) {
      throw new BadRequestException("A bike ride can offer only 1 passenger seat");
    }
    if (input.vehicleId) {
      const vehicle = await this.vehicles.findById(input.vehicleId);
      if (!vehicle || vehicle.ownerId !== driverId) {
        throw new ForbiddenException("Vehicle not found or not yours");
      }
      if (input.seatsTotal > vehicle.seats) {
        throw new BadRequestException(`Vehicle has only ${vehicle.seats} seats`);
      }
    }

    // Store the driving polyline so riders can be matched anywhere ALONG the
    // route, not just near its endpoints. Best-effort: a routing outage must
    // never block posting a ride — the ride simply falls back to endpoint
    // matching until it is backfilled.
    let routePoints = input.routePoints;
    if (!routePoints && this.places) {
      try {
        const route = await this.places.route(
          input.originLat,
          input.originLng,
          input.destLat,
          input.destLng
        );
        routePoints = route.points;
      } catch {
        /* keep routePoints undefined */
      }
    }

    return this.rides.create({ ...input, routePoints, driverId, city: user.city });
  }

  async getById(id: string): Promise<RideRecord> {
    const ride = await this.rides.findById(id);
    if (!ride) throw new NotFoundException("Ride not found");
    return ride;
  }

  search(params: RideSearch): Promise<RidePage> {
    return this.rides.search(params);
  }

  myRides(driverId: string, cursor: string | null, limit: number): Promise<RidePage> {
    return this.rides.listByDriver(driverId, cursor, limit);
  }

  /** Driver self-manages seat count on a posted ride (e.g. a minivan filling up). */
  async updateSeats(driverId: string, rideId: string, seatsTotal: number): Promise<RideRecord> {
    const ride = await this.rides.findById(rideId);
    if (!ride) throw new NotFoundException("Ride not found");
    if (ride.driverId !== driverId) throw new ForbiddenException("Not your ride");
    if (ride.status !== "open" && ride.status !== "full") {
      throw new BadRequestException("This ride can no longer be edited");
    }
    if (ride.vehicleType === "bike" && seatsTotal > 1) {
      throw new BadRequestException("A bike ride can offer only 1 passenger seat");
    }
    const reserved = ride.seatsTotal - ride.seatsAvailable;
    if (seatsTotal < reserved) {
      throw new BadRequestException(`${reserved} seat(s) already booked — can't go below that`);
    }
    if (ride.vehicleId) {
      const vehicle = await this.vehicles.findById(ride.vehicleId);
      if (vehicle && seatsTotal > vehicle.seats) {
        throw new BadRequestException(`Vehicle has only ${vehicle.seats} seats`);
      }
    }
    const updated = await this.rides.updateSeats(rideId, driverId, seatsTotal);
    if (!updated) throw new BadRequestException("Could not update seats");
    return updated;
  }
}
