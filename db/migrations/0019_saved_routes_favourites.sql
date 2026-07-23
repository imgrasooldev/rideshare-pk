-- Migration 0019: saved routes + favourite drivers. Two rider conveniences —
-- one-tap re-search of a frequent trip, and a shortlist of trusted drivers
-- that can bias search results.
CREATE TABLE IF NOT EXISTS saved_routes (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label        text,
  origin_label text NOT NULL,
  origin_lat   double precision,
  origin_lng   double precision,
  dest_label   text NOT NULL,
  dest_lat     double precision,
  dest_lng     double precision,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS saved_routes_user_idx ON saved_routes (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS favourite_drivers (
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  driver_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, driver_id)
);
CREATE INDEX IF NOT EXISTS favourite_drivers_user_idx ON favourite_drivers (user_id, created_at DESC);
