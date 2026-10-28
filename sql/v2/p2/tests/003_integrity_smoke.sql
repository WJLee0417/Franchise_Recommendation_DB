-- P2 smoke test: clean disposable DB, after P0 then P1 then P2.
-- Test observations are rolled back. Expected errors are exact MySQL 8 errno.
USE franchise_dw_p0;
DELIMITER $$
CREATE PROCEDURE p2_integrity_smoke()
BEGIN
 DECLARE v_period BIGINT UNSIGNED;
 DECLARE v_hq BIGINT UNSIGNED;
 DECLARE v_brand BIGINT UNSIGNED;
 DECLARE v_other_brand BIGINT UNSIGNED;
 DECLARE v_disclosure BIGINT UNSIGNED;
 DECLARE v_err INT DEFAULT 0;
 DECLARE v_n INT DEFAULT 0;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 INSERT INTO DIM_PERIOD(period_type_code,calendar_code,period_code,period_name,base_year,quarter_no,period_start_date,period_end_date,period_precision_code,lineage_group_id)
 VALUES ('YEAR','P2_TEST','2026','2026',2026,NULL,'2026-01-01','2026-12-31','YEAR','p2-test');
 SET v_period=LAST_INSERT_ID();
 INSERT INTO DIM_HEADQUARTER(headquarter_management_no,version_no,company_name,effective_start_date,is_current,lineage_group_id)
 VALUES ('P2-HQ',1,'P2 HQ','2025-01-01','Y','p2-test');
 SET v_hq=LAST_INSERT_ID();
 INSERT INTO DIM_FRANCHISE(brand_management_no,version_no,brand_name,headquarter_key,effective_start_date,is_current,lineage_group_id)
 VALUES ('P2-BRAND',1,'P2 Brand',v_hq,'2025-01-01','Y','p2-test');
 SET v_brand=LAST_INSERT_ID();
 INSERT INTO DIM_FRANCHISE(brand_management_no,version_no,brand_name,headquarter_key,effective_start_date,is_current,lineage_group_id)
 VALUES ('P2-OTHER',1,'Other Brand',v_hq,'2025-01-01','Y','p2-test');
 SET v_other_brand=LAST_INSERT_ID();
 INSERT INTO DIM_DISCLOSURE_VERSION(disclosure_no,disclosure_version_code,franchise_key,initial_contract_period,initial_contract_unit_code,lineage_group_id)
 VALUES ('P2-DISC','V1',v_brand,3,'YEAR','p2-test');
 SET v_disclosure=LAST_INSERT_ID();

 -- Unknown source numeric values are retained verbatim.
 INSERT INTO SRC_FTC_CONTRACT(collection_batch_id,source_document_id,source_record_path,raw_record_text,disclosure_no,initial_contract_period)
 VALUES('p2-batch','p2-contract','/1','{"initial_contract_period":"N/A"}','P2-DISC','N/A');
 INSERT INTO SRC_FTC_STARTUP_COST(collection_batch_id,source_document_id,source_record_path,raw_record_text,disclosure_no,joining_fee)
 VALUES('p2-batch','p2-cost','/1','{"joining_fee":"0"}','P2-DISC','0');
 INSERT INTO SRC_FTC_INTERIOR(collection_batch_id,source_document_id,source_record_path,raw_record_text,disclosure_no,standard_store_area)
 VALUES('p2-batch','p2-interior','/1','{"standard_store_area":"30"}','P2-DISC','30');
 INSERT INTO SRC_FTC_AD_PROMOTION(collection_batch_id,source_document_id,source_record_path,raw_record_text,disclosure_no)
 VALUES('p2-batch','p2-ad','/1','{}','P2-DISC');
 INSERT INTO SRC_FTC_EMPLOYEE(collection_batch_id,source_document_id,source_record_path,raw_record_text,disclosure_no)
 VALUES('p2-batch','p2-employee','/1','{}','P2-DISC');
 INSERT INTO SRC_FTC_LEGAL(collection_batch_id,source_document_id,source_record_path,raw_record_text,disclosure_no)
 VALUES('p2-batch','p2-legal','/1','{}','P2-DISC');

 INSERT INTO FACT_FRANCHISE_STARTUP_COST(disclosure_version_key,franchise_key,joining_fee,training_fee,lineage_group_id)
 VALUES(v_disclosure,v_brand,0,NULL,'p2-test');
 INSERT INTO FACT_FRANCHISE_INTERIOR(disclosure_version_key,specification_code,franchise_key,standard_store_area,interior_cost_per_area,interior_total_cost,lineage_group_id)
 VALUES(v_disclosure,'P2-SPEC',v_brand,30,1000,30000,'p2-test');
 INSERT INTO FACT_AD_PROMOTION(headquarter_key,period_key,advertising_amount,promotion_amount,lineage_group_id)
 VALUES(v_hq,v_period,100,0,'p2-test');
 INSERT INTO FACT_HQ_EMPLOYEE(headquarter_key,period_key,executive_count,employee_count,lineage_group_id)
 VALUES(v_hq,v_period,1,12,'p2-test');
 INSERT INTO FACT_HQ_LEGAL(headquarter_key,period_key,corrective_action_count,civil_case_count,criminal_sentence_count,lineage_group_id)
 VALUES(v_hq,v_period,0,0,NULL,'p2-test');

 SELECT COUNT(*) INTO v_n
 FROM FACT_FRANCHISE_STARTUP_COST s
 JOIN DIM_DISCLOSURE_VERSION d ON d.disclosure_version_key=s.disclosure_version_key AND d.franchise_key=s.franchise_key
 JOIN DIM_FRANCHISE f ON f.franchise_key=d.franchise_key
 WHERE f.brand_management_no='P2-BRAND';
 IF v_n<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2 disclosure-brand join'; END IF;
 SELECT COUNT(*) INTO v_n FROM FACT_HQ_EMPLOYEE e JOIN FACT_HQ_LEGAL l
  ON l.headquarter_key=e.headquarter_key AND l.period_key=e.period_key
 WHERE e.headquarter_key=v_hq AND e.period_key=v_period;
 IF v_n<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2 HQ facts join'; END IF;

 -- Existing disclosure belongs to v_brand, never v_other_brand.
 SET v_err=0;
 BEGIN DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_err=MYSQL_ERRNO; END;
 INSERT INTO FACT_FRANCHISE_STARTUP_COST(disclosure_version_key,franchise_key,joining_fee,lineage_group_id)
 VALUES(v_disclosure,v_other_brand,100,'p2-test');
 END;
 IF v_err<>1452 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2 disclosure-brand composite FK not enforced'; END IF;

 SET v_err=0;
 BEGIN DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_err=MYSQL_ERRNO; END;
 INSERT INTO FACT_FRANCHISE_INTERIOR(disclosure_version_key,specification_code,franchise_key,lineage_group_id)
 VALUES(v_disclosure,' ',v_brand,'p2-test');
 END;
 IF v_err<>3819 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2 specification CHECK not enforced'; END IF;

 SET v_err=0;
 BEGIN DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_err=MYSQL_ERRNO; END;
 INSERT INTO FACT_FRANCHISE_INTERIOR(disclosure_version_key,specification_code,franchise_key,lineage_group_id)
 VALUES(v_disclosure,'P2-SPEC',v_brand,'p2-test');
 END;
 IF v_err<>1062 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2 interior PK not enforced'; END IF;

 SET v_err=0;
 BEGIN DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_err=MYSQL_ERRNO; END;
 UPDATE FACT_FRANCHISE_STARTUP_COST SET joining_fee=-1 WHERE disclosure_version_key=v_disclosure;
 END;
 IF v_err<>3819 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2 negative cost CHECK not enforced'; END IF;

 SET v_err=0;
 BEGIN DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_err=MYSQL_ERRNO; END;
 INSERT INTO FACT_HQ_LEGAL(headquarter_key,period_key,lineage_group_id) VALUES(v_hq,v_period,'p2-test');
 END;
 IF v_err<>1062 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2 HQ fact grain not enforced'; END IF;

 SET v_err=0;
 BEGIN DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_err=MYSQL_ERRNO; END;
 INSERT INTO SRC_FTC_CONTRACT(collection_batch_id,source_document_id,source_record_path,raw_record_text)
 VALUES('p2-batch','p2-contract','/1','{}');
 END;
 IF v_err<>1062 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2 source uniqueness not enforced'; END IF;

 ROLLBACK;
 SELECT 'PASS P2: raw, facts, joins, composite FK, PK, CHECK, source uniqueness' AS result;
END$$
DELIMITER ;
CALL p2_integrity_smoke();
DROP PROCEDURE p2_integrity_smoke;
