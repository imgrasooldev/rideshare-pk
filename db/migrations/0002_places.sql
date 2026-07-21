-- Dynamic locations: cities + curated hubs, so pickup/drop lists come from the
-- DB per city instead of a hardcoded Lahore array. Backend geo-matching already
-- works on lat/lng, so this just feeds real coordinates per city.

CREATE TABLE IF NOT EXISTS cities (
  slug       text PRIMARY KEY,
  name       text NOT NULL,
  center_lat double precision NOT NULL,
  center_lng double precision NOT NULL,
  sort       int NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS hubs (
  id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city  text NOT NULL,
  label text NOT NULL,
  lat   double precision NOT NULL,
  lng   double precision NOT NULL,
  sort  int NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS hubs_city_idx ON hubs(city);
CREATE UNIQUE INDEX IF NOT EXISTS hubs_city_label_uk ON hubs(city, label);

INSERT INTO cities (slug, name, center_lat, center_lng, sort) VALUES
  ('karachi',   'Karachi',   24.8607, 67.0011, 1),
  ('lahore',    'Lahore',    31.5204, 74.3587, 2),
  ('islamabad', 'Islamabad', 33.6844, 73.0479, 3)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO hubs (city, label, lat, lng, sort) VALUES
  ('karachi', 'Saddar',                24.8600, 67.0300, 1),
  ('karachi', 'Clifton',               24.8138, 67.0300, 2),
  ('karachi', 'DHA Phase 5',           24.7900, 67.0500, 3),
  ('karachi', 'Gulshan-e-Iqbal',       24.9200, 67.0900, 4),
  ('karachi', 'Nazimabad',             24.9100, 67.0300, 5),
  ('karachi', 'North Nazimabad',       24.9500, 67.0400, 6),
  ('karachi', 'Korangi',               24.8300, 67.1300, 7),
  ('karachi', 'Jinnah Intl Airport',   24.9065, 67.1608, 8)
ON CONFLICT (city, label) DO NOTHING;

INSERT INTO hubs (city, label, lat, lng, sort) VALUES
  ('lahore', 'Gulberg (Liberty Market)',   31.5102, 74.3441, 1),
  ('lahore', 'DHA Phase 5',                31.4622, 74.4082, 2),
  ('lahore', 'Johar Town (Emporium)',      31.4676, 74.2664, 3),
  ('lahore', 'Model Town Link Rd',         31.4811, 74.3242, 4),
  ('lahore', 'Allama Iqbal Intl Airport',  31.5216, 74.4036, 5),
  ('lahore', 'Bahria Town Lahore',         31.3670, 74.1845, 6),
  ('lahore', 'Shahdara Chowk',             31.5925, 74.3095, 7),
  ('lahore', 'Kalma Chowk (Ferozepur Rd)', 31.5040, 74.3320, 8)
ON CONFLICT (city, label) DO NOTHING;

INSERT INTO hubs (city, label, lat, lng, sort) VALUES
  ('islamabad', 'Blue Area',              33.7089, 73.0551, 1),
  ('islamabad', 'F-10 Markaz',            33.6938, 72.9990, 2),
  ('islamabad', 'F-7 Markaz',             33.7180, 73.0550, 3),
  ('islamabad', 'G-11 Markaz',            33.6680, 72.9720, 4),
  ('islamabad', 'Bahria Town Phase 7',    33.5340, 73.1180, 5),
  ('islamabad', 'Islamabad Intl Airport', 33.5490, 72.8258, 6)
ON CONFLICT (city, label) DO NOTHING;
