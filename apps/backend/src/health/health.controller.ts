import { Controller, Get, Inject, Optional } from "@nestjs/common";
import type { Pool } from "pg";
import type { KeyValueStore } from "../shared/kv.js";
import { KV_STORE, PG_POOL } from "../shared/tokens.js";

// Liveness for the load balancer / platform; readiness proves the
// dependencies actually answer so a bad deploy is never routed traffic.
@Controller()
export class HealthController {
  constructor(
    @Optional() @Inject(PG_POOL) private readonly pool: Pool | null,
    @Inject(KV_STORE) private readonly kv: KeyValueStore
  ) {}

  @Get("health")
  health() {
    return { status: "ok", service: "rideshare-backend", uptime: process.uptime() };
  }

  @Get("health/ready")
  async ready() {
    const checks: Record<string, string> = {};

    if (this.pool) {
      try {
        await Promise.race([
          this.pool.query("SELECT 1"),
          new Promise((_, reject) => setTimeout(() => reject(new Error("timeout")), 3000))
        ]);
        checks.database = "ok";
      } catch {
        checks.database = "unreachable";
      }
    } else {
      checks.database = "in-memory (dev)";
    }

    try {
      const probe = `ready:${Date.now()}`;
      await this.kv.set(probe, "1", 5);
      checks.kv = (await this.kv.get(probe)) === "1" ? "ok" : "inconsistent";
    } catch {
      checks.kv = "unreachable";
    }

    const ready = Object.values(checks).every((v) => v !== "unreachable" && v !== "inconsistent");
    return { status: ready ? "ready" : "degraded", checks };
  }
}
