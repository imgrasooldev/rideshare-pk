// Applies a SQL file to DATABASE_URL. Usage: node scripts/db-apply.mjs <file.sql>
// Works through the Supabase transaction pooler (simple-protocol multi-statement).
import { readFileSync } from "node:fs";
import pg from "pg";

const url = process.env.DATABASE_URL;
const file = process.argv[2];
if (!url || !file) {
  console.error("Usage: DATABASE_URL=... node scripts/db-apply.mjs <file.sql>");
  process.exit(1);
}

const client = new pg.Client({ connectionString: url });
await client.connect();
try {
  const sql = readFileSync(file, "utf8");
  await client.query(sql);
  console.log(`APPLIED: ${file}`);
} finally {
  await client.end();
}
