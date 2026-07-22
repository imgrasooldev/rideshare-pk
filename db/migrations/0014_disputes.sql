-- Migration 0014: disputes / complaints. A rider or driver reports a problem
-- with a booking; it lands in an admin queue for resolution.
CREATE TABLE IF NOT EXISTS disputes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id  uuid REFERENCES bookings(id) ON DELETE SET NULL,
  user_id     uuid NOT NULL REFERENCES users(id),
  category    text NOT NULL,
  message     text NOT NULL CHECK (length(btrim(message)) BETWEEN 1 AND 2000),
  status      text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'resolved', 'dismissed')),
  resolution  text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);
CREATE INDEX IF NOT EXISTS disputes_user_idx ON disputes (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS disputes_status_idx ON disputes (status, created_at DESC);
