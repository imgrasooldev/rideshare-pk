-- Migration 0008: commission settlements (driver wallet).
-- The platform's fee on cash trips accrues off the confirmed bookings; a
-- settlement records the driver paying that accrued commission back to the
-- marketplace (cash deposit now, an automatic gateway deduction later).
CREATE TABLE IF NOT EXISTS settlements (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id   uuid NOT NULL REFERENCES users(id),
  amount      integer NOT NULL CHECK (amount > 0),          -- PKR
  method      text NOT NULL DEFAULT 'cash_deposit'
                CHECK (method IN ('cash_deposit', 'wallet', 'adjustment')),
  reference   text,                                          -- deposit slip / txn id
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS settlements_driver_idx ON settlements (driver_id, created_at DESC);
