import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException
} from "@nestjs/common";
import type { AppConfig } from "../config/config.js";
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
    @Inject(VEHICLE_REPOSITORY) private readonly vehicles: VehicleRepository
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
    if (input.vehicleId) {
      const vehicle = await this.vehicles.findById(input.vehicleId);
      if (!vehicle || vehicle.ownerId !== driverId) {
        throw new ForbiddenException("Vehicle not found or not yours");
      }
      if (input.seatsTotal > vehicle.seats) {
        throw new BadRequestException(`Vehicle has only ${vehicle.seats} seats`);
      }
    }

    return this.rides.create({ ...input, driverId, city: user.city });
  }

  async getById(id: string): Promise<RideRecord> {
    const ride = await this.rides.findById(id);
    if (!ride) throw new NotFoundException("Ride not found");
    return ride;
  }

  search(params: RideSearch): Promise<RidePage> {
    return this.rides.search(params);
  }
}
