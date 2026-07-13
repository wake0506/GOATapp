# Water Tracking

Water is stored locally as individual `WaterIntakeRecord` values with a stable
ID, date, recorded time, amount, and legacy-aggregate flag. Daily totals are
derived by summing the records for that date.

Older snapshots that only contain `water[date]` are migrated to one record with
ID `legacy_water_<date>`. The migration keeps the amount but uses the date at
00:00 because the old aggregate did not contain a real time.

The existing `daily_tracking.water_ml` column remains a compatibility summary
for cloud sync. The current schema has no per-intake water table, so individual
water records remain local-first and their pending delete IDs are retained
locally until a dedicated remote table is available.
