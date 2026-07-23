-- Migration 0018: instant-book. When a driver opts a ride into instant-book,
-- a rider's booking is auto-confirmed (seat taken immediately) instead of
-- waiting in the request queue.
ALTER TABLE rides ADD COLUMN IF NOT EXISTS instant_book boolean NOT NULL DEFAULT false;
