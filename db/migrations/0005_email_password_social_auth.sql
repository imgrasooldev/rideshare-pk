-- Migration 0005: email/password + social auth alongside phone OTP.
-- Phone becomes optional (email-only accounts exist); still unique when set.
ALTER TABLE users ALTER COLUMN phone DROP NOT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified boolean NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash text;
CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique ON users (lower(email)) WHERE email IS NOT NULL;

-- Social identities (google/facebook), linkable to one user each.
CREATE TABLE IF NOT EXISTS user_identities (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id),
  provider     text NOT NULL CHECK (provider IN ('google','facebook')),
  provider_uid text NOT NULL,
  email        text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, provider_uid)
);
CREATE INDEX IF NOT EXISTS user_identities_user ON user_identities (user_id);
