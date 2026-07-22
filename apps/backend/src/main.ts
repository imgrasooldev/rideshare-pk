import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module.js";
import { loadConfig } from "./config/config.js";

async function bootstrap() {
  const config = loadConfig();

  // Loud, unmissable warning: a production deploy with no real OTP provider
  // means anyone can read verification codes straight from the API response.
  if (config.NODE_ENV === "production" && config.SMS_PROVIDER === "dev") {
    console.warn(
      "SECURITY: SMS_PROVIDER=dev in production — OTP codes are returned by the API " +
        "and no SMS is sent. Set SMS_PROVIDER + credentials and OTP_DEV_MODE=false."
    );
  }

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
