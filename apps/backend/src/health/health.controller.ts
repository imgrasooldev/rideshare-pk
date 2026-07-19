import { Controller, Get } from "@nestjs/common";

// Liveness for the load balancer / platform. Readiness (DB + Redis reachability)
// is added once those clients exist, so a bad deploy is never routed traffic.
@Controller()
export class HealthController {
  @Get("health")
  health() {
    return { status: "ok", service: "rideshare-backend", uptime: process.uptime() };
  }
}
