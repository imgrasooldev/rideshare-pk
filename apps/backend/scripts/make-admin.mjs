// Grants admin to a user by phone. Usage:
//   DATABASE_URL=... node scripts/make-admin.mjs +923001234567
import pg from "pg";

const url = process.env.DATABASE_URL;
const phone = process.argv[2];
if (!url || !phone) {
  console.error("Usage: DATABASE_URL=... node scripts/make-admin.mjs <phone-e164>");
  process.exit(1);
}

const client = new pg.Client({ connectionString: url });
await client.connect();
try {
  const { rows } = await client.query(
    "UPDATE users SET is_admin = true, updated_at = now() WHERE phone = $1 RETURNING id, phone",
    [phone]
  );
  if (!rows[0]) {
    console.error(`No user with phone ${phone} — they must log in once first.`);
    process.exitCode = 1;
  } else {
    console.log(`ADMIN GRANTED: ${rows[0].phone} (${rows[0].id})`);
  }
} finally {
  await client.end();
}
