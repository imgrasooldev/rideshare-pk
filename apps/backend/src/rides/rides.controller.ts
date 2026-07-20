import { Body, Controller, Get, Param, Post, Query, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { parse } from "../shared/validation.js";
import { RidesService } from "./rides.service.js";

const lat = z.coerce.number().min(-90).max(90);
const lng = z.coerce.number().min(-180).max(180);

const postRideDto = z.object({
  originLabel: z.string().trim().min(3).max(120),
  originLat: lat,
  originLng: lng,
  destLabel: z.string().trim().min(3).max(120),
  destLat: lat,
  destLng: lng,
  departAt: z.string().datetime({ offset: true }),
  recurringDays: z.array(z.number().int().min(0).max(6)).max(7).default([]),
  seatsTotal: z.number().int().min(1).max(20),
  pricePerSeat: z.number().int().min(0).max(100_000),
  vehicleId: z.string().nullish(),
  vertical: z
    .enum(["office", "school", "city", "rentacar", "ladies", "parcel", "corporate", "airport", "events"])
    .default("office"),
  vehicleType: z.enum(["car", "bike", "hiace", "minivan"]).default("car"),
  ladiesOnly: z.boolean().default(false)
});

const searchDto = z.object({
  pickupLat: lat,
  pickupLng: lng,
  dropLat: lat,
  dropLng: lng,
  radiusKm: z.coerce.number().min(0.1).max(25).default(3),
  departAfter: z.string().datetime({ offset: true }),
  departBefore: z.string().datetime({ offset: true }),
  ladiesOnly: z
    .enum(["true", "false"])
    .optional()
    .transform((v) => (v === undefined ? undefined : v === "true")),
  vehicleType: z.enum(["car", "bike", "hiace", "minivan"]).optional(),
  city: z.string().optional(),
  cursor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20)
});

@Controller("rides")
export class RidesController {
  constructor(private readonly rides: RidesService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  post(@Req() req: AuthedRequest, @Body() body: unknown) {
    const dto = parse(postRideDto, body);
    return this.rides.post(req.user.sub, { ...dto, vehicleId: dto.vehicleId ?? null });
  }

  @Get("search")
  @UseGuards(JwtAuthGuard)
  search(@Query() query: unknown) {
    const dto = parse(searchDto, query);
    return this.rides.search({
      pickupLat: dto.pickupLat,
      pickupLng: dto.pickupLng,
      dropLat: dto.dropLat,
      dropLng: dto.dropLng,
      radiusM: Math.round(dto.radiusKm * 1000),
      departAfter: dto.departAfter,
      departBefore: dto.departBefore,
      ladiesOnly: dto.ladiesOnly,
      vehicleType: dto.vehicleType,
      city: dto.city,
      cursor: dto.cursor ?? null,
      limit: dto.limit
    });
  }

  @Get("mine")
  @UseGuards(JwtAuthGuard)
  mine(@Req() req: AuthedRequest, @Query("cursor") cursor?: string, @Query("limit") limit?: string) {
    const n = Math.min(Math.max(Number(limit) || 20, 1), 50);
    return this.rides.myRides(req.user.sub, cursor ?? null, n);
  }

  @Get(":id")
  @UseGuards(JwtAuthGuard)
  get(@Param("id") id: string) {
    return this.rides.getById(id);
  }
}
