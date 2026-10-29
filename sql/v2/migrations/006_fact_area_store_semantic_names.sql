-- Phase 3-5 approved MODEL CONTRACT only: NO historical source/quality/fact rows written.
-- Requires empty FACT_AREA_STORE and 004 nonnegative rate migration already applied.
USE franchise_dw_p0;
DELIMITER //
CREATE PROCEDURE p35_apply_fact_store_names()
BEGIN
  DECLARE n BIGINT DEFAULT 0;
  DECLARE checks_ok INT DEFAULT 0;
  SELECT COUNT(*) INTO n FROM FACT_AREA_STORE;
  IF n <> 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FACT_AREA_STORE not empty: refuse semantic rename';
  END IF;
  SELECT COUNT(*) INTO checks_ok FROM information_schema.CHECK_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND CONSTRAINT_NAME IN ('ck_fast_open','ck_fast_close')
      AND LOWER(CHECK_CLAUSE) NOT LIKE '%between 0 and 100%';
  IF checks_ok <> 2 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Apply and verify rate migration 004 first';
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
