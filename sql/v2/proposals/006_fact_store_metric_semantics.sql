-- Phase 3-5 schema proposal. NOT auto-applied. Requires review/approval and
-- verified G02/G03/G06/G11/G13; never modify populated FACT without migration plan.
-- Historical metric semantics from Seoul OA-15577 and 457,043-row CSV identity.
-- Use only in dedicated EMPTY test schema after reviewing existing columns.
USE franchise_dw_p0;
-- Prefer explicit names. Rename the two ambiguous FACT columns; retain data types.
-- This migration MUST NOT be applied on populated FACT tables without backup,
-- semantic backfill plan and consumer/view compatibility review.
ALTER TABLE FACT_AREA_STORE
  RENAME COLUMN store_count TO ordinary_store_count,
  RENAME COLUMN similar_industry_store_count TO total_store_count,
  ADD CONSTRAINT ck_fact_store_decomp
    CHECK (
       total_store_count IS NULL OR franchise_store_count IS NULL
       OR total_store_count = ordinary_store_count + franchise_store_count
    );
-- Target mapping only, no actual load:
-- ordinary_store_count <- SRC_SEOUL_STORE.store_count
-- total_store_count <- SRC_SEOUL_STORE.similar_industry_store_count
-- franchise_store_count <- SRC_SEOUL_STORE.franchise_store_count
-- Historical SRC and STG must NOT be rewritten or reclassified in place.
