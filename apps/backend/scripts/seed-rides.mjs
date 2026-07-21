// Seeds a full week of upcoming rides across every city's hubs, so search and
// "live near you" (which query a single future day) always find results.
// Uses exact hub coordinates from the DB so geo-corridor matching hits.
// Batched inserts (fast + pooler-safe). Usage: DATABASE_URL=... node scripts/seed-rides.mjs
import pg from "pg";

const url = process.env.DATABASE_URL;
if (!url) { console.error("DATABASE_URL required"); process.exit(1); }
const db = new pg.Client({ connectionString: url });
await db.connect();

const TYPES = ["car", "car", "bike", "hiace", "car", "minivan", "car"];
const seatsFor = (t, i) => (t === "bike" ? 1 : t === "hiace" ? 12 : t === "minivan" ? 7 : 3 + (i % 2));
const HOURS = ["08", "18"];
const DAYS = [1, 2, 3, 4, 5];

try {
  const hubRows = (await db.query(`SELECT city, label, lat, lng FROM hubs ORDER BY city, sort`)).rows;
  const byCity = {};
  for (const h of hubRows) (byCity[h.city] ??= []).push(h);

  let drivers = (await db.query(
    `SELECT id, gender FROM users WHERE role IN ('driver','both') AND verified=true ORDER BY phone`
  )).rows;
  if (!drivers.length) {
    drivers = (await db.query(
      `INSERT INTO users (phone,name,role,gender,verified,city)
       VALUES ('+923990000000','Seed Driver X','driver','male',true,'lahore') RETURNING id, gender`
    )).rows;
  }

  // Directed adjacent corridors (both ways) per city.
  const corridors = [];
  for (const [city, hubs] of Object.entries(byCity)) {
    if (hubs.length < 2) continue;
    for (let i = 0; i < hubs.length; i++) {
      corridors.push([city, hubs[i], hubs[(i + 1) % hubs.length]]);
      corridors.push([city, hubs[(i + 1) % hubs.length], hubs[i]]);
    }
  }

  await db.query(
    `UPDATE rides SET status='cancelled'
     WHERE status='open' AND depart_at > now() AND recurring_days='{1,2,3,4,5}'`
  );

  // Build all rows first.
  const rows = [];
  let di = 0;
  for (let ci = 0; ci < corridors.length; ci++) {
    const [city, from, to] = corridors[ci];
    for (const d of DAYS) {
      for (const hr of HOURS) {
        const driver = drivers[di++ % drivers.length];
        const vt = TYPES[(ci + d) % TYPES.length];
        const dateStr = new Date(Date.now() + d * 86400000).toISOString().slice(0, 10);
        rows.push([
          driver.id, from.label, from.lng, from.lat, to.label, to.lng, to.lat,
          `${dateStr}T${hr}:00:00+05:00`, seatsFor(vt, ci), 100 + ((ci + d) % 6) * 40,
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
    `SELECT city, COUNT(*)::int n FROM rides WHERE status='open' AND depart_at > now()
     GROUP BY city ORDER BY city`
  )).rows;
  console.log(`SEEDED ${rows.length} upcoming rides across ${corridors.length} corridors`);
  console.table(summary);
} finally {
  await db.end();
}
