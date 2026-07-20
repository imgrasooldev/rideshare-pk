import { Body, Controller, Get, HttpCode, Param, Post, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { parse } from "../shared/validation.js";
import { TrackingService } from "./tracking.service.js";

const locationDto = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180)
});

@Controller("trips")
export class TripsController {
  constructor(private readonly tracking: TrackingService) {}

  @Post(":rideId/start")
  @HttpCode(200)
  @UseGuards(JwtAuthGuard)
  start(@Req() req: AuthedRequest, @Param("rideId") rideId: string) {
    return this.tracking.start(req.user.sub, rideId);
  }

  @Post(":rideId/end")
  @HttpCode(200)
  @UseGuards(JwtAuthGuard)
  end(@Req() req: AuthedRequest, @Param("rideId") rideId: string) {
    return this.tracking.end(req.user.sub, rideId);
  }

  /** REST fallback for the driver's location ping (same throttle as WS). */
  @Post(":rideId/location")
  @HttpCode(200)
  @UseGuards(JwtAuthGuard)
  async ping(
    @Req() req: AuthedRequest,
    @Param("rideId") rideId: string,
    @Body() body: unknown
  ) {
    const dto = parse(locationDto, body);
    const accepted = await this.tracking.publishLocation(req.user.sub, rideId, dto.lat, dto.lng);
    return { accepted };
  }

  /** Riders poll or WS-subscribe; this is the poll fallback. */
  @Get(":rideId/location")
  @UseGuards(JwtAuthGuard)
  async location(@Param("rideId") rideId: string) {
    return {
      trip: await this.tracking.liveTrip(rideId),
      location: await this.tracking.lastLocation(rideId)
    };
  }

  /** PUBLIC share-my-trip link — no auth by design (family safety link). */
  @Get("shared/:token")
  shared(@Param("token") token: string) {
    return this.tracking.sharedView(token);
  }
}
