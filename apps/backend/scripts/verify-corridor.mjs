// Proves the along-the-route SQL against real PostGIS, inside a rolled-back
// transaction: a rider joining mid-route matches, the reverse direction does
// not, and the corridor predicate uses the GiST index.
//   DATABASE_URL=... node scripts/verify-corridor.mjs
import pg from "pg";

const db = new pg.Client({ connectionString: process.env.DATABASE_URL });
await db.connect();

const ROUTE = {
  type: "LineString",
  coordinates: [
    [74.3441, 31.5102], // Gulberg (origin)
    [74.31, 31.49],
    [74.2664, 31.4676], // Johar Town (mid-route)
    [74.34, 31.465],
    [74.4082, 31.4622] // DHA Phase 5 (destination)
  ]
};

const corridorSql = (pickup, drop) => `
  SELECT
    ST_DWithin(route_line, ST_SetSRID(ST_MakePoint(${pickup[0]}, ${pickup[1]}), 4326)::geography, 3000)
      AS pickup_near,
    ST_DWithin(route_line, ST_SetSRID(ST_MakePoint(${drop[0]}, ${drop[1]}), 4326)::geography, 3000)
      AS drop_near,
    ST_LineLocatePoint(route_line::geometry, ST_SetSRID(ST_MakePoint(${pickup[0]}, ${pickup[1]}), 4326))
      < ST_LineLocatePoint(route_line::geometry, ST_SetSRID(ST_MakePoint(${drop[0]}, ${drop[1]}), 4326))
      AS right_direction
  FROM rides WHERE id = $1`;

let failures = 0;
const check = (label, actual, expected) => {
  const ok = actual === expected;
  if (!ok) failures++;
  console.log(`${ok ? "PASS" : "FAIL"}: ${label} (got ${actual}, expected ${expected})`);
};

try {
  await db.query("BEGIN");

  const { rows: u } = await db.query(
    `INSERT INTO users (phone, role, verified, city)
     VALUES ('+923488888888', 'driver', true, 'corridor-test')
     ON CONFLICT (phone) DO UPDATE SET city = 'corridor-test' RETURNING id`
  );

  const { rows: r } = await db.query(
    `INSERT INTO rides (driver_id, origin_label, origin_geo, dest_label, dest_geo,
                        depart_at, seats_total, seats_available, price_per_seat, city, route_line)
     VALUES ($1, 'Gulberg', ST_SetSRID(ST_MakePoint(74.3441, 31.5102), 4326)::geography,
             'DHA Phase 5', ST_SetSRID(ST_MakePoint(74.4082, 31.4622), 4326)::geography,
             now() + interval '1 day', 3, 3, 250, 'corridor-test',
             ST_SetSRID(ST_GeomFromGeoJSON($2::jsonb), 4326)::geography)
     RETURNING id`,
    [u[0].id, JSON.stringify(ROUTE)]
  );
  const rideId = r[0].id;

  // Johar Town -> DHA: on the corridor, correct direction.
  const forward = (
    await db.query(corridorSql([74.2664, 31.4676], [74.4082, 31.4622]), [rideId])
  ).rows[0];
  check("mid-route pickup is near the corridor", forward.pickup_near, true);
  check("drop is near the corridor", forward.drop_near, true);
  check("direction is forward", forward.right_direction, true);

  // DHA -> Johar Town: same corridor, wrong way.
  const reverse = (
    await db.query(corridorSql([74.4082, 31.4622], [74.2664, 31.4676]), [rideId])
  ).rows[0];
  check("reverse trip rejected by direction guard", reverse.right_direction, false);

  // Bahria Town: far off the corridor.
  const off = (await db.query(corridorSql([74.1845, 31.367], [74.4082, 31.4622]), [rideId])).rows[0];
  check("off-corridor pickup not matched", off.pickup_near, false);

  // The corridor predicate must be index-backed, not a sequential scan.
  await db.query("ANALYZE rides");
  const { rows: plan } = await db.query(
    `EXPLAIN SELECT id FROM rides
     WHERE route_line IS NOT NULL
       AND ST_DWithin(route_line, ST_SetSRID(ST_MakePoint(74.2664, 31.4676), 4326)::geography, 3000)`
  );
  const text = plan.map((p) => p["QUERY PLAN"]).join("\n");
  check("corridor search uses rides_route_line_gist", /route_line_gist/.test(text), true);
  if (!/route_line_gist/.test(text)) console.log(text);

  await db.query("ROLLBACK");
} catch (err) {
  await db.query("ROLLBACK").catch(() => {});
  throw err;
} finally {
  await db.end();
}

console.log(failures === 0 ? "\nCORRIDOR SQL OK" : `\n${failures} CHECK(S) FAILED`);
process.exitCode = failures === 0 ? 0 : 1;
