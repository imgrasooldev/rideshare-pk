import type { NextFunction, Request, Response } from "express";

/**
 * One structured JSON line per HTTP request, emitted on response finish so it
 * captures EVERYTHING — including guard rejections (401/403) and errors, which
 * a NestJS interceptor never sees (guards run before interceptors).
 *
 * Deliberately logs NO bodies, headers, or query strings: OTP codes, passwords
 * and tokens must never reach the log stream. Health probes are skipped to keep
 * the stream signal-dense.
 */
export function requestLogger(req: Request, res: Response, next: NextFunction): void {
  const path = req.originalUrl.split("?")[0];
  if (path === "/health" || path === "/health/ready") return next();

  const start = Date.now();
  res.on("finish", () => {
    const userId = (req as { user?: { sub?: string } }).user?.sub;
    console.log(
      JSON.stringify({
        level: res.statusCode >= 500 ? "error" : res.statusCode >= 400 ? "warn" : "info",
        msg: "http",
        method: req.method,
        path,
        status: res.statusCode,
        ms: Date.now() - start,
        ...(userId ? { userId } : {})
      })
    );
  });

  next();
}
