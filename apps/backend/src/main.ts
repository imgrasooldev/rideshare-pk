import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module.js";
import { loadConfig } from "./config/config.js";

async function bootstrap() {
  const config = loadConfig();
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix("api/v1", { exclude: ["health"] });
  app.enableShutdownHooks();
  await app.listen(config.PORT);
  console.log(JSON.stringify({ level: "info", msg: "backend listening", port: config.PORT }));
}

bootstrap().catch((err) => {
  console.error(err);
  process.exit(1);
});
