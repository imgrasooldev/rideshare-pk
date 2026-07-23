// Populates rides.route_line for rides posted before along-the-route matching
// existed. Routes are cached per unique origin->destination pair, so repeated
// corridors cost one routing call instead of one per ride.
//   DATABASE_URL=... node scripts/backfill-routes.mjs [--limit N]
import pg from "pg";

const limitArg = process.argv.indexOf("--limit");
const LIMIT = limitArg > -1 ? Number(process.argv[limitArg + 1]) : 2000;
const PAUSE_MS = 400; // be polite to the public OSRM server

const db = new pg.Client({ connectionString: process.env.DATABASE_URL });
await db.connect();

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const key = (a, b, c, d) =>
  [a, b, c, d].map((n) => Number(n).toFixed(4)).join(",");

async function fetchRoute(fromLat, fromLng, toLat, toLng) {
  const url =
    `https://router.project-osrm.org/route/v1/driving/` +
    `${fromLng},${fromLat};${toLng},${toLat}?overview=full&geometries=geojson`;
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "RidesharePK/1.0 (support@rideshare.pk)" },
      signal: AbortSignal.timeout(15000)
    });
    if (res.ok) {
      const data = await res.json();
      const coords = data.routes?.[0]?.geometry?.coordinates;
      if (coords?.length >= 2) return { coordinates: coords, source: "osrm" };
    }
  } catch {
    /* fall through */
  }
  // Straight line still yields a usable corridor; better than no route at all.
  return { coordinates: [[fromLng, fromLat], [toLng, toLat]], source: "straight" };
}

try {
  const { rows } = await db.query(
    `SELECT id,
            ST_Y(origin_geo::geometry) AS "oLat", ST_X(origin_geo::geometry) AS "oLng",
            ST_Y(dest_geo::geometry)   AS "dLat", ST_X(dest_geo::geometry)   AS "dLng"
     FROM rides
     WHERE route_line IS NULL AND status IN ('open', 'full')
     ORDER BY created_at DESC
     LIMIT $1`,
    [LIMIT]
  );
  console.log(`rides needing a route: ${rows.length}`);

  const cache = new Map();
  let updated = 0;
  let osrmCalls = 0;
  let straight = 0;

  for (const r of rows) {
    const k = key(r.oLat, r.oLng, r.dLat, r.dLng);
    let route = cache.get(k);
    if (!route) {
      route = await fetchRoute(r.oLat, r.oLng, r.dLat, r.dLng);
      cache.set(k, route);
      osrmCalls++;
      if (route.source === "straight") straight++;
      await sleep(PAUSE_MS);
    }

    await db.query(
      `UPDATE rides
         SET route_line = ST_SetSRID(ST_GeomFromGeoJSON($2::jsonb), 4326)::geography,
             updated_at = now()
       WHERE id = $1`,
      [r.id, JSON.stringify({ type: "LineString", coordinates: route.coordinates })]
    );
    updated++;
    if (updated % 50 === 0) console.log(`  ${updated}/${rows.length} …`);
  }

  console.log(
    `\nBACKFILL DONE: ${updated} rides updated using ${osrmCalls} routing calls ` +
      `(${cache.size} unique corridors, ${straight} straight-line fallbacks)`
  );
} finally {
  await db.end();
}
