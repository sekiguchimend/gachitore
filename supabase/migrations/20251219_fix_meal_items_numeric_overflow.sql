-- Fix: numeric field overflow when logging meals.
-- `meal_items` macro columns were too small (numeric(6,2) => max 9999.99).
-- Expand precision to avoid insert failures for large values / unit mismatches.

ALTER TABLE public.meal_items
  ALTER COLUMN protein_g TYPE NUMERIC(10,2),
  ALTER COLUMN fat_g     TYPE NUMERIC(10,2),
  ALTER COLUMN carbs_g   TYPE NUMERIC(10,2),
  ALTER COLUMN fiber_g   TYPE NUMERIC(10,2);

-- Keep daily aggregate fiber in sync (was numeric(6,2)).
ALTER TABLE public.nutrition_daily
  ALTER COLUMN fiber_g TYPE NUMERIC(10,2);


