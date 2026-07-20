// Prints schema health: tables, PostGIS version, rides indexes.
import pg from "pg";

const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
await client.connect();
try {
  const t = await client.query(
    "select table_name from information_schema.tables where table_schema='public' and table_type='BASE TABLE' order by 1"
  );
  console.log("tables:", t.rows.map((r) => r.table_name).join(", "));
  const p = await client.query("select postgis_version() as v");
  console.log("postgis:", p.rows[0].v);
  const i = await client.query("select indexname from pg_indexes where tablename='rides' order by 1");
  console.log("rides indexes:", i.rows.map((r) => r.indexname).join(", "));
  const u = await client.query("select count(*)::int as n from users");
  console.log("users rows:", u.rows[0].n);
} finally {
  await client.end();
}
