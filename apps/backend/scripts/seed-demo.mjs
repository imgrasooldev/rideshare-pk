// Rich demo data for all screens: named riders, vehicles, bookings (so the
// primary demo account has upcoming rides), ratings, pending verifications, and
// a live trip. Idempotent. Usage: DATABASE_URL=... node scripts/seed-demo.mjs
import pg from "pg";

const url = process.env.DATABASE_URL;
if (!url) { console.error("DATABASE_URL required"); process.exit(1); }
const db = new pg.Client({ connectionString: url });
await db.connect();

const q = (text, params) => db.query(text, params);
const one = async (text, params) => (await q(text, params)).rows[0];

try {
  // --- Named demo riders (so lists show real names, not phones) ---
  const RIDERS = [
    ["+923410000000", "Ayesha Khan", "female", "lahore"],
    ["+923410000001", "Bilal Ahmed", "male", "lahore"],
    ["+923410000002", "Fatima Noor", "female", "karachi"],
    ["+923410000003", "Usman Ali", "male", "karachi"],
    ["+923410000004", "Sara Malik", "female", "lahore"],
    ["+923410000005", "Hamza Sheikh", "male", "islamabad"]
  ];
  const riderIds = [];
  for (const [phone, name, gender, city] of RIDERS) {
    const row = await one(
      `INSERT INTO users (phone, name, role, gender, verified, city)
       VALUES ($1,$2,'rider',$3,true,$4)
       ON CONFLICT (phone) DO UPDATE SET name=$2, gender=$3, city=$4, verified=true
       RETURNING id`,
      [phone, name, gender, city]
    );
    riderIds.push(row.id);
  }

  // --- Primary demo account (Seed Driver 1) gets a real name + vehicle ---
  const main = await one(
    `UPDATE users SET name='Ali Raza', role='both', verified=true
     WHERE phone='+923400000000' RETURNING id`
  );
  const mainId = main?.id;

  // Vehicles for the primary account and a few seed drivers.
  const drivers = (await q(
    `SELECT id, phone FROM users WHERE role IN ('driver','both') ORDER BY phone LIMIT 8`
  )).rows;
  const VEHICLES = [
    ["car", "Toyota", "Corolla", "LEA-1786", 4],
    ["car", "Honda", "City", "LEB-4521", 4],
    ["car", "Suzuki", "WagonR", "LEC-9034", 4],
    ["hiace", "Toyota", "Hiace", "LED-2210", 12],
    ["minivan", "Suzuki", "APV", "LEE-7788", 7]
  ];
  let vi = 0;
  for (const d of drivers) {
    const [vt, make, model, plate, seats] = VEHICLES[vi % VEHICLES.length];
    await q(
      `INSERT INTO vehicles (owner_id, vehicle_type, make, model, plate, seats, verified)
       VALUES ($1,$2,$3,$4,$5,$6,true)
       ON CONFLICT DO NOTHING`,
      [d.id, vt, make, model, `${plate}`, seats]
    );
    vi++;
  }

  // --- Bookings: give the primary account upcoming rides (as a rider) on other
  // people's open rides, plus bookings from the named riders across the board.
  const openRides = (await q(
    `SELECT id, driver_id, seats_total, city FROM rides
     WHERE status='open' ORDER BY depart_at LIMIT 40`
  )).rows;

  const book = async (rideId, riderId, seats, status) =>
    q(
      `INSERT INTO bookings (ride_id, rider_id, seats, status, idempotency_key)
       VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (rider_id, idempotency_key) DO NOTHING`,
      [rideId, riderId, seats, status, `demo-${rideId}`]
    );

  // Primary account books 2 upcoming Lahore rides it doesn't own.
  const forMain = openRides.filter((r) => r.driver_id !== mainId && r.city === "lahore").slice(0, 2);
  for (const r of forMain) await book(r.id, mainId, 1, "confirmed");

  // Named riders book rides in their own city where possible.
  const ridersByCity = { lahore: [], karachi: [], islamabad: [] };
  RIDERS.forEach(([, , , city], i) => (ridersByCity[city] ??= []).push(riderIds[i]));
  let booked = 0;
  for (const r of openRides) {
    const pool = ridersByCity[r.city] ?? riderIds;
    if (!pool.length) continue;
    const rider = pool[booked % pool.length];
    if (rider === r.driver_id) continue;
    await book(r.id, rider, 1 + (booked % 2), "confirmed");
    booked++;
  }

  // Keep seats_available consistent with the bookings we just made.
  await q(
    `UPDATE rides r SET seats_available = GREATEST(0, seats_total - COALESCE((
        SELECT SUM(seats) FROM bookings b
        WHERE b.ride_id = r.id AND b.status IN ('confirmed','completed')), 0))
     WHERE r.status='open'`
  );

  // --- Ratings: named riders rate drivers 4-5 stars; refresh user aggregates ---
  const rateTargets = (await q(
    `SELECT id, driver_id FROM rides ORDER BY depart_at LIMIT 20`
  )).rows;
  const COMMENTS = ["Great ride, on time!", "Very polite driver", "Comfortable and safe",
    "Highly recommended", "Smooth trip", null];
  let ri = 0;
  for (const r of rateTargets) {
    const from = riderIds[ri % riderIds.length];
    if (from === r.driver_id) { ri++; continue; }
    await q(
      `INSERT INTO ratings (ride_id, from_user_id, to_user_id, stars, comment)
       VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (ride_id, from_user_id, to_user_id) DO NOTHING`,
      [r.id, from, r.driver_id, 4 + (ri % 2), COMMENTS[ri % COMMENTS.length]]
    );
    ri++;
  }
  await q(
    `UPDATE users u SET
        rating_avg = COALESCE((SELECT ROUND(AVG(stars)::numeric,2) FROM ratings WHERE to_user_id=u.id),0),
        rating_count = COALESCE((SELECT COUNT(*) FROM ratings WHERE to_user_id=u.id),0)`
  );

  // --- Pending verifications (admin queue) for a couple of accounts ---
  const pend = (await q(
    `SELECT id FROM users WHERE role IN ('driver','both') ORDER BY phone LIMIT 3`
  )).rows;
  for (const u of pend) {
    for (const type of ["cnic", "license"]) {
      await q(
        `INSERT INTO verifications (user_id, type, doc_url, status)
         SELECT $1,$2,$3,'pending'
         WHERE NOT EXISTS (SELECT 1 FROM verifications WHERE user_id=$1 AND type=$2)`,
        [u.id, type, `https://example.com/docs/${type}-${u.id}.jpg`]
      );
    }
  }

  // --- One live trip for the tracking screen ---
  if (openRides[0]) {
    await q(
      `INSERT INTO trips (ride_id, started_at, live_status)
       SELECT $1, now(), 'live'
       WHERE NOT EXISTS (SELECT 1 FROM trips WHERE ride_id=$1)`,
      [openRides[0].id]
    );
  }

  const counts = await one(
    `SELECT
       (SELECT COUNT(*) FROM users) users,
       (SELECT COUNT(*) FROM vehicles) vehicles,
       (SELECT COUNT(*) FROM bookings) bookings,
       (SELECT COUNT(*) FROM ratings) ratings,
       (SELECT COUNT(*) FROM verifications WHERE status='pending') pending_verifs,
       (SELECT COUNT(*) FROM trips WHERE live_status='live') live_trips`
  );
  console.log("DEMO SEED DONE:", counts);
} finally {
  await db.end();
}
