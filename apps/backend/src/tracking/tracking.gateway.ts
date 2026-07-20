import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway
} from "@nestjs/websockets";
import type { Socket } from "socket.io";
import { TokenService } from "../auth/token.service.js";
import { TrackingService } from "./tracking.service.js";

interface TrackedSocket extends Socket {
  data: {
    userId?: string;
    rideId?: string;
    unsubscribe?: () => Promise<void>;
  };
}

/**
 * WS /trips (socket.io): driver publishes `location`, riders receive
 * `location`/`ended` events. Fan-out crosses instances via the message bus,
 * so any replica can serve any subscriber (rule 4).
 *
 * Client contract:
 *   io(`${API}/trips`, { auth: { token: <accessToken>, rideId } })
 *   socket.emit('location', { lat, lng })      // driver only
 *   socket.on('location', ({ lat, lng, at }) => ...)
 *   socket.on('ended', () => ...)
 */
@WebSocketGateway({ namespace: "trips", cors: { origin: true } })
export class TrackingGateway implements OnGatewayConnection, OnGatewayDisconnect {
  constructor(
    private readonly tokens: TokenService,
    private readonly tracking: TrackingService
  ) {}

  async handleConnection(client: TrackedSocket) {
    try {
      const { token, rideId } = client.handshake.auth as { token?: string; rideId?: string };
      if (!token || !rideId) throw new Error("token and rideId required");
      const claims = this.tokens.verifyAccess(token);
      client.data.userId = claims.sub;
      client.data.rideId = rideId;

      // Fan-in from the backplane to this socket.
      client.data.unsubscribe = await this.tracking.subscribe(rideId, (message) => {
        const event = JSON.parse(message) as { type: string } & Record<string, unknown>;
        if (event.type === "location") {
          client.emit("location", { lat: event.lat, lng: event.lng, at: event.at });
        } else if (event.type === "ended") {
          client.emit("ended", {});
        }
      });

      // Late joiners immediately get the last known position.
      const last = await this.tracking.lastLocation(rideId);
      if (last) client.emit("location", last);
    } catch (err) {
      client.emit("error", { message: (err as Error).message });
      client.disconnect(true);
    }
  }

  async handleDisconnect(client: TrackedSocket) {
    await client.data.unsubscribe?.();
  }

  @SubscribeMessage("location")
  async onLocation(
    @ConnectedSocket() client: TrackedSocket,
    @MessageBody() body: { lat?: number; lng?: number }
  ) {
    const { userId, rideId } = client.data;
    if (!userId || !rideId) return { ok: false, error: "unauthenticated" };
    if (typeof body?.lat !== "number" || typeof body?.lng !== "number") {
      return { ok: false, error: "lat/lng required" };
    }
    try {
      const accepted = await this.tracking.publishLocation(userId, rideId, body.lat, body.lng);
      return { ok: true, accepted };
    } catch (err) {
      return { ok: false, error: (err as { message?: string }).message ?? "rejected" };
    }
  }
}
