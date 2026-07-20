import { Body, Controller, Get, Inject, Post, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { VEHICLE_REPOSITORY } from "../shared/tokens.js";
import { parse } from "../shared/validation.js";
import type { VehicleRepository } from "./vehicles.repo.js";

const createVehicleDto = z.object({
  vehicleType: z.enum(["car", "bike", "hiace", "minivan"]).default("car"),
  make: z.string().trim().min(2).max(40),
  model: z.string().trim().min(1).max(40),
  plate: z
    .string()
    .trim()
    .min(3)
    .max(12)
    .regex(/^[A-Za-z0-9 -]+$/, "plate may contain letters, digits, spaces, dashes"),
  seats: z.number().int().min(1).max(20),
  docUrls: z.array(z.string().url()).max(10).default([])
});

@Controller("vehicles")
@UseGuards(JwtAuthGuard)
export class VehiclesController {
  constructor(@Inject(VEHICLE_REPOSITORY) private readonly vehicles: VehicleRepository) {}

  @Post()
  async create(@Req() req: AuthedRequest, @Body() body: unknown) {
    const dto = parse(createVehicleDto, body);
    return this.vehicles.create(req.user.sub, { ...dto, plate: dto.plate.toUpperCase() });
  }

  @Get("mine")
  mine(@Req() req: AuthedRequest) {
    return this.vehicles.listByOwner(req.user.sub);
  }
}
