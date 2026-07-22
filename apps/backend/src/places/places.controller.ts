import { Controller, Get, Query } from "@nestjs/common";
import { PlacesRepository } from "./places.repo.js";

// Public: the app loads cities/hubs to build pickup/drop pickers, including
// before login, so no auth guard here.
@Controller()
export class PlacesController {
  constructor(private readonly places: PlacesRepository) {}

  @Get("cities")
  cities() {
    return this.places.cities();
  }

  @Get("hubs")
  hubs(@Query("city") city?: string) {
    return this.places.hubs((city ?? "lahore").trim().toLowerCase());
  }

  // Free-text address search (any address, not just curated hubs).
  @Get("places/search")
  search(@Query("q") q?: string, @Query("city") city?: string) {
    return this.places.search((q ?? "").trim(), city?.trim());
  }
}
