-- Migration 0002: admin flag on users; verifications can target a vehicle.
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin boolean NOT NULL DEFAULT false;
ALTER TABLE verifications ADD COLUMN IF NOT EXISTS vehicle_id uuid REFERENCES vehicles(id);
