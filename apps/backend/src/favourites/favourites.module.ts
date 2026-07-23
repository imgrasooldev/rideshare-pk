import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { FavouritesController } from "./favourites.controller.js";
import { FavouritesService } from "./favourites.service.js";

@Module({
  imports: [AuthModule], // exports JwtAuthGuard's TokenService
  controllers: [FavouritesController],
  providers: [FavouritesService],
  exports: [FavouritesService]
})
export class FavouritesModule {}
