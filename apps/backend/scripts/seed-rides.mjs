// Seeds a full week of upcoming rides so search and "live near you" (which
// query a single future day) always find results. Uses exact hub coordinates
// from the DB so geo-corridor matching hits.
//
// Usage:
//   DATABASE_URL=... node scripts/seed-rides.mjs              # every city
//   DATABASE_URL=... node scripts/seed-rides.mjs --city=karachi
//
// Re-running replaces the previous seed for the cities being seeded. Rides
// that someone has actually booked are never cancelled - see keepIds below.
import pg from "pg";

const url = process.env.DATABASE_URL;
if (!url) { console.error("DATABASE_URL required"); process.exit(1); }

const cityArg = process.argv.find((a) => a.startsWith("--city="))?.slice(7)?.toLowerCase();

const db = new pg.Client({ connectionString: url });
await db.connect();

const TYPES = ["car", "car", "bike", "hiace", "car", "minivan", "car"];
const seatsFor = (t, i) => (t === "bike" ? 1 : t === "hiace" ? 12 : t === "minivan" ? 7 : 3 + (i % 2));
const HOURS = ["08", "18"];
const DAYS = [1, 2, 3, 4, 5];

// Real commuter corridors, written as one-way pairs (residential -> workplace);
// the reverse leg is added automatically. Without this we fall back to a ring
// through the hub list, which connects whatever hubs happen to sort next to
// each other and misses the routes people actually travel.
const CURATED = {
  karachi: [
    // Northern belt into the business district and city centre
    ["North Nazimabad", "II Chundrigar Road"],
    ["North Nazimabad", "Saddar"],
    ["Nazimabad", "II Chundrigar Road"],
    ["Federal B Area", "Saddar"],
    ["Surjani Town", "SITE Industrial Area"],
    ["Surjani Town", "North Nazimabad"],
    // Eastern residential sprawl
    ["Gulshan-e-Iqbal", "II Chundrigar Road"],
    ["Gulshan-e-Iqbal", "Clifton"],
    ["Gulistan-e-Johar", "II Chundrigar Road"],
    ["Gulistan-e-Johar", "Clifton"],
    ["Karachi University", "Gulshan-e-Iqbal"],
    ["Malir Cantt", "Saddar"],
    ["Malir Cantt", "Shahrah-e-Faisal"],
    // Industrial belt
    ["Landhi", "Korangi"],
    ["Korangi", "Clifton"],
    ["Port Qasim", "Korangi"],
    // Southern / DHA
    ["DHA Phase 5", "II Chundrigar Road"],
    ["DHA Phase 5", "Clifton"],
    ["Tariq Road", "II Chundrigar Road"],
    ["Bahadurabad", "Saddar"],
    // Long-haul suburb
    ["Bahria Town Karachi", "Saddar"],
    ["Bahria Town Karachi", "Clifton"],
    // Airport runs
    ["Jinnah Intl Airport", "Saddar"],
    ["Jinnah Intl Airport", "Clifton"],
    ["Jinnah Intl Airport", "DHA Phase 5"],
    // Northern Superhighway growth belt (Maymar / Ahsanabad)
    ["Gulshan-e-Maymar", "Saddar"],
    ["Gulshan-e-Maymar", "II Chundrigar Road"],
    ["Ahsanabad", "Garden"],
    ["Ahsanabad", "Saddar"],
    ["Gulshan-e-Maymar", "Gulshan-e-Iqbal"]
  ]
};

/** Straight-line km between two hubs. */
function distanceKm(a, b) {
  const R = 6371;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}

/**
 * Per-seat cash fare, rounded to Rs 10. A flat fare made a 40 km Bahria Town
 * run cost the same as a 5 km hop, which is the first thing a real user would
 * notice. Shared vehicles cost less per seat because the cost splits further.
 */
function fareFor(km, vehicleType) {
  const perKm = vehicleType === "bike" ? 8 : vehicleType === "hiace" ? 9 : vehicleType === "minivan" ? 10 : 14;
  const base = vehicleType === "bike" ? 30 : 50;
  return Math.max(50, Math.round((base + km * perKm) / 10) * 10);
}

