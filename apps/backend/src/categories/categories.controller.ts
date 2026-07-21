import { Controller, Get } from "@nestjs/common";
import { CategoriesService } from "./categories.service.js";

@Controller("categories")
export class CategoriesController {
  constructor(private readonly categories: CategoriesService) {}

  // Public: the app renders the category grid pre- and post-login.
  @Get()
  list() {
    return this.categories.list();
  }
}
