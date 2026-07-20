import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module.js";
import { loadConfig } from "./config/config.js";

async function bootstrap() {
  const config = loadConfig();
  const app = await NestFactory.create(AppModule);
  // Bearer-token API (no cookies) consumed by the Flutter app and admin web
  // console from browser origins — CORS open by design.
  app.enableCors({ origin: true, methods: "GET,POST,PATCH,DELETE,OPTIONS" });
  app.setGlobalPrefix("api/v1", { exclude: ["health", "health/ready"] });
  app.enableShutdownHooks();
  await app.listen(config.PORT);
  console.log(JSON.stringify({ level: "info", msg: "backend listening", port: config.PORT }));
}

bootstrap().catch((err) => {
  console.error(err);
  process.exit(1);
});
