-- Migration 0016: user safety controls.
-- Disputes covered "something went wrong with this booking". They could not
-- express "this PERSON is a problem", there was no way for a user to avoid
-- someone, and no way for an admin to stop an abusive account.

-- 1. Personal blocklist. Blocking is one-directional intent but enforced
--    symmetrically: once either side blocks, neither is shown to the other.
CREATE TABLE IF NOT EXISTS user_blocks (
  blocker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason     text,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CONSTRAINT user_blocks_not_self CHECK (blocker_id <> blocked_id)
);
-- Reverse lookup: "who blocked me" is needed on every ride search.
CREATE INDEX IF NOT EXISTS user_blocks_blocked_idx ON user_blocks (blocked_id);

-- 2. A dispute can now name the person being reported, so the admin queue
--    shows WHO is complained about, not just who complained.
ALTER TABLE disputes ADD COLUMN IF NOT EXISTS reported_user_id uuid REFERENCES users(id);
CREATE INDEX IF NOT EXISTS disputes_reported_idx
  ON disputes (reported_user_id, created_at DESC) WHERE reported_user_id IS NOT NULL;

-- 3. Admin suspension: an account that can no longer sign in or act.
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_at timestamptz;
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspension_reason text;
CREATE INDEX IF NOT EXISTS users_suspended_idx ON users (suspended_at)
  WHERE suspended_at IS NOT NULL;
