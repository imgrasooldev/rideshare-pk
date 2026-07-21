-- Migration 0006: in-app chat. A message belongs to a ride and is a directed
-- note between two users; a "thread" is the pair (ride_id, {sender, recipient})
-- regardless of direction.
CREATE TABLE IF NOT EXISTS messages (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id      uuid NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  sender_id    uuid NOT NULL REFERENCES users(id),
  recipient_id uuid NOT NULL REFERENCES users(id),
  body         text NOT NULL CHECK (length(btrim(body)) BETWEEN 1 AND 2000),
  read_at      timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- Thread reads: all messages for a ride between two users, in time order.
CREATE INDEX IF NOT EXISTS messages_thread_idx
  ON messages (ride_id, sender_id, recipient_id, created_at);
-- Fast unread lookups for a recipient.
CREATE INDEX IF NOT EXISTS messages_recipient_unread_idx
  ON messages (recipient_id) WHERE read_at IS NULL;
-- Inbox: a user's most recent conversations.
CREATE INDEX IF NOT EXISTS messages_participants_idx
  ON messages (sender_id, recipient_id, created_at DESC);
