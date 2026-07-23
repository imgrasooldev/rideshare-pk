import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { PlacesModule } from "../places/places.module.js";
import { UsersController } from "./users.controller.js";
import { UsersService } from "./users.service.js";

@Module({
  // Places supplies the city list that a profile city change is validated against.
  imports: [AuthModule, PlacesModule],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService]
})
export class UsersModule {}
