-- Migration 0004: marketplace vehicle types + explicit cash payment method.
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS vehicle_type text NOT NULL DEFAULT 'car';
ALTER TABLE vehicles ADD CONSTRAINT vehicles_vehicle_type_check
  CHECK (vehicle_type IN ('car','bike','hiace','minivan'));

ALTER TABLE rides ADD COLUMN IF NOT EXISTS vehicle_type text NOT NULL DEFAULT 'car';
ALTER TABLE rides ADD CONSTRAINT rides_vehicle_type_check
  CHECK (vehicle_type IN ('car','bike','hiace','minivan'));

-- Cash-only for now; the CHECK grows when digital payments (Phase 2) land.
ALTER TABLE rides ADD COLUMN IF NOT EXISTS payment_method text NOT NULL DEFAULT 'cash';
ALTER TABLE rides ADD CONSTRAINT rides_payment_method_check
  CHECK (payment_method IN ('cash'));
