import { Module } from "@nestjs/common";
import { PlacesController } from "./places.controller.js";
import { PlacesRepository } from "./places.repo.js";

@Module({
  controllers: [PlacesController],
  providers: [PlacesRepository],
  // Rides uses the router to store each ride's polyline for corridor matching.
  exports: [PlacesRepository]
})
export class PlacesModule {}
