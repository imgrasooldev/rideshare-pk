import { BadRequestException, Inject, Injectable, NotFoundException } from "@nestjs/common";
import { RIDE_REPOSITORY, SUBSCRIPTION_REPOSITORY } from "../shared/tokens.js";
import type { RideRepository } from "../rides/rides.repo.js";
import { NotificationsService } from "../notifications/notifications.service.js";
import type {
  SubscriptionRecord,
  SubscriptionRepository,
  SubscriptionWithRide
} from "./subscriptions.repo.js";

// A commuter runs ~22 weekday trips a month; subscribers get a standing
// discount vs. paying per ride — the incentive to lock in monthly.
const TRIPS_PER_MONTH = 22;
const SUBSCRIBER_RATE = 0.8;

@Injectable()
export class SubscriptionsService {
  constructor(
    @Inject(SUBSCRIPTION_REPOSITORY) private readonly subs: SubscriptionRepository,
    @Inject(RIDE_REPOSITORY) private readonly rides: RideRepository,
    private readonly notifications: NotificationsService
  ) {}

  /** Monthly price for a recurring ride at the subscriber rate. */
  quote(pricePerSeat: number, seats: number): number {
    return Math.round(pricePerSeat * seats * TRIPS_PER_MONTH * SUBSCRIBER_RATE);
  }

  async subscribe(riderId: string, rideId: string, seats: number): Promise<SubscriptionRecord> {
    const ride = await this.rides.findById(rideId);
    if (!ride) throw new NotFoundException("Ride not found");
    if (ride.driverId === riderId) {
      throw new BadRequestException("You cannot subscribe to your own ride");
    }
    const pricePerMonth = this.quote(ride.pricePerSeat, seats);
    const renews = new Date();
    renews.setMonth(renews.getMonth() + 1);
    const renewsOn = renews.toISOString().slice(0, 10);

    const sub = await this.subs.create(
      riderId,
      rideId,
      seats,
      ride.recurringDays?.length ? ride.recurringDays : [1, 2, 3, 4, 5],
      pricePerMonth,
      renewsOn
    );

    void this.notifications.notify(
      ride.driverId,
      "subscription",
      "New monthly subscriber",
      `Someone subscribed to your ${ride.originLabel} → ${ride.destLabel} route`,
      { rideId, subscriptionId: sub.id }
    );
    return sub;
  }

  mine(riderId: string): Promise<SubscriptionWithRide[]> {
    return this.subs.listByRider(riderId);
  }

  cancel(id: string, riderId: string): Promise<SubscriptionRecord> {
    return this.subs.cancel(id, riderId);
  }
}
