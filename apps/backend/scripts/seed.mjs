// Seeds demo Lahore corridor rides. Idempotent: seed users are keyed by fixed
// phones; their old open rides are replaced on re-run.
//   DATABASE_URL=... node scripts/seed.mjs
import pg from "pg";

const HUBS = {
  gulberg:    { label: "Gulberg (Liberty Market)",   lat: 31.5102, lng: 74.3441 },
  dha5:       { label: "DHA Phase 5",                lat: 31.4622, lng: 74.4082 },
  joharTown:  { label: "Johar Town (Emporium)",      lat: 31.4676, lng: 74.2664 },
  modelTown:  { label: "Model Town Link Rd",         lat: 31.4811, lng: 74.3242 },
  airport:    { label: "Allama Iqbal Intl Airport",  lat: 31.5216, lng: 74.4036 },
  bahria:     { label: "Bahria Town Lahore",         lat: 31.3670, lng: 74.1845 },
  shahdara:   { label: "Shahdara Chowk",             lat: 31.5925, lng: 74.3095 },
  kalmaChowk: { label: "Kalma Chowk (Ferozepur Rd)", lat: 31.5040, lng: 74.3320 }
};

// Morning office corridors (suburb → business hub) + evening returns.
const CORRIDORS = [
  ["dha5", "gulberg"], ["joharTown", "gulberg"], ["modelTown", "gulberg"],
  ["bahria", "kalmaChowk"], ["shahdara", "gulberg"], ["dha5", "joharTown"],
  ["gulberg", "dha5"], ["gulberg", "joharTown"]
];

const url = process.env.DATABASE_URL;
if (!url) {
  console.error("DATABASE_URL required");
  process.exit(1);
}
const db = new pg.Client({ connectionString: url });
await db.connect();

try {
  const drivers = [];
  for (let i = 0; i < 8; i++) {
    const phone = `+92340000000${i}`;
    const { rows } = await db.query(
      `INSERT INTO users (phone, name, role, gender, verified, city)
       VALUES ($1, $2, 'driver', $3, true, 'lahore')
       ON CONFLICT (phone) DO UPDATE SET verified = true, role = 'driver'
       RETURNING id`,
      [phone, `Seed Driver ${i + 1}`, i % 3 === 0 ? "female" : "male"]
    );
    drivers.push(rows[0].id);
  }

  await db.query(
    `UPDATE rides SET status = 'cancelled' WHERE driver_id = ANY($1) AND status = 'open'`,
    [drivers]
  );

  // Two departures per corridor tomorrow: 08:00 and 09:00 PKT (UTC+5).
  const tomorrow = new Date(Date.now() + 24 * 3600 * 1000).toISOString().slice(0, 10);
  let count = 0;
  for (let c = 0; c < CORRIDORS.length; c++) {
    const [fromKey, toKey] = CORRIDORS[c];
    const from = HUBS[fromKey];
    const to = HUBS[toKey];
    const driverId = drivers[c % drivers.length];
    const ladiesOnly = c % 4 === 0; // seed drivers 0,4 are female by construction
    for (const hour of ["08", "09"]) {
      // jitter pickup point ±~500m so rides aren't stacked on one coordinate
      const jLat = from.lat + (((c * 7 + Number(hour)) % 10) - 5) * 0.001;
      const jLng = from.lng + (((c * 13 + Number(hour)) % 10) - 5) * 0.001;
      await db.query(
        `INSERT INTO rides (driver_id, origin_label, origin_geo, dest_label, dest_geo,
                            depart_at, recurring_days, seats_total, seats_available,
                            price_per_seat, vertical, ladies_only, city)
         VALUES ($1, $2, ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography,
                 $5, ST_SetSRID(ST_MakePoint($6, $7), 4326)::geography,
                 $8, '{1,2,3,4,5}', $9, $9, $10, 'office', $11, 'lahore')`,
        [
          driverId, from.label, jLng, jLat, to.label, to.lng, to.lat,
          `${tomorrow}T${hour}:00:00+05:00`,
          3 + (c % 2), 150 + (c % 5) * 50, ladiesOnly
        ]
      );
      count++;
    }
  }
  console.log(`SEEDED: ${drivers.length} drivers, ${count} open rides across ${CORRIDORS.length} Lahore corridors`);
} finally {
  await db.end();
}
