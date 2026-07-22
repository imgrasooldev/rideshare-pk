-- Migration 0009: dispatch loop. A booking starts as a request the driver must
-- act on (accept / reject / counter-offer). Seats are only ever held by a
-- CONFIRMED booking, so requests never block a ride from filling.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS offered_price integer;   -- driver's counter, PKR/seat
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS responded_at timestamptz;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE bookings ADD CONSTRAINT bookings_status_check CHECK (status IN
  ('requested', 'countered', 'confirmed', 'rejected', 'cancelled', 'completed'));

-- Driver's request inbox: open requests across their rides.
CREATE INDEX IF NOT EXISTS bookings_status_ride_idx ON bookings (ride_id, status);
