-- Execute AFTER 001_schema.sql against a disposable P0 schema.
-- All fixture inserts are wrapped in a transaction and rolled back.
-- Expected constraint failures must match MySQL error numbers (1062 duplicate, 1452 FK, 3819 CHECK, 1048 NOT NULL).
USE franchise_dw_p0;

DELIMITER $$
CREATE PROCEDURE p0_integrity_smoke()
BEGIN
  DECLARE area_type_id BIGINT UNSIGNED;
  DECLARE district_id BIGINT UNSIGNED;
  DECLARE dong_id BIGINT UNSIGNED;
  DECLARE area_id BIGINT UNSIGNED;
  DECLARE industry_id BIGINT UNSIGNED;
  DECLARE period_id BIGINT UNSIGNED;
  DECLARE caught_error INT DEFAULT 0;
  DECLARE row_count_test INT DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  -- Raw source: preserve even malformed/withheld numeric values as text.
  INSERT INTO SRC_SEOUL_AREA
    (collection_batch_id, source_document_id, source_record_path,
     reference_period_text, raw_record_text, area_code, area_name)
  VALUES ('p0-test-batch-1', 'area-demo', '/records/1',
          '2026-Q1', '{"area_code":"p0-demo"}', 'p0-demo', 'P0 Demo');

  INSERT INTO SRC_SEOUL_SALES
    (collection_batch_id, source_document_id, source_record_path,
     base_year_quarter, area_code, service_industry_code,
     estimated_sales_amount, raw_record_text)
  VALUES ('p0-test-batch-1', 'sales-demo', '/records/1',
          '2026-Q1', 'p0-demo', 'C001', 'N/A', '{"estimated_sales_amount":"N/A"}');

  INSERT INTO SRC_SEOUL_STORE
    (collection_batch_id, source_document_id, source_record_path,
     base_year_quarter, area_code, service_industry_code,
     store_count, raw_record_text)
  VALUES ('p0-test-batch-1', 'store-demo', '/records/1',
          '2026-Q1', 'p0-demo', 'C001', '12', '{"store_count":"12"}');

  -- Same physical source path may be re-ingested in a DIFFERENT batch.
  INSERT INTO SRC_SEOUL_AREA
    (collection_batch_id, source_document_id, source_record_path, raw_record_text)
  VALUES ('p0-test-batch-2', 'area-demo', '/records/1', '{"area_code":"p0-demo"}');

  SELECT COUNT(*) INTO row_count_test
    FROM SRC_SEOUL_AREA
   WHERE source_document_id = 'area-demo' AND source_record_path = '/records/1';
  IF row_count_test <> 2 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'raw re-ingestion across distinct batches rejected';
  END IF;

  INSERT INTO DIM_AREA_TYPE (area_type_code, area_type_name, lineage_group_id)
  VALUES ('G', 'Demo Street', 'p0-test-batch-1');
  SET area_type_id = LAST_INSERT_ID();

  INSERT INTO DIM_DISTRICT (district_code, district_name, lineage_group_id)
  VALUES ('11000', 'Demo District', 'p0-test-batch-1');
  SET district_id = LAST_INSERT_ID();

  INSERT INTO DIM_DONG (dong_code, dong_name, lineage_group_id)
  VALUES ('110001', 'Demo Dong', 'p0-test-batch-1');
  SET dong_id = LAST_INSERT_ID();

  INSERT INTO DIM_PERIOD
    (period_type_code, calendar_code, period_code, period_name, base_year,
     quarter_no, period_start_date, period_end_date, period_precision_code, lineage_group_id)
  VALUES ('QUARTER', 'GREGORIAN', '2026Q1', '2026 Q1', 2026,
          1, '2026-01-01', '2026-03-31', 'QUARTER', 'p0-test-batch-1');
  SET period_id = LAST_INSERT_ID();

  INSERT INTO DIM_AREA
    (area_code, version_no, area_name, area_type_key, district_key, dong_key,
     coordinate_system_code, area_size, effective_start_date, is_current, lineage_group_id)
  VALUES ('p0-demo', 1, 'P0 Demo', area_type_id, district_id, dong_id,
          'EPSG:5181', 1000.500000, '2025-01-01', 'Y', 'p0-test-batch-1');
  SET area_id = LAST_INSERT_ID();

  INSERT INTO DIM_INDUSTRY
    (service_industry_code, service_industry_name, classification_version,
     effective_start_date, is_current, lineage_group_id)
  VALUES ('C001', 'Demo Cafe', 'SEOUL-DEMO-2026', '2025-01-01', 'Y', 'p0-test-batch-1');
  SET industry_id = LAST_INSERT_ID();

  INSERT INTO FACT_AREA_SALES
    (period_key, area_key, industry_key, estimated_sales_amount, lineage_group_id)
  VALUES (period_id, area_id, industry_id, 123456.78, 'p0-test-batch-1');

  -- Explicit source-specific decision: here the observation and reporting periods coincide.
  INSERT INTO FACT_AREA_STORE
    (period_key, area_key, industry_key, observation_period_key, store_count,
     similar_industry_store_count, opening_rate, opened_store_count,
     closure_rate, closed_store_count, franchise_store_count, lineage_group_id)
  VALUES (period_id, area_id, industry_id, period_id, 12, 18, 10.0, 2, 3.0, 1, 3, 'p0-test-batch-1');

  SELECT COUNT(*) INTO row_count_test
    FROM FACT_AREA_SALES sa
    JOIN FACT_AREA_STORE st
      ON sa.period_key = st.period_key
     AND sa.area_key = st.area_key
     AND sa.industry_key = st.industry_key
    JOIN DIM_PERIOD dp ON dp.period_key = sa.period_key
   WHERE dp.period_code = '2026Q1' AND st.observation_period_key = sa.period_key;
  IF row_count_test <> 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'P0 period-area-industry fact join failed';
  END IF;

  -- The same source row in the same batch/document/path must fail.
  SET caught_error = 0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 caught_error = MYSQL_ERRNO;
    END;
    INSERT INTO SRC_SEOUL_AREA
      (collection_batch_id, source_document_id, source_record_path, raw_record_text)
    VALUES ('p0-test-batch-1', 'area-demo', '/records/1', '{}');
  END;
  IF caught_error <> 1062 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'source duplicate uniqueness not enforced';
  END IF;

  -- Exactly one current area version per business code.
  SET caught_error = 0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 caught_error = MYSQL_ERRNO;
    END;
    INSERT INTO DIM_AREA
      (area_code, version_no, area_name, area_type_key, district_key, dong_key,
       effective_start_date, is_current, lineage_group_id)
    VALUES ('p0-demo', 2, 'Duplicate Current', area_type_id, district_id, dong_id,
            '2026-01-01', 'Y', 'p0-test-batch-1');
  END;
  IF caught_error <> 1062 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'current area uniqueness not enforced';
  END IF;

  SET caught_error = 0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 caught_error = MYSQL_ERRNO;
    END;
    INSERT INTO FACT_AREA_SALES
      (period_key, area_key, industry_key, estimated_sales_amount, lineage_group_id)
    VALUES (period_id, area_id, industry_id, 999, 'p0-test-batch-1');
  END;
  IF caught_error <> 1062 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'sales fact grain uniqueness not enforced';
  END IF;

  SET caught_error = 0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 caught_error = MYSQL_ERRNO;
    END;
    INSERT INTO FACT_AREA_SALES
      (period_key, area_key, industry_key, estimated_sales_amount, lineage_group_id)
    VALUES (period_id, area_id, 999999999999, 999, 'p0-test-batch-1');
  END;
  IF caught_error <> 1452 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'fact industry FK not enforced';
  END IF;

  SET caught_error = 0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 caught_error = MYSQL_ERRNO;
    END;
    UPDATE FACT_AREA_SALES SET estimated_sales_amount = -1
    WHERE period_key = period_id AND area_key = area_id AND industry_key = industry_id;
  END;
  IF caught_error <> 3819 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'negative sales CHECK not enforced';
  END IF;

  SET caught_error = 0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 caught_error = MYSQL_ERRNO;
    END;
    UPDATE FACT_AREA_STORE SET opening_rate = -1.0
    WHERE period_key = period_id AND area_key = area_id AND industry_key = industry_id;
  END;
  IF caught_error <> 3819 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'negative opening-rate CHECK not enforced';
  END IF;

  -- Rates over 100 are valid in archive and must not be rejected.
  UPDATE FACT_AREA_STORE SET opening_rate = 200.0, closure_rate = 4800.0
  WHERE period_key = period_id AND area_key = area_id AND industry_key = industry_id;

  SET caught_error = 0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 caught_error = MYSQL_ERRNO;
    END;
    UPDATE FACT_AREA_STORE SET observation_period_key = NULL
    WHERE period_key = period_id AND area_key = area_id AND industry_key = industry_id;
  END;
  IF caught_error <> 1048 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'observation period NOT NULL not enforced';
  END IF;

  ROLLBACK;
  SELECT 'PASS: P0 11-table inserts, joins, uniqueness, FK, CHECK and required observation period' AS result;
END$$
DELIMITER ;

CALL p0_integrity_smoke();
DROP PROCEDURE p0_integrity_smoke;
