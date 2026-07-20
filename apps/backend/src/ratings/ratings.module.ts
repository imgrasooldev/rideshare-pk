import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { RatingsController } from "./ratings.controller.js";
import { RatingsService } from "./ratings.service.js";

@Module({
  imports: [AuthModule],
  controllers: [RatingsController],
  providers: [RatingsService],
  exports: [RatingsService]
})
export class RatingsModule {}
