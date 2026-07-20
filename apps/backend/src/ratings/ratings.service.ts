import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException
} from "@nestjs/common";
import { DuplicateRatingError } from "./ratings.repo.js";
import { BOOKING_REPOSITORY, RATING_REPOSITORY, RIDE_REPOSITORY } from "../shared/tokens.js";
import type { BookingRepository } from "../bookings/bookings.repo.js";
import type { RideRepository } from "../rides/rides.repo.js";
import type { RatingRecord, RatingRepository } from "./ratings.repo.js";

@Injectable()
export class RatingsService {
  constructor(
    @Inject(RATING_REPOSITORY) private readonly ratings: RatingRepository,
    @Inject(RIDE_REPOSITORY) private readonly rides: RideRepository,
    @Inject(BOOKING_REPOSITORY) private readonly bookings: BookingRepository
  ) {}

  /**
   * Two-way ratings, participants only:
   *  - a booked rider may rate the ride's driver
   *  - the driver may rate a rider who booked the ride
   */
  async rate(fromUserId: string, rideId: string, toUserId: string, stars: number, comment?: string): Promise<RatingRecord> {
    if (fromUserId === toUserId) {
      throw new BadRequestException("You cannot rate yourself");
    }
    const ride = await this.rides.findById(rideId);
    if (!ride) throw new NotFoundException("Ride not found");

    const fromIsDriver = ride.driverId === fromUserId;
    if (fromIsDriver) {
      const targetBooked = await this.bookings.hasBookingForRide(toUserId, rideId);
      if (!targetBooked) {
        throw new ForbiddenException("You can only rate riders who booked this ride");
      }
    } else {
      if (toUserId !== ride.driverId) {
        throw new ForbiddenException("Riders can only rate the driver of this ride");
      }
      const booked = await this.bookings.hasBookingForRide(fromUserId, rideId);
      if (!booked) {
        throw new ForbiddenException("Book this ride before rating its driver");
      }
    }

    try {
      return await this.ratings.create(rideId, fromUserId, toUserId, stars, comment ?? null);
    } catch (err) {
      if (err instanceof DuplicateRatingError) throw new ConflictException(err.message);
      throw err;
    }
  }

  listForUser(userId: string): Promise<RatingRecord[]> {
    return this.ratings.listForUser(userId, 20);
  }
}
