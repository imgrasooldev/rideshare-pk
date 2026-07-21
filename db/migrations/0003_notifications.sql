-- In-app notification center. Every meaningful event (a booking on your ride,
-- a verification decision, a cancelled seat) writes a row here; the app shows a
-- bell with an unread count. FCM push later just delivers the same events.

CREATE TABLE IF NOT EXISTS notifications (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id),
  type       text NOT NULL,                 -- booking | verification | ride | safety | system
  title      text NOT NULL,
  body       text NOT NULL,
  data       jsonb NOT NULL DEFAULT '{}',    -- deep-link payload (rideId, bookingId, …)
  read_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Newest-first per user, and a fast unread count.
CREATE INDEX IF NOT EXISTS notifications_user_created_idx
  ON notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS notifications_user_unread_idx
  ON notifications (user_id) WHERE read_at IS NULL;