try {
  const hubRows = (await db.query(`SELECT city, label, lat, lng FROM hubs ORDER BY city, sort`)).rows;
  const byCity = {};
  for (const h of hubRows) (byCity[h.city] ??= []).push(h);

  const cities = cityArg ? [cityArg] : Object.keys(byCity);
  for (const c of cities) {
    if (!byCity[c]) { console.error(`unknown city: ${c}`); process.exitCode = 1; }
  }
  if (process.exitCode) throw new Error("aborting");

  const allDrivers = (await db.query(
    `SELECT id, gender, city FROM users WHERE role IN ('driver','both') AND verified=true ORDER BY phone`
  )).rows;
  if (!allDrivers.length) {
    allDrivers.push(...(await db.query(
      `INSERT INTO users (phone,name,role,gender,verified,city)
       VALUES ('+923990000000','Seed Driver X','driver','male',true,'lahore') RETURNING id, gender, city`
    )).rows);
  }

  // Build corridors per city: curated pairs where we have them, ring otherwise.
  const corridors = [];
  for (const city of cities) {
    const hubs = byCity[city];
    if (hubs.length < 2) continue;
    const curated = CURATED[city];

    if (curated) {
      const byLabel = new Map(hubs.map((h) => [h.label, h]));
      for (const [fromLabel, toLabel] of curated) {
        const from = byLabel.get(fromLabel);
        const to = byLabel.get(toLabel);
        // A curated pair naming a hub that isn't in the DB is a typo, not a
        // reason to silently seed fewer routes.
        if (!from || !to) {
          console.warn(`  skipped ${city}: "${fromLabel}" -> "${toLabel}" (hub not found)`);
          continue;
        }
        corridors.push([city, from, to]);
        corridors.push([city, to, from]);
      }
    } else {
      for (let i = 0; i < hubs.length; i++) {
        corridors.push([city, hubs[i], hubs[(i + 1) % hubs.length]]);
        corridors.push([city, hubs[(i + 1) % hubs.length], hubs[i]]);
      }
    }
  }

  // Retire the previous seed for these cities, but never a ride somebody is
  // actually holding a seat on - cancelling that would strand a real booking.
  const retired = await db.query(
    `UPDATE rides r SET status='cancelled'
      WHERE r.status='open' AND r.depart_at > now() AND r.recurring_days='{1,2,3,4,5}'
        AND r.city = ANY($1::text[])
        AND NOT EXISTS (
          SELECT 1 FROM bookings b
           WHERE b.ride_id = r.id
             AND b.status IN ('requested','countered','confirmed')
        )`,
    [cities]
  );

  const rows = [];
  let di = 0;
  for (let ci = 0; ci < corridors.length; ci++) {
    const [city, from, to] = corridors[ci];
    // Prefer a driver based in the city; fall back to the whole pool so a city
    // with no local drivers yet still gets rides.
    const pool = allDrivers.filter((d) => d.city === city);
    const drivers = pool.length ? pool : allDrivers;
    const km = distanceKm(from, to);

    for (const d of DAYS) {
      for (const hr of HOURS) {
        const driver = drivers[di++ % drivers.length];
        const vt = TYPES[(ci + d) % TYPES.length];
        const dateStr = new Date(Date.now() + d * 86400000).toISOString().slice(0, 10);
        rows.push([
          driver.id, from.label, from.lng, from.lat, to.label, to.lng, to.lat,
          `${dateStr}T${hr}:00:00+05:00`, seatsFor(vt, ci), fareFor(km, vt),
          vt, ci % 6 === 0 && driver.gender === "female", city
        ]);
      }
    }
  }

  // Insert in batches of 50 rows (50 * 13 = 650 params, well under the limit).
  const COLS = 13;
  for (let start = 0; start < rows.length; start += 50) {
    const batch = rows.slice(start, start + 50);
    const values = [];
    const params = [];
    batch.forEach((r, i) => {
      const b = i * COLS;
      values.push(
        `($${b + 1},$${b + 2},ST_SetSRID(ST_MakePoint($${b + 3},$${b + 4}),4326)::geography,` +
        `$${b + 5},ST_SetSRID(ST_MakePoint($${b + 6},$${b + 7}),4326)::geography,` +
        `$${b + 8},'{1,2,3,4,5}',$${b + 9},$${b + 9},$${b + 10},'office',$${b + 11},$${b + 12},$${b + 13})`
      );
      params.push(...r);
    });
    await db.query(
      `INSERT INTO rides (driver_id,origin_label,origin_geo,dest_label,dest_geo,depart_at,
                          recurring_days,seats_total,seats_available,price_per_seat,vertical,
                          vehicle_type,ladies_only,city) VALUES ${values.join(",")}`,
      params
    );
  }

  const summary = (await db.query(
    `SELECT city, COUNT(*)::int rides, COUNT(DISTINCT origin_label || '->' || dest_label)::int routes,
            MIN(price_per_seat)::int min_fare, MAX(price_per_seat)::int max_fare
       FROM rides WHERE status='open' AND depart_at > now()
      GROUP BY city ORDER BY city`
  )).rows;
  console.log(
    `SEEDED ${rows.length} rides across ${corridors.length} corridors ` +
    `in ${cities.join(", ")} (retired ${retired.rowCount} previous)`
  );
  console.table(summary);
} finally {
  await db.end();
}
