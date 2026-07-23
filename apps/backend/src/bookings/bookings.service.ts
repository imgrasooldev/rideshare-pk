import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException
} from "@nestjs/common";
import type { BlocksRepository } from "../safety/blocks.repo.js";
import {
  BLOCKS_REPOSITORY,
  BOOKING_REPOSITORY,
  RIDE_REPOSITORY,
  USER_REPOSITORY
} from "../shared/tokens.js";
import type { RideRepository } from "../rides/rides.repo.js";
import type { UserRepository } from "../users/users.repo.js";
import { NotificationsService } from "../notifications/notifications.service.js";
import type {
  BookingPage,
  BookingRecord,
  BookingRepository,
  DriverRequest
} from "./bookings.repo.js";

export type DriverAction = "accept" | "reject" | "counter";

@Injectable()
export class BookingsService {
  constructor(
    @Inject(BOOKING_REPOSITORY) private readonly bookings: BookingRepository,
    @Inject(RIDE_REPOSITORY) private readonly rides: RideRepository,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
    @Inject(BLOCKS_REPOSITORY) private readonly blocks: BlocksRepository,
    private readonly notifications: NotificationsService
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
    // Deliberately vague: revealing "they blocked you" invites retaliation.
    if (await this.blocks.isBlockedEitherWay(riderId, ride.driverId)) {
      throw new ForbiddenException("This ride is not available to you");
    }
    if (ride.ladiesOnly) {
      const rider = await this.users.findById(riderId);
      if (rider?.gender !== "female") {
        throw new ForbiddenException("This is a ladies-only ride");
      }
    }
    // A request holds no seat — the driver accepts to confirm it.
    const booking = await this.bookings.create(riderId, rideId, seats, idempotencyKey);

    // Ping the driver's request inbox (best-effort, never blocks the request).
    const rider = await this.users.findById(riderId);
    void this.notifications.notify(
      ride.driverId,
      "booking_request",
      "New seat request",
      `${rider?.name ?? "A rider"} requested ${seats} seat${seats > 1 ? "s" : ""} · ${ride.originLabel} → ${ride.destLabel}`,
      { rideId, bookingId: booking.id }
    );
    return booking;
  }

  cancel(bookingId: string, riderId: string, reason?: string): Promise<BookingRecord> {
    return this.bookings.cancel(bookingId, riderId, reason);
  }

  /**
   * Pickup check: the driver enters the 4-digit PIN the passenger reads out,
   * proving the right person is getting into the right car.
   */
  async verifyStartPin(driverId: string, bookingId: string, pin: string): Promise<BookingRecord> {
    const booking = await this.bookings.verifyStartPin(bookingId, driverId, pin);
    void this.notifications.notify(
      booking.riderId,
      "booking_update",
      "Pickup confirmed",
      "Your driver confirmed your PIN. Have a safe trip!",
      { rideId: booking.rideId, bookingId: booking.id }
    );
    return booking;
  }

  /** Driver marks a confirmed rider a no-show; frees the seat and notifies them. */
  async noShow(driverId: string, bookingId: string): Promise<BookingRecord> {
    const booking = await this.bookings.noShow(bookingId, driverId);
    void this.notifications.notify(
      booking.riderId,
      "booking_update",
      "Marked as no-show",
      "The driver reported you didn't show up for the ride.",
      { rideId: booking.rideId, bookingId: booking.id }
    );
    return booking;
  }

  ridePassengers(driverId: string, rideId: string): Promise<DriverRequest[]> {
    return this.bookings.listForRide(rideId, driverId);
  }

  mine(riderId: string, cursor: string | null, limit: number): Promise<BookingPage> {
    return this.bookings.listByRider(riderId, cursor, limit);
  }

  requests(driverId: string, limit: number): Promise<DriverRequest[]> {
    return this.bookings.listRequestsForDriver(driverId, limit);
  }

  /** Driver acts on a seat request. Ownership is enforced in the repository. */
  async respond(
    driverId: string,
    bookingId: string,
    action: DriverAction,
    offeredPrice?: number
  ): Promise<BookingRecord> {
    let booking: BookingRecord;
    let title: string;
    let body: string;
    if (action === "accept") {
      booking = await this.bookings.accept(bookingId, driverId);
      title = "Request accepted";
      body = "Your seat is confirmed. Cash on the trip.";
    } else if (action === "reject") {
      booking = await this.bookings.reject(bookingId, driverId);
      title = "Request declined";
      body = "The driver couldn't take this request. Try another ride.";
    } else {
      if (!offeredPrice || offeredPrice <= 0) {
        throw new BadRequestException("Enter a valid counter-offer price");
      }
      booking = await this.bookings.counter(bookingId, driverId, offeredPrice);
      title = "Driver counter-offered";
      body = `New price: Rs ${offeredPrice}/seat. Accept or decline in the app.`;
    }
    void this.notifications.notify(booking.riderId, "booking_update", title, body, {
      rideId: booking.rideId,
      bookingId: booking.id
    });
    return booking;
  }

  /** Rider accepts or declines a driver's counter-offer. */
  async respondToCounter(riderId: string, bookingId: string, accept: boolean): Promise<BookingRecord> {
    const booking = await this.bookings.respondToCounter(bookingId, riderId, accept);
    const ride = await this.rides.findById(booking.rideId);
    if (ride) {
      const rider = await this.users.findById(riderId);
      void this.notifications.notify(
        ride.driverId,
        "booking_update",
        accept ? "Counter-offer accepted" : "Counter-offer declined",
        `${rider?.name ?? "The rider"} ${accept ? "accepted" : "declined"} · ${ride.originLabel} → ${ride.destLabel}`,
        { rideId: ride.id, bookingId: booking.id }
      );
    }
    return booking;
  }
}
