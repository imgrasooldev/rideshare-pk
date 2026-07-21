-- Subscription routes: instead of booking a daily commute every morning, a
-- rider subscribes to a recurring ride for a month. Predictable income for the
-- driver, predictable spend for the rider, and a monthly commission for the
-- marketplace. Payment capture wires in when a gateway is configured; until
-- then the subscription is a cash commitment.

CREATE TABLE IF NOT EXISTS subscriptions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id        uuid NOT NULL REFERENCES users(id),
  ride_id         uuid NOT NULL REFERENCES rides(id),
  seats           int NOT NULL DEFAULT 1 CHECK (seats >= 1),
  days            int[] NOT NULL DEFAULT '{1,2,3,4,5}',
  price_per_month int NOT NULL,
  status          text NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'cancelled', 'expired')),
  starts_on       date NOT NULL DEFAULT current_date,
  renews_on       date NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS subscriptions_rider_idx ON subscriptions (rider_id, created_at DESC);
-- One active subscription per rider per ride.
CREATE UNIQUE INDEX IF NOT EXISTS subscriptions_active_uk
  ON subscriptions (rider_id, ride_id) WHERE status = 'active';
