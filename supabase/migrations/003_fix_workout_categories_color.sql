-- =============================================================================
-- 003 — widen workout_categories.color to bigint
-- -----------------------------------------------------------------------------
-- The mobile app stores category colors as ARGB decimals (e.g. 4294937088 =
-- 0xFF00...), which exceed the signed 32-bit integer range (max 2147483647).
-- Migration 002 (master seed) therefore failed with ERROR 22003
-- "integer out of range". This widens the column so the seed can load.
--
-- Safe: column currently has no rows (002 never inserted workout_categories),
-- no dependent indexes/views reference it.
-- =============================================================================

alter table public.workout_categories
    alter column color type bigint;
