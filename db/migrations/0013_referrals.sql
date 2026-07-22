-- Migration 0013: referrals. Each user gets a stable shareable code; a new
-- user can credit exactly one referrer. Rewards accrue as a count today
-- (redeemable once a rider wallet exists).
ALTER TABLE users ADD COLUMN IF NOT EXISTS referral_code text UNIQUE;

CREATE TABLE IF NOT EXISTS referrals (
  referrer_id  uuid NOT NULL REFERENCES users(id),
  referred_id  uuid NOT NULL REFERENCES users(id),
  created_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (referred_id)          -- a user can be referred only once
);
CREATE INDEX IF NOT EXISTS referrals_referrer_idx ON referrals (referrer_id);
