// End-to-end API smoke for steps 2+3: auth → profile → vehicle → verification
// → admin queue → approve → verified badge. Admin flip needs DATABASE_URL
// (skipped gracefully on in-memory dev runs).
import { spawn } from "node:child_process";

const PORT = 4102;
const BASE = `http://localhost:${PORT}/api/v1`;
const child = spawn(process.execPath, ["dist/main.js"], {
  env: { ...process.env, PORT: String(PORT), OTP_DEV_MODE: "true" },
  stdio: "inherit"
});

function shutdown(code) {
  process.exitCode = code;
  child.kill();
}

async function call(method, path, { body, token, expectStatus = 200 } = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      ...(body ? { "content-type": "application/json" } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {})
    },
    body: body ? JSON.stringify(body) : undefined
  });
  if (res.status !== expectStatus) {
    throw new Error(`${method} ${path}: expected ${expectStatus}, got ${res.status}: ${await res.text()}`);
  }
  return res.json().catch(() => null);
}

async function loginAs(phone) {
  const req = await call("POST", "/auth/otp/request", { body: { phone } });
  const login = await call("POST", "/auth/otp/verify", { body: { phone, code: req.devCode } });
  return login;
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

  const rnd = () => String(Math.floor(Math.random() * 1e7)).padStart(7, "0");
  const driverPhone = "0300" + rnd();

  // Profile
  const driver = await loginAs(driverPhone);
  const t = driver.accessToken;
  await call("GET", "/me", { token: undefined, expectStatus: 401 });
  const me0 = await call("GET", "/me", { token: t });
  if (me0.cnicMasked !== null) throw new Error("fresh user should have no cnic");

  const me1 = await call("PATCH", "/me", {
    token: t,
    body: { name: "Smoke Driver", role: "driver", gender: "male", cnic: "35202-1234567-1" }
  });
  if (me1.role !== "driver" || me1.cnicMasked !== "*********5671") {
    throw new Error(`profile update wrong: ${JSON.stringify(me1)}`);
  }
  await call("PATCH", "/me", { token: t, body: { cnic: "123" }, expectStatus: 400 });

  // Vehicle
  const vehicle = await call("POST", "/vehicles", {
    token: t,
    body: { make: "Suzuki", model: "Alto", plate: "leb-1234", seats: 4, docUrls: [] },
    expectStatus: 201
  });
  if (vehicle.plate !== "LEB-1234") throw new Error("plate not normalised");
  const mine = await call("GET", "/vehicles/mine", { token: t });
  if (mine.length !== 1) throw new Error("vehicle list wrong");

  // Verification submit
  const ver = await call("POST", "/verifications", {
    token: t,
    body: { type: "cnic", docUrl: "https://example.com/cnic-front.jpg" },
    expectStatus: 201
  });
  if (ver.status !== "pending") throw new Error("verification should be pending");

  // Admin queue is locked down
  await call("GET", "/admin/verifications", { token: t, expectStatus: 403 });

  if (process.env.DATABASE_URL) {
    // Flip a second user to admin directly in the DB, then run the review flow.
    const adminPhone = "0301" + rnd();
    const admin = await loginAs(adminPhone);
    const pg = await import("pg");
    const dbc = new pg.default.Client({ connectionString: process.env.DATABASE_URL });
    await dbc.connect();
    await dbc.query("UPDATE users SET is_admin = true WHERE id = $1", [admin.user.id]);
    await dbc.end();

    const queue = await call("GET", "/admin/verifications?limit=50", { token: admin.accessToken });
    const ours = queue.items.find((v) => v.id === ver.id);
    if (!ours) throw new Error("submitted verification not in admin queue");

    const reviewed = await call("POST", `/admin/verifications/${ver.id}`, {
      token: admin.accessToken,
      body: { action: "approve", notes: "smoke approval" }
    });
    if (reviewed.status !== "approved") throw new Error("approve failed");

    const meAfter = await call("GET", "/me", { token: t });
    if (meAfter.verified !== true) throw new Error("verified badge not set after approval");

    // Now verified — post a ride (Gulberg → DHA 5) and find it via geo search.
    const departAt = new Date(Date.now() + 24 * 3600 * 1000).toISOString();
    const ride = await call("POST", "/rides", {
      token: t,
      expectStatus: 201,
      body: {
        originLabel: "Gulberg Liberty Market", originLat: 31.5102, originLng: 74.3441,
        destLabel: "DHA Phase 5", destLat: 31.4622, destLng: 74.4082,
        departAt, recurringDays: [1, 2, 3, 4, 5], seatsTotal: 3, pricePerSeat: 250
      }
    });
    if (ride.seatsAvailable !== 3) throw new Error("ride seats wrong");

    const search = await call(
      "GET",
      `/rides/search?pickupLat=31.515&pickupLng=74.35&dropLat=31.465&dropLng=74.405&radiusKm=3` +
        `&departAfter=${encodeURIComponent(new Date(Date.now() + 12 * 3600 * 1000).toISOString())}` +
        `&departBefore=${encodeURIComponent(new Date(Date.now() + 36 * 3600 * 1000).toISOString())}`,
      { token: t }
    );
    if (!search.items.some((r) => r.id === ride.id)) {
      throw new Error("posted ride not found by geo search");
    }
    const got = await call("GET", `/rides/${ride.id}`, { token: t });
    if (got.originLabel !== "Gulberg Liberty Market") throw new Error("get ride wrong");

    console.log("API SMOKE OK (admin review + ride post/search against real DB)");
  } else {
    // In-memory mode can't flip admin — but the driver-verification gate must hold.
    await call("POST", "/rides", {
      token: t,
      expectStatus: 403,
      body: {
        originLabel: "Gulberg", originLat: 31.51, originLng: 74.34,
        destLabel: "DHA", destLat: 31.46, destLng: 74.41,
        departAt: new Date(Date.now() + 3600_000).toISOString(),
        seatsTotal: 3, pricePerSeat: 200
      }
    });
    console.log("API SMOKE OK (in-memory; admin+ride flow needs DATABASE_URL)");
  }

  shutdown(0);
} catch (err) {
  console.error("API SMOKE FAILED:", err.message);
  shutdown(1);
}
