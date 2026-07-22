-- Migration 0010: FCM device tokens for push notifications. One row per
-- device token; a token belongs to whichever user last registered it.
CREATE TABLE IF NOT EXISTS device_tokens (
  token       text PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform    text NOT NULL DEFAULT 'android' CHECK (platform IN ('android', 'ios', 'web')),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS device_tokens_user_idx ON device_tokens (user_id);
