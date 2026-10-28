-- Phase 3-1 correction: measured Seoul opening/closure rates can exceed 100.
-- The precise official historical rate denominator could not be verified.
-- Do NOT assume these rates always equal event count / current stores * 100.
-- Historical 2022Q1-2023Q2 raw STORE CSV: opening >100 (5), closure >100 (124),
-- distinct offending rows (union): 128 / 457043. Maximum closure rate: 4800.
-- Preserve original rates, do not clamp or coerce to 0. >100 is a QA anomaly
-- for investigation, not an automatic DB rejection.
-- Requires P0 001_schema.sql; run in a controlled migration sequence.
-- MySQL 8.0.16+ with enforced CHECK constraints.
USE franchise_dw_p0;
ALTER TABLE FACT_AREA_STORE
  DROP CHECK ck_fast_open,
  DROP CHECK ck_fast_close,
  ADD CONSTRAINT ck_fast_open CHECK (opening_rate IS NULL OR opening_rate >= 0),
  ADD CONSTRAINT ck_fast_close CHECK (closure_rate IS NULL OR closure_rate >= 0);
