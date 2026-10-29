-- Phase 3-5-3 (MySQL 8): physical FACT store metric semantics correction.
-- Controlled DDL ONLY. No synthetic validity dates or actual DIM/FACT rows.
-- Prerequisite 001 (P0) + 004 (nonnegative rates). Run once in maintenance window.
-- Existing 49-table schema continues unchanged except FACT_AREA_STORE measure names.
USE franchise_dw_p0;
DELIMITER //
CREATE PROCEDURE p35_apply_fact_store_names()
BEGIN
  DECLARE n BIGINT DEFAULT 0;
  DECLARE old_cols INT DEFAULT 0;
  DECLARE new_cols INT DEFAULT 0;
  DECLARE rate_checks INT DEFAULT 0;
  -- Refuse destructive reinterpretation of any existing FACT records.
  SELECT COUNT(*) INTO n FROM FACT_AREA_STORE;
  IF n <> 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '006 refused: FACT_AREA_STORE is not empty';
  END IF;
  -- Refuse replay and unexpected schema; migrations are deliberately one-time.
  SELECT COUNT(*) INTO old_cols FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='FACT_AREA_STORE'
     AND COLUMN_NAME IN ('store_count','similar_industry_store_count');
  SELECT COUNT(*) INTO new_cols FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='FACT_AREA_STORE'
     AND COLUMN_NAME IN ('ordinary_store_count','total_store_count');
  IF old_cols<>2 OR new_cols<>0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '006 refused: unexpected FACT_AREA_STORE schema or already applied';
  END IF;
  -- The audited rate values can exceed 100. Ensure 004 removed that cap.
  SELECT COUNT(*) INTO rate_checks FROM information_schema.CHECK_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA=DATABASE()
      AND CONSTRAINT_NAME IN ('ck_fast_open','ck_fast_close')
      AND LOWER(CHECK_CLAUSE) LIKE '%>= 0%'
      AND LOWER(CHECK_CLAUSE) NOT LIKE '%between 0 and 100%';
  IF rate_checks <> 2 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '006 refused: nonnegative-only rate checks (004) not found';
  END IF;
  ALTER TABLE FACT_AREA_STORE
    RENAME COLUMN store_count TO ordinary_store_count,
    RENAME COLUMN similar_industry_store_count TO total_store_count,
    MODIFY COLUMN total_store_count BIGINT UNSIGNED NOT NULL,
    MODIFY COLUMN franchise_store_count BIGINT UNSIGNED NOT NULL,
    ADD CONSTRAINT ck_fast_total_decomposition
      CHECK (total_store_count = ordinary_store_count + franchise_store_count);
END//
DELIMITER ;
CALL p35_apply_fact_store_names();
DROP PROCEDURE p35_apply_fact_store_names;
