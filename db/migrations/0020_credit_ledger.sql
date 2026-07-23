-- Migration 0020: rider credit ledger — a gateway-agnostic wallet foundation.
-- Every balance change is an immutable append-only entry (signed paisa); the
-- balance is SUM(amount_paisa). No payment gateway is wired yet: real money
-- top-ups are stubbed. Working credit sources today are referral rewards and
-- admin adjustments; debits (paying a fare from credit) come with digital pay.
CREATE TABLE IF NOT EXISTS credit_ledger (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount_paisa bigint NOT NULL,               -- signed: +credit, -debit
  kind         text NOT NULL,                 -- topup | referral_credit | promo_credit | refund | ride_debit | adjustment
  reference    text,                          -- natural key of the source event (dedupe)
  description  text,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS credit_ledger_user_idx ON credit_ledger (user_id, created_at DESC);

-- One credit per source event. NULLs are distinct, so unreferenced entries
-- (adjustments, stubbed top-ups) are never blocked; a referral can only pay once.
CREATE UNIQUE INDEX IF NOT EXISTS credit_ledger_ref_uidx
  ON credit_ledger (user_id, kind, reference);
