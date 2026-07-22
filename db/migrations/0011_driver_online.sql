-- Migration 0011: driver availability. Offline pauses a driver's rides —
-- they're hidden from search and can't be requested. Default online so
-- existing drivers keep showing.
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_online boolean NOT NULL DEFAULT true;
