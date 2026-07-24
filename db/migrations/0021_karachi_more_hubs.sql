-- More Karachi hubs: the northern Superhighway growth belt (Gulshan-e-Maymar,
-- Ahsanabad) and the central Garden area near Saddar. These feed the curated
-- corridors added in seed-rides.mjs (e.g. Maymar -> Saddar, Ahsanabad -> Garden).
INSERT INTO hubs (city, label, lat, lng, sort) VALUES
  ('karachi', 'Gulshan-e-Maymar',   25.0340, 67.1030, 22),
  ('karachi', 'Ahsanabad',          25.0180, 67.1230, 23),
  ('karachi', 'Garden',             24.8790, 67.0230, 24)
ON CONFLICT (city, label) DO NOTHING;
