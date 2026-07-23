import {
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException
} from "@nestjs/common";
import type { MessageBus } from "../shared/bus.js";
import type { KeyValueStore } from "../shared/kv.js";
import {
  BOOKING_REPOSITORY,
  BUS,
  KV_STORE,
  RIDE_REPOSITORY,
  TRIP_REPOSITORY
} from "../shared/tokens.js";
import type { BookingRepository } from "../bookings/bookings.repo.js";
import { NotificationsService } from "../notifications/notifications.service.js";
import type { RideRepository } from "../rides/rides.repo.js";
import type { TripRecord, TripRepository } from "./trips.repo.js";

export interface LiveLocation {
  lat: number;
  lng: number;
  at: string; // ISO timestamp
}

const LOCATION_TTL_S = 90; // stale locations disappear on their own
const MIN_PING_INTERVAL_MS = 3_000; // rule 4: throttle location writes

@Injectable()
export class TrackingService {
  constructor(
    @Inject(TRIP_REPOSITORY) private readonly trips: TripRepository,
    @Inject(RIDE_REPOSITORY) private readonly rides: RideRepository,
    @Inject(KV_STORE) private readonly kv: KeyValueStore,
    @Inject(BUS) private readonly bus: MessageBus,
    @Inject(BOOKING_REPOSITORY) private readonly bookings: BookingRepository,
    private readonly notifications: NotificationsService
  ) {}

  private readonly lastPingAt = new Map<string, number>(); // rideId → epoch ms

  channel(rideId: string): string {
    return `trip:${rideId}`;
  }

  private async requireOwnRide(driverId: string, rideId: string) {
    const ride = await this.rides.findById(rideId);
    if (!ride) throw new NotFoundException("Ride not found");
    if (ride.driverId !== driverId) throw new ForbiddenException("Not your ride");
    return ride;
  }

  async start(driverId: string, rideId: string): Promise<TripRecord> {
    await this.requireOwnRide(driverId, rideId);
    return this.trips.start(rideId);
  }

  async end(driverId: string, rideId: string): Promise<TripRecord> {
    await this.requireOwnRide(driverId, rideId);
    const trip = await this.trips.end(rideId);
    if (!trip) throw new NotFoundException("No live trip for this ride");
    await this.kv.del(`trip:loc:${rideId}`);
    await this.bus.publish(this.channel(rideId), JSON.stringify({ type: "ended" }));
    this.lastPingAt.delete(rideId);

    // Trip over: settle the bookings and nudge each rider to rate.
    const ride = await this.rides.findById(rideId);
    const completed = await this.bookings.completeRide(rideId);
    for (const b of completed) {
      void this.notifications.notify(
        b.riderId,
        "trip_completed",
        "How was your trip?",
        ride ? `Rate your ride · ${ride.originLabel} → ${ride.destLabel}` : "Rate your ride",
        { rideId, bookingId: b.id }
      );
    }
    return trip;
  }

  /**
   * Driver location ping. Throttled per ride; stored in KV with TTL (never
   * Postgres) and fanned out over the bus. Returns false when dropped.
   */
  async publishLocation(driverId: string, rideId: string, lat: number, lng: number): Promise<boolean> {
    const now = Date.now();
    const last = this.lastPingAt.get(rideId) ?? 0;
    if (now - last < MIN_PING_INTERVAL_MS) return false;

    await this.requireOwnRide(driverId, rideId);
    const trip = await this.trips.findLiveByRide(rideId);
    if (!trip) throw new NotFoundException("Start the trip before sending locations");

    this.lastPingAt.set(rideId, now);
    const location: LiveLocation = { lat, lng, at: new Date(now).toISOString() };
    await this.kv.set(`trip:loc:${rideId}`, JSON.stringify(location), LOCATION_TTL_S);
    await this.bus.publish(
      this.channel(rideId),
      JSON.stringify({ type: "location", ...location })
    );
    return true;
  }

  /** Subscribe to a ride's live events; returns the unsubscribe function. */
  subscribe(rideId: string, handler: (message: string) => void): Promise<() => Promise<void>> {
    return this.bus.subscribe(this.channel(rideId), handler);
  }

  async lastLocation(rideId: string): Promise<LiveLocation | null> {
    const raw = await this.kv.get(`trip:loc:${rideId}`);
    return raw ? (JSON.parse(raw) as LiveLocation) : null;
  }

  async liveTrip(rideId: string): Promise<TripRecord | null> {
    return this.trips.findLiveByRide(rideId);
  }

  /** Public share-my-trip view: safe subset, no auth (family link). */
  async sharedView(token: string) {
    const trip = await this.trips.findByShareToken(token);
    if (!trip) throw new NotFoundException("Trip link is invalid or expired");
    const ride = await this.rides.findById(trip.rideId);
    return {
      status: trip.liveStatus,
      startedAt: trip.startedAt,
      endedAt: trip.endedAt,
      originLabel: ride?.originLabel,
      destLabel: ride?.destLabel,
      location: trip.liveStatus === "live" ? await this.lastLocation(trip.rideId) : null
    };
  }
}
