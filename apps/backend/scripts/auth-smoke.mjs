// End-to-end auth smoke: boots the built server and walks the real HTTP flow
// OTP request → verify → refresh → replay-rejection. Works against in-memory
// drivers locally and real Postgres+Redis in CI (via DATABASE_URL/REDIS_URL).
import { spawn } from "node:child_process";

const PORT = 4101;
const BASE = `http://localhost:${PORT}/api/v1`;
const child = spawn(process.execPath, ["dist/main.js"], {
  env: { ...process.env, PORT: String(PORT), OTP_DEV_MODE: "true" },
  stdio: "inherit"
});

async function post(path, body, expectStatus = 200) {
  const res = await fetch(`${BASE}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body)
  });
  if (res.status !== expectStatus) {
    throw new Error(`${path}: expected ${expectStatus}, got ${res.status}: ${await res.text()}`);
  }
  return res.status === 204 ? null : res.json();
}

function shutdown(code) {
  // No process.exit(): forcing exit with live fetch/child handles trips a
  // libuv assertion on Windows. Set the code and let the loop drain.
  process.exitCode = code;
  child.kill();
}

async function waitForBoot() {
  const deadline = Date.now() + 15_000;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(`http://localhost:${PORT}/health`);
      if (res.ok) return;
    } catch {
      await new Promise((r) => setTimeout(r, 300));
    }
  }
  throw new Error("server did not boot in 15s");
}

try {
  await waitForBoot();

  const phone = "0300" + String(Math.floor(Math.random() * 1e7)).padStart(7, "0");

  const req = await post("/auth/otp/request", { phone });
  if (!/^\d{6}$/.test(req.devCode ?? "")) throw new Error("no devCode in dev mode");

  const login = await post("/auth/otp/verify", { phone, code: req.devCode });
  if (!login.accessToken || !login.refreshToken) throw new Error("missing tokens");
  if (!login.user?.id) throw new Error("missing user");

  const rotated = await post("/auth/refresh", { refreshToken: login.refreshToken });
  if (!rotated.accessToken) throw new Error("refresh failed");

  // Spent refresh token must be rejected.
  await post("/auth/refresh", { refreshToken: login.refreshToken }, 401);
  // Wrong OTP must be rejected.
  await post("/auth/otp/verify", { phone, code: "000000" }, 401);
  // Bad phone must 400.
  await post("/auth/otp/request", { phone: "12345678901" }, 400);

  console.log("AUTH SMOKE OK: request → verify → refresh → rotation all behave");
  shutdown(0);
} catch (err) {
  console.error("AUTH SMOKE FAILED:", err.message);
  shutdown(1);
}
