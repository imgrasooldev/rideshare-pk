-- Migration 0015: trip start PIN.
-- When a booking is confirmed the rider gets a 4-digit PIN. At pickup the
-- driver asks for it and enters it, which proves they have the right
-- passenger (and the passenger the right car). The PIN is only ever readable
-- by the rider — never returned on any driver-facing endpoint.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS start_pin text;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS picked_up_at timestamptz;
-- Wrong-PIN attempts, so a PIN cannot be brute-forced (only 10k combinations).
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS pin_attempts integer NOT NULL DEFAULT 0;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_start_pin_format;
ALTER TABLE bookings ADD CONSTRAINT bookings_start_pin_format
  CHECK (start_pin IS NULL OR start_pin ~ '^[0-9]{4}$');

-- Backfill PINs for already-confirmed bookings so the feature works for
-- rides that were booked before this shipped.
UPDATE bookings
   SET start_pin = lpad((floor(random() * 10000))::int::text, 4, '0')
 WHERE status = 'confirmed' AND start_pin IS NULL;
