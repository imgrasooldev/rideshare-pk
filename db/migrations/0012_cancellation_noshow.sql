-- Migration 0012: cancellation reasons + no-show. A no-show is the driver's
-- record that a confirmed rider didn't turn up; it frees the seat like a
-- cancel but is tracked separately for both parties' reliability.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS cancel_reason text;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE bookings ADD CONSTRAINT bookings_status_check CHECK (status IN
  ('requested', 'countered', 'confirmed', 'rejected', 'cancelled', 'completed', 'no_show'));
