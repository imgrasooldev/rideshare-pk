-- Migration 0003: trip share links, safety centre, emergency contact.
ALTER TABLE users ADD COLUMN IF NOT EXISTS emergency_phone text;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS share_token uuid NOT NULL DEFAULT gen_random_uuid();
CREATE UNIQUE INDEX IF NOT EXISTS trips_share_token ON trips (share_token);
CREATE UNIQUE INDEX IF NOT EXISTS trips_one_live_per_ride ON trips (ride_id) WHERE live_status = 'live';

CREATE TABLE IF NOT EXISTS safety_events (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id),
  ride_id    uuid REFERENCES rides(id),
  kind       text NOT NULL DEFAULT 'sos' CHECK (kind IN ('sos')),
  lat        double precision,
  lng        double precision,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS safety_events_user ON safety_events (user_id, created_at DESC);
