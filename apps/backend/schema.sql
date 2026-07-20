-- Rideshare-PK — initial schema (Phase 1, architected for 2–4).
-- Postgres 16 + PostGIS. Applied by db/migrations/0001_init.sql; this file is
-- the canonical current-state reference.

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gen_random_uuid()

-- Phase 3 entity, defined now so users.org_id exists from day one (rule 8).
CREATE TABLE organizations (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL,
  billing_email text,
  city          text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone         text NOT NULL UNIQUE,          -- E.164, e.g. +923001234567
  name          text,
  role          text NOT NULL DEFAULT 'rider' CHECK (role IN ('driver','rider','both')),
  gender        text CHECK (gender IN ('female','male','other')), -- required for ladies-only matching
  cnic          text,                           -- encrypted at rest at the app layer
  verified      boolean NOT NULL DEFAULT false,
  is_admin      boolean NOT NULL DEFAULT false,
  rating_avg    numeric(3,2) NOT NULL DEFAULT 0,
  rating_count  integer NOT NULL DEFAULT 0,
  city          text NOT NULL DEFAULT 'lahore',
  org_id        uuid REFERENCES organizations(id),
  deleted_at    timestamptz,                    -- soft delete
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE vehicles (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id   uuid NOT NULL REFERENCES users(id),
  make       text NOT NULL,
  model      text NOT NULL,
  plate      text NOT NULL,
  seats      integer NOT NULL CHECK (seats BETWEEN 1 AND 20),
  doc_urls   text[] NOT NULL DEFAULT '{}',
  verified   boolean NOT NULL DEFAULT false,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE rides (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id       uuid NOT NULL REFERENCES users(id),
  vehicle_id      uuid REFERENCES vehicles(id),
  origin_label    text NOT NULL,
  origin_geo      geography(Point, 4326) NOT NULL,
  dest_label      text NOT NULL,
  dest_geo        geography(Point, 4326) NOT NULL,
  route_line      geography(LineString, 4326),   -- optional polyline for corridor matching
  depart_at       timestamptz NOT NULL,
  recurring_days  smallint[] NOT NULL DEFAULT '{}', -- 0=Sun..6=Sat
  seats_total     integer NOT NULL CHECK (seats_total BETWEEN 1 AND 20),
  seats_available integer NOT NULL CHECK (seats_available >= 0),
  price_per_seat  integer NOT NULL CHECK (price_per_seat >= 0), -- PKR, cost-share framing
  vertical        text NOT NULL DEFAULT 'office' CHECK (vertical IN
                    ('office','school','city','rentacar','ladies','parcel','corporate','airport','events')),
  ladies_only     boolean NOT NULL DEFAULT false,
  status          text NOT NULL DEFAULT 'open' CHECK (status IN ('open','full','cancelled','completed')),
  city            text NOT NULL DEFAULT 'lahore',
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (seats_available <= seats_total)
);

-- Rule 3: the matching query must be index-backed.
CREATE INDEX rides_origin_geo_gist ON rides USING gist (origin_geo);
CREATE INDEX rides_dest_geo_gist   ON rides USING gist (dest_geo);
CREATE INDEX rides_route_line_gist ON rides USING gist (route_line);
CREATE INDEX rides_depart_at_btree ON rides (depart_at);
CREATE INDEX rides_search_hot      ON rides (city, status, depart_at) WHERE status = 'open';

CREATE TABLE bookings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id         uuid NOT NULL REFERENCES rides(id),
  rider_id        uuid NOT NULL REFERENCES users(id),
  seats           integer NOT NULL CHECK (seats >= 1),
  status          text NOT NULL DEFAULT 'confirmed' CHECK (status IN
                    ('requested','confirmed','cancelled','completed')), -- 'requested' enables Phase 2 accept/decline
  idempotency_key text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (rider_id, idempotency_key)
);
CREATE INDEX bookings_ride_id ON bookings (ride_id);
CREATE INDEX bookings_rider_id_created ON bookings (rider_id, created_at DESC);

CREATE TABLE trips (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id     uuid NOT NULL REFERENCES rides(id),
  started_at  timestamptz,
  ended_at    timestamptz,
  live_status text NOT NULL DEFAULT 'pending' CHECK (live_status IN ('pending','live','ended')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
-- Live driver locations live in Redis geo sets; an optional persisted trail
-- table (trip_points) can be added when needed — do not write per-ping rows here.

CREATE TABLE ratings (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id      uuid NOT NULL REFERENCES rides(id),
  from_user_id uuid NOT NULL REFERENCES users(id),
  to_user_id   uuid NOT NULL REFERENCES users(id),
  stars        integer NOT NULL CHECK (stars BETWEEN 1 AND 5),
  comment      text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ride_id, from_user_id, to_user_id)
);
CREATE INDEX ratings_to_user ON ratings (to_user_id);

CREATE TABLE verifications (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id),
  type        text NOT NULL CHECK (type IN ('cnic','license','vehicle')),
  vehicle_id  uuid REFERENCES vehicles(id),  -- set when type = 'vehicle'
  doc_url     text NOT NULL,
  status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  reviewer_id uuid REFERENCES users(id),
  notes       text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX verifications_queue ON verifications (status, created_at) WHERE status = 'pending';
