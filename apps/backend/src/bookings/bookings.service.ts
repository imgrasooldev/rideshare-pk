import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException
} from "@nestjs/common";
import { BOOKING_REPOSITORY, RIDE_REPOSITORY, USER_REPOSITORY } from "../shared/tokens.js";
import type { RideRepository } from "../rides/rides.repo.js";
import type { UserRepository } from "../users/users.repo.js";
import type { BookingPage, BookingRecord, BookingRepository } from "./bookings.repo.js";

@Injectable()
export class BookingsService {
  constructor(
    @Inject(BOOKING_REPOSITORY) private readonly bookings: BookingRepository,
    @Inject(RIDE_REPOSITORY) private readonly rides: RideRepository,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository
  ) {}

  async book(riderId: string, rideId: string, seats: number, idempotencyKey: string): Promise<BookingRecord> {
    const ride = await this.rides.findById(rideId);
    if (!ride) throw new NotFoundException("Ride not found");
    if (ride.driverId === riderId) {
      throw new BadRequestException("You cannot book a seat on your own ride");
    }
    if (new Date(ride.departAt).getTime() <= Date.now()) {
      throw new BadRequestException("This ride has already departed");
    }
    if (ride.ladiesOnly) {
      const rider = await this.users.findById(riderId);
      if (rider?.gender !== "female") {
        throw new ForbiddenException("This is a ladies-only ride");
      }
    }
    // Seat availability is NOT checked here — the repository's conditional
    // UPDATE is the single source of truth, immune to check-then-act races.
    return this.bookings.create(riderId, rideId, seats, idempotencyKey);
  }

  cancel(bookingId: string, riderId: string): Promise<BookingRecord> {
    return this.bookings.cancel(bookingId, riderId);
  }

  mine(riderId: string, cursor: string | null, limit: number): Promise<BookingPage> {
    return this.bookings.listByRider(riderId, cursor, limit);
  }
}
