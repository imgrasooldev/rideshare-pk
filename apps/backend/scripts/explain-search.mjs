// Proves the geo search is index-backed (build rule 3). Inside a rolled-back
// transaction: inserts 5000 synthetic rides, ANALYZEs, EXPLAIN ANALYZEs the
// exact search query, and asserts the GiST index is used. No data persists.
//   DATABASE_URL=... node scripts/explain-search.mjs
import pg from "pg";

const url = process.env.DATABASE_URL;
if (!url) {
  console.error("DATABASE_URL required");
  process.exit(1);
}
const db = new pg.Client({ connectionString: url });
await db.connect();

try {
  await db.query("BEGIN");

  const { rows: seedUser } = await db.query(
    `INSERT INTO users (phone, role, verified, city)
     VALUES ('+923499999999', 'driver', true, 'lahore-bench')
     ON CONFLICT (phone) DO UPDATE SET city = 'lahore-bench' RETURNING id`
  );

  // 5000 rides scattered over the Lahore bounding box, departing tomorrow.
  await db.query(
    `INSERT INTO rides (driver_id, origin_label, origin_geo, dest_label, dest_geo,
                        depart_at, seats_total, seats_available, price_per_seat, city)
     SELECT $1, 'bench-origin',
            ST_SetSRID(ST_MakePoint(74.18 + random() * 0.30, 31.36 + random() * 0.25), 4326)::geography,
            'bench-dest',
            ST_SetSRID(ST_MakePoint(74.18 + random() * 0.30, 31.36 + random() * 0.25), 4326)::geography,
            now() + interval '1 day' + (random() * interval '4 hours'),
            4, 4, 200, 'lahore-bench'
     FROM generate_series(1, 5000)`,
    [seedUser[0].id]
  );
  await db.query("ANALYZE rides");

  const { rows: plan } = await db.query(
    `EXPLAIN (ANALYZE, BUFFERS)
     SELECT id FROM rides
     WHERE status = 'open' AND seats_available > 0
       AND depart_at BETWEEN now() + interval '20 hours' AND now() + interval '30 hours'
       AND ST_DWithin(origin_geo, ST_SetSRID(ST_MakePoint(74.3441, 31.5102), 4326)::geography, 3000)
       AND ST_DWithin(dest_geo,   ST_SetSRID(ST_MakePoint(74.4082, 31.4622), 4326)::geography, 3000)
     ORDER BY depart_at, id LIMIT 20`
  );
  const text = plan.map((r) => r["QUERY PLAN"]).join("\n");
  console.log(text);

  await db.query("ROLLBACK");

  if (!/rides_(origin|dest)_geo_gist/.test(text)) {
    console.error("\nFAIL: plan does not use the GiST geo indexes");
    process.exitCode = 1;
  } else {
    const ms = /Execution Time: ([\d.]+) ms/.exec(text)?.[1];
    console.log(`\nOK: GiST geo index used. Execution time: ${ms} ms over 5000 synthetic rides.`);
  }
} catch (err) {
  await db.query("ROLLBACK").catch(() => {});
  throw err;
} finally {
  await db.end();
}
