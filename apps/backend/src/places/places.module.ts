import { Module } from "@nestjs/common";
import { PlacesController } from "./places.controller.js";
import { PlacesRepository } from "./places.repo.js";

@Module({
  controllers: [PlacesController],
  providers: [PlacesRepository]
})
export class PlacesModule {}
