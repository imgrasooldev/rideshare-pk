-- Karachi had 8 hubs, which left most of the city unreachable: no business
-- district (II Chundrigar Road), no industrial belt (SITE, Port Qasim), and
-- nothing in the northern or eastern residential sprawl where most commuters
-- actually live. Riders searching those areas got no results.
--
-- Coordinates are the commonly-used centre of each area, since they seed the
-- geo-corridor matching and ETA estimates.

INSERT INTO hubs (city, label, lat, lng, sort) VALUES
  -- Commercial / employment centres
  ('karachi', 'II Chundrigar Road',      24.8496, 67.0028,  9),
  ('karachi', 'Tariq Road',              24.8722, 67.0631, 10),
  ('karachi', 'Bahadurabad',             24.8788, 67.0678, 11),
  ('karachi', 'SITE Industrial Area',    24.8770, 66.9930, 12),
  ('karachi', 'Port Qasim',              24.7850, 67.3400, 13),
  -- Residential catchments
  ('karachi', 'Gulistan-e-Johar',        24.9265, 67.1300, 14),
  ('karachi', 'Federal B Area',          24.9350, 67.0650, 15),
  ('karachi', 'Malir Cantt',             24.8930, 67.1907, 16),
  ('karachi', 'Landhi',                  24.8470, 67.1900, 17),
  ('karachi', 'Surjani Town',            25.0130, 67.0680, 18),
  ('karachi', 'Bahria Town Karachi',     25.0080, 67.3160, 19),
  ('karachi', 'Karachi University',      24.9400, 67.1200, 20),
  -- The city's main artery; most cross-town commutes run along it.
  ('karachi', 'Shahrah-e-Faisal',        24.8640, 67.0720, 21)
ON CONFLICT (city, label) DO NOTHING;
