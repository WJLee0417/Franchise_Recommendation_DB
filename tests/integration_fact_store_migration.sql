USE franchise_dw_p0;
-- Assert exact changed shape.
DELIMITER //
CREATE PROCEDURE p35_assert_contract()
BEGIN
 DECLARE n INT;
 SELECT COUNT(*) INTO n FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='FACT_AREA_STORE'
 AND COLUMN_NAME IN ('ordinary_store_count','total_store_count','franchise_store_count');
 IF n<>3 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='expected 3 count measures'; END IF;
 SELECT COUNT(*) INTO n FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='FACT_AREA_STORE'
 AND COLUMN_NAME IN ('store_count','similar_industry_store_count');
 IF n<>0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='legacy measures still present'; END IF;
 SELECT COUNT(*) INTO n FROM information_schema.CHECK_CONSTRAINTS
 WHERE CONSTRAINT_SCHEMA=DATABASE() AND CONSTRAINT_NAME='ck_fast_total_decomposition';
 IF n<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='missing decomposition CHECK'; END IF;
END//
DELIMITER ;
CALL p35_assert_contract();
DROP PROCEDURE p35_assert_contract;
-- synthetic FK anchor rows with documented synthetic-only temporal fields; not historical archive
INSERT INTO DIM_AREA_TYPE (area_type_code,area_type_name,lineage_group_id) VALUES ('X','synthetic','ci');
INSERT INTO DIM_DISTRICT (district_code,district_name,lineage_group_id) VALUES ('X','synthetic','ci');
INSERT INTO DIM_DONG (dong_code,dong_name,lineage_group_id) VALUES ('X','synthetic','ci');
INSERT INTO DIM_PERIOD (period_type_code,calendar_code,period_code,period_name,base_year,quarter_no,period_start_date,period_end_date,period_precision_code,lineage_group_id)
VALUES ('QUARTER','GREGORIAN','2099Q1','synthetic',2099,1,'2099-01-01','2099-03-31','QUARTER','ci');
INSERT INTO DIM_AREA (area_code,version_no,area_name,area_type_key,district_key,dong_key,effective_start_date,is_current,lineage_group_id)
VALUES ('X',1,'synthetic',1,1,1,'2099-01-01','Y','ci');
INSERT INTO DIM_INDUSTRY (service_industry_code,service_industry_name,classification_version,effective_start_date,is_current,lineage_group_id)
VALUES ('CSX','synthetic','ci','2099-01-01','Y','ci');
INSERT INTO FACT_AREA_STORE(period_key,area_key,industry_key,observation_period_key,ordinary_store_count,total_store_count,franchise_store_count,opening_rate,closure_rate,lineage_group_id)
VALUES(1,1,1,1,3,5,2,200,4800,'ci');
-- Constraint must refuse inconsistent total.
DELIMITER //
CREATE PROCEDURE p35_assert_bad_sum()
BEGIN
 DECLARE rejected BOOLEAN DEFAULT FALSE;
 BEGIN
   DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
   UPDATE FACT_AREA_STORE SET total_store_count=9
   WHERE period_key=1 AND area_key=1 AND industry_key=1 AND observation_period_key=1;
 END;
 IF rejected=FALSE THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='bad sum unexpectedly inserted'; END IF;
END//
DELIMITER ;
CALL p35_assert_bad_sum();
DROP PROCEDURE p35_assert_bad_sum;
SELECT 'PASS FACT store 006: new names, sum CHECK, >100 rates' AS result;
