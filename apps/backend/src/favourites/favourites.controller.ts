import { Body, Controller, Delete, Get, HttpCode, Param, Post, Req, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { JwtAuthGuard, type AuthedRequest } from "../auth/jwt-auth.guard.js";
import { parse } from "../shared/validation.js";
import { FavouritesService } from "./favourites.service.js";

const saveRouteDto = z.object({
  label: z.string().trim().max(60).optional(),
  originLabel: z.string().trim().min(1).max(200),
  originLat: z.number().optional(),
  originLng: z.number().optional(),
  destLabel: z.string().trim().min(1).max(200),
  destLat: z.number().optional(),
  destLng: z.number().optional()
});

@Controller()
@UseGuards(JwtAuthGuard)
export class FavouritesController {
  constructor(private readonly favourites: FavouritesService) {}

  // --- Saved routes ---

  @Get("saved-routes")
  listRoutes(@Req() req: AuthedRequest) {
    return this.favourites.listRoutes(req.user.sub);
  }

  @Post("saved-routes")
  saveRoute(@Req() req: AuthedRequest, @Body() body: unknown) {
    const dto = parse(saveRouteDto, body);
    return this.favourites.saveRoute(req.user.sub, dto);
  }

  @Delete("saved-routes/:id")
  deleteRoute(@Req() req: AuthedRequest, @Param("id") id: string) {
    return this.favourites.deleteRoute(req.user.sub, id);
  }

  // --- Favourite drivers ---

  @Get("favourites")
  listFavourites(@Req() req: AuthedRequest) {
    return this.favourites.listFavourites(req.user.sub);
  }

  @Post("favourites/:driverId")
  @HttpCode(200)
  addFavourite(@Req() req: AuthedRequest, @Param("driverId") driverId: string) {
    return this.favourites.addFavourite(req.user.sub, driverId);
  }

  @Delete("favourites/:driverId")
  removeFavourite(@Req() req: AuthedRequest, @Param("driverId") driverId: string) {
    return this.favourites.removeFavourite(req.user.sub, driverId);
  }
}
