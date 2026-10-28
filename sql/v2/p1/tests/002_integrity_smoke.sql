-- P1 integrity smoke. Run after 001_schema.sql and 002_schema.sql on a fresh disposable DB.
-- Transaction rollback protects persistent records. Procedure is removed after execution.
-- Negative tests verify exact MySQL errno: 1062 duplicate, 1452 FK, 3819 CHECK.
USE franchise_dw_p0;
DELIMITER $$
CREATE PROCEDURE p1_integrity_smoke()
BEGIN
 DECLARE v_period BIGINT UNSIGNED;
 DECLARE v_hq BIGINT UNSIGNED;
 DECLARE v_franchise BIGINT UNSIGNED;
 DECLARE v_region BIGINT UNSIGNED;
 DECLARE v_industry BIGINT UNSIGNED;
 DECLARE v_disclosure BIGINT UNSIGNED;
 DECLARE v_area_type BIGINT UNSIGNED;
 DECLARE v_district BIGINT UNSIGNED;
 DECLARE v_dong BIGINT UNSIGNED;
 DECLARE v_area BIGINT UNSIGNED;
 DECLARE v_err INT DEFAULT 0;
 DECLARE v_count INT DEFAULT 0;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 INSERT INTO DIM_PERIOD(period_type_code,calendar_code,period_code,period_name,base_year,quarter_no,period_start_date,period_end_date,period_precision_code,lineage_group_id)
 VALUES('YEAR','P1_TEST','P1-2026','P1 Year 2026',2026,NULL,'2026-01-01','2026-12-31','YEAR','p1-test');
 SET v_period=LAST_INSERT_ID();
 INSERT INTO DIM_AREA_TYPE(area_type_code,area_type_name,lineage_group_id) VALUES('P1-T','Test','p1-test');
 SET v_area_type=LAST_INSERT_ID();
 INSERT INTO DIM_DISTRICT(district_code,district_name,lineage_group_id) VALUES('P1-11','Test','p1-test');
 SET v_district=LAST_INSERT_ID();
 INSERT INTO DIM_DONG(dong_code,dong_name,lineage_group_id) VALUES('P1-1101','Test','p1-test');
 SET v_dong=LAST_INSERT_ID();
 INSERT INTO DIM_AREA(area_code,version_no,area_name,area_type_key,district_key,dong_key,effective_start_date,is_current,lineage_group_id)
 VALUES('P1-AREA',1,'Test',v_area_type,v_district,v_dong,'2025-01-01','Y','p1-test');
 SET v_area=LAST_INSERT_ID();
 INSERT INTO DIM_HEADQUARTER(headquarter_management_no,version_no,company_name,effective_start_date,is_current,lineage_group_id)
 VALUES('HQ-P1',1,'HQ Test','2025-01-01','Y','p1-test');
 SET v_hq=LAST_INSERT_ID();
 INSERT INTO DIM_REGION(region_system_code,region_code,region_name,region_level_code,region_version,effective_start_date,is_current,lineage_group_id)
 VALUES('FTC_DEMO','SEOUL','Test Region','CITY','2026','2025-01-01','Y','p1-test');
 SET v_region=LAST_INSERT_ID();
 -- FTC→Seoul industry mapping is not verified. Keep franchise.industry_key NULL.
 INSERT INTO DIM_FRANCHISE(brand_management_no,version_no,brand_name,headquarter_key,industry_key,effective_start_date,is_current,lineage_group_id)
 VALUES('BRAND-P1',1,'Test Franchise',v_hq,NULL,'2025-01-01','Y','p1-test');
 SET v_franchise=LAST_INSERT_ID();
 INSERT INTO DIM_DISCLOSURE_VERSION(disclosure_no,disclosure_version_code,franchise_key,initial_contract_period,initial_contract_unit_code,lineage_group_id)
 VALUES('DISC-P1','V1',v_franchise,3,'YEAR','p1-test');
 SET v_disclosure=LAST_INSERT_ID();
 INSERT INTO FACT_HQ_FINANCE(headquarter_key,period_key,accounting_scope_code,assets,liabilities,capital,revenue,operating_income,net_income,lineage_group_id)
 VALUES(v_hq,v_period,'SEPARATE',100,150,-50,100,-20,-30,'p1-test');
 INSERT INTO FACT_FRANCHISE_STORE(franchise_key,period_key,region_key,franchise_store_count,direct_store_count,lineage_group_id)
 VALUES(v_franchise,v_period,v_region,12,2,'p1-test');
 INSERT INTO FACT_FRANCHISE_CHANGE(franchise_key,period_key,new_store_count,contract_expired_count,contract_terminated_count,lineage_group_id)
 VALUES(v_franchise,v_period,3,1,0,'p1-test');
 INSERT INTO FACT_FRANCHISE_AVG_SALES(franchise_key,period_key,region_key,average_sales_amount,sales_amount_per_area,lineage_group_id)
 VALUES(v_franchise,v_period,v_region,123.45,12.345,'p1-test');
 INSERT INTO FACT_AREA_INCOME(period_key,area_key,monthly_average_income,income_bracket_code,lineage_group_id)
 VALUES(v_period,v_area,12345,'4','p1-test');
 INSERT INTO FACT_AREA_FLOW_POP(period_key,area_key,observation_period_key,total_flow_population,male_flow_population,female_flow_population,lineage_group_id)
 VALUES(v_period,v_area,v_period,123.5,60,63.5,'p1-test');
 INSERT INTO SRC_FTC_DISCLOSURE(collection_batch_id,source_document_id,source_record_path,raw_record_text,disclosure_no)
 VALUES('p1-batch','p1-doc','/1','{"disclosure_no":"DISC-P1"}','DISC-P1');
 SELECT COUNT(*) INTO v_count FROM FACT_FRANCHISE_STORE fs
 JOIN DIM_FRANCHISE fr ON fr.franchise_key=fs.franchise_key
 JOIN DIM_HEADQUARTER h ON h.headquarter_key=fr.headquarter_key
 JOIN DIM_REGION r ON r.region_key=fs.region_key
 WHERE fr.brand_management_no='BRAND-P1' AND fs.period_key=v_period;
 IF v_count<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1 franchise chain JOIN failed'; END IF;
 SET v_err=0;
 BEGIN DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_err = MYSQL_ERRNO;
    END;
 INSERT INTO DIM_HEADQUARTER(headquarter_management_no,version_no,company_name,effective_start_date,is_current,lineage_group_id)
 VALUES('HQ-P1',2,'Duplicate Current','2026-01-01','Y','p1-test');
 END;
 IF v_err <> 1062 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1 HQ current uniqueness failed'; END IF;
 SET v_err=0;
 BEGIN DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_err = MYSQL_ERRNO;
    END;
 INSERT INTO DIM_FRANCHISE(brand_management_no,version_no,brand_name,headquarter_key,effective_start_date,is_current,lineage_group_id)
 VALUES('ORPHAN-P1',1,'No HQ',99999999999,'2025-01-01','Y','p1-test');
 END;
 IF v_err <> 1452 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1 orphan franchise FK failed'; END IF;
 SET v_err=0;
 BEGIN DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_err = MYSQL_ERRNO;
    END;
 INSERT INTO DIM_DISCLOSURE_VERSION(disclosure_no,disclosure_version_code,franchise_key,initial_contract_period,initial_contract_unit_code,lineage_group_id)
 VALUES('D-BAD','V1',v_franchise,3,NULL,'p1-test');
 END;
 IF v_err <> 3819 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1 contract unit CHECK failed'; END IF;
 SET v_err=0;
 BEGIN DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_err = MYSQL_ERRNO;
    END;
 INSERT INTO FACT_FRANCHISE_STORE(franchise_key,period_key,region_key,franchise_store_count,lineage_group_id)
 VALUES(v_franchise,v_period,v_region,100,'p1-test');
 END;
 IF v_err <> 1062 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1 franchise FACT grain uniqueness failed'; END IF;
 SET v_err=0;
 BEGIN DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_err = MYSQL_ERRNO;
    END;
 UPDATE FACT_FRANCHISE_AVG_SALES SET average_sales_amount=-1
 WHERE franchise_key=v_franchise AND period_key=v_period AND region_key=v_region;
 END;
 IF v_err <> 3819 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1 negative avg sales CHECK failed'; END IF;
 SET v_err=0;
 BEGIN DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN
      GET DIAGNOSTICS CONDITION 1 v_err = MYSQL_ERRNO;
    END;
 INSERT INTO SRC_FTC_DISCLOSURE(collection_batch_id,source_document_id,source_record_path,raw_record_text)
 VALUES('p1-batch','p1-doc','/1','{}');
 END;
 IF v_err <> 1062 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1 raw source UNIQUE failed'; END IF;
 ROLLBACK;
 SELECT 'PASS P1: FK, UNIQUE, CHECK, finance negatives and SRC lineage' AS result;
END$$
DELIMITER ;
CALL p1_integrity_smoke();
DROP PROCEDURE p1_integrity_smoke;
