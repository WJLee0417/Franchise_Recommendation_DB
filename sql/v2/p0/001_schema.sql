-- Phase 2-1: isolated MySQL 8.0.16+ P0 warehouse schema.
-- ERD: 상권분석ERD(1).damx (SHA-256: 0fd22beb5239b071b39035deb3adb1485cc4261a07283927d3bca75f4d3de1b0)
-- Run without changing legacy sql/schema.sql. Re-running intentionally fails on existing tables.
CREATE DATABASE IF NOT EXISTS franchise_dw_p0 CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
USE franchise_dw_p0;

-- Preserve original source values and raw_record_text; invalid business fields may be NULL.
CREATE TABLE SRC_SEOUL_AREA (
  source_row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  collection_batch_id VARCHAR(50) NOT NULL,
  source_document_id VARCHAR(200) NOT NULL,
  source_record_path VARCHAR(500) NOT NULL,
  source_url VARCHAR(2048) NULL,
  source_version VARCHAR(100) NULL,
  reference_period_text VARCHAR(200) NULL,
  unit_metadata_text LONGTEXT NULL,
  raw_record_text LONGTEXT NOT NULL,
  collected_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  area_code VARCHAR(50) NULL,
  area_name VARCHAR(200) NULL,
  area_type_code VARCHAR(50) NULL,
  area_type_name VARCHAR(100) NULL,
  x_coordinate VARCHAR(100) NULL,
  y_coordinate VARCHAR(100) NULL,
  district_code VARCHAR(50) NULL,
  district_name VARCHAR(100) NULL,
  dong_code VARCHAR(50) NULL,
  dong_name VARCHAR(100) NULL,
  area_size VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_ssa_record (collection_batch_id, source_document_id, source_record_path),
  KEY ix_ssa_batch (collection_batch_id),
  CONSTRAINT ck_ssa_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id)) > 0),
  CONSTRAINT ck_ssa_document CHECK (CHAR_LENGTH(TRIM(source_document_id)) > 0),
  CONSTRAINT ck_ssa_path CHECK (CHAR_LENGTH(TRIM(source_record_path)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Preserve original source values and raw_record_text; invalid business fields may be NULL.
CREATE TABLE SRC_SEOUL_SALES (
  source_row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  collection_batch_id VARCHAR(50) NOT NULL,
  source_document_id VARCHAR(200) NOT NULL,
  source_record_path VARCHAR(500) NOT NULL,
  source_url VARCHAR(2048) NULL,
  source_version VARCHAR(100) NULL,
  reference_period_text VARCHAR(200) NULL,
  unit_metadata_text LONGTEXT NULL,
  raw_record_text LONGTEXT NOT NULL,
  collected_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  base_year_quarter VARCHAR(20) NULL,
  area_type_code VARCHAR(50) NULL,
  area_type_name VARCHAR(100) NULL,
  area_code VARCHAR(50) NULL,
  area_name VARCHAR(200) NULL,
  service_industry_code VARCHAR(50) NULL,
  service_industry_name VARCHAR(200) NULL,
  estimated_sales_amount VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_sss_record (collection_batch_id, source_document_id, source_record_path),
  KEY ix_sss_batch (collection_batch_id),
  CONSTRAINT ck_sss_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id)) > 0),
  CONSTRAINT ck_sss_document CHECK (CHAR_LENGTH(TRIM(source_document_id)) > 0),
  CONSTRAINT ck_sss_path CHECK (CHAR_LENGTH(TRIM(source_record_path)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Preserve original source values and raw_record_text; invalid business fields may be NULL.
CREATE TABLE SRC_SEOUL_STORE (
  source_row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  collection_batch_id VARCHAR(50) NOT NULL,
  source_document_id VARCHAR(200) NOT NULL,
  source_record_path VARCHAR(500) NOT NULL,
  source_url VARCHAR(2048) NULL,
  source_version VARCHAR(100) NULL,
  reference_period_text VARCHAR(200) NULL,
  unit_metadata_text LONGTEXT NULL,
  raw_record_text LONGTEXT NOT NULL,
  collected_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  base_year_quarter VARCHAR(20) NULL,
  area_type_code VARCHAR(50) NULL,
  area_type_name VARCHAR(100) NULL,
  area_code VARCHAR(50) NULL,
  area_name VARCHAR(200) NULL,
  service_industry_code VARCHAR(50) NULL,
  service_industry_name VARCHAR(200) NULL,
  store_count VARCHAR(100) NULL,
  similar_industry_store_count VARCHAR(100) NULL,
  opening_rate VARCHAR(100) NULL,
  opened_store_count VARCHAR(100) NULL,
  closure_rate VARCHAR(100) NULL,
  closed_store_count VARCHAR(100) NULL,
  franchise_store_count VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_sst_record (collection_batch_id, source_document_id, source_record_path),
  KEY ix_sst_batch (collection_batch_id),
  CONSTRAINT ck_sst_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id)) > 0),
  CONSTRAINT ck_sst_document CHECK (CHAR_LENGTH(TRIM(source_document_id)) > 0),
  CONSTRAINT ck_sst_path CHECK (CHAR_LENGTH(TRIM(source_record_path)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Conformed reference dimension; original code retained as VARCHAR.
CREATE TABLE DIM_AREA_TYPE (
  area_type_key BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  area_type_code VARCHAR(50) NOT NULL,
  area_type_name VARCHAR(100) NOT NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (area_type_key),
  UNIQUE KEY uq_dat_code (area_type_code),
  CONSTRAINT ck_dat_code CHECK (CHAR_LENGTH(TRIM(area_type_code)) > 0),
  CONSTRAINT ck_dat_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Conformed reference dimension; original code retained as VARCHAR.
CREATE TABLE DIM_DISTRICT (
  district_key BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  district_code VARCHAR(50) NOT NULL,
  district_name VARCHAR(100) NOT NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (district_key),
  UNIQUE KEY uq_dd_code (district_code),
  CONSTRAINT ck_dd_code CHECK (CHAR_LENGTH(TRIM(district_code)) > 0),
  CONSTRAINT ck_dd_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Conformed reference dimension; original code retained as VARCHAR.
CREATE TABLE DIM_DONG (
  dong_key BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  dong_code VARCHAR(50) NOT NULL,
  dong_name VARCHAR(100) NOT NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (dong_key),
  UNIQUE KEY uq_dong_code (dong_code),
  CONSTRAINT ck_dong_code CHECK (CHAR_LENGTH(TRIM(dong_code)) > 0),
  CONSTRAINT ck_dong_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- The reporting and observation periods use the same period dimension.
CREATE TABLE DIM_PERIOD (
  period_key BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  period_type_code VARCHAR(20) NOT NULL,
  calendar_code VARCHAR(50) NOT NULL,
  period_code VARCHAR(100) NOT NULL,
  period_name VARCHAR(150) NOT NULL,
  base_year SMALLINT NOT NULL,
  quarter_no TINYINT NULL,
  period_start_date DATE NOT NULL,
  period_end_date DATE NOT NULL,
  period_precision_code VARCHAR(20) NOT NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (period_key),
  UNIQUE KEY uq_dp_natural (calendar_code, period_type_code, period_code),
  CONSTRAINT ck_dp_dates CHECK (period_end_date >= period_start_date),
  CONSTRAINT ck_dp_quarter CHECK ((period_type_code = 'QUARTER' AND quarter_no BETWEEN 1 AND 4) OR (period_type_code <> 'QUARTER' AND quarter_no IS NULL)),
  CONSTRAINT ck_dp_year CHECK (base_year BETWEEN 1 AND 9999),
  CONSTRAINT ck_dp_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Type-2 area version; exclusive end date. Generated current_area_code guards at most one current row per code.
CREATE TABLE DIM_AREA (
  area_key BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  area_code VARCHAR(50) NOT NULL,
  version_no INT NOT NULL,
  area_name VARCHAR(200) NOT NULL,
  area_type_key BIGINT UNSIGNED NOT NULL,
  district_key BIGINT UNSIGNED NOT NULL,
  dong_key BIGINT UNSIGNED NOT NULL,
  x_coordinate DECIMAL(18,6) NULL,
  y_coordinate DECIMAL(18,6) NULL,
  coordinate_system_code VARCHAR(30) NULL,
  area_size DECIMAL(24,6) NULL,
  source_area_version VARCHAR(100) NULL,
  effective_start_date DATE NOT NULL,
  effective_end_date DATE NULL,
  is_current CHAR(1) NOT NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  current_area_code VARCHAR(50) GENERATED ALWAYS AS (CASE WHEN is_current = 'Y' THEN area_code ELSE NULL END) STORED,
  PRIMARY KEY (area_key),
  UNIQUE KEY uq_da_version (area_code, version_no),
  UNIQUE KEY uq_da_current (current_area_code),
  KEY ix_da_effective (area_code, effective_start_date, effective_end_date),
  KEY ix_da_type (area_type_key),
  KEY ix_da_district (district_key),
  KEY ix_da_dong (dong_key),
  CONSTRAINT fk_da_type FOREIGN KEY (area_type_key) REFERENCES DIM_AREA_TYPE(area_type_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_da_district FOREIGN KEY (district_key) REFERENCES DIM_DISTRICT(district_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_da_dong FOREIGN KEY (dong_key) REFERENCES DIM_DONG(dong_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_da_version CHECK (version_no > 0),
  CONSTRAINT ck_da_dates CHECK (effective_end_date IS NULL OR effective_end_date > effective_start_date),
  CONSTRAINT ck_da_current CHECK ((is_current = 'Y' AND effective_end_date IS NULL) OR (is_current = 'N' AND effective_end_date IS NOT NULL)),
  CONSTRAINT ck_da_area_size CHECK (area_size IS NULL OR area_size >= 0),
  CONSTRAINT ck_da_code CHECK (CHAR_LENGTH(TRIM(area_code)) > 0),
  CONSTRAINT ck_da_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Seoul industry taxonomy only; cross-source FTC mapping is outside P0.
CREATE TABLE DIM_INDUSTRY (
  industry_key BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  service_industry_code VARCHAR(50) NOT NULL,
  service_industry_name VARCHAR(200) NOT NULL,
  classification_version VARCHAR(100) NOT NULL,
  effective_start_date DATE NOT NULL,
  effective_end_date DATE NULL,
  is_current CHAR(1) NOT NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  current_industry_code VARCHAR(50) GENERATED ALWAYS AS (CASE WHEN is_current = 'Y' THEN service_industry_code ELSE NULL END) STORED,
  PRIMARY KEY (industry_key),
  UNIQUE KEY uq_di_version (service_industry_code, classification_version, effective_start_date),
  UNIQUE KEY uq_di_current (current_industry_code),
  KEY ix_di_effective (service_industry_code, effective_start_date, effective_end_date),
  CONSTRAINT ck_di_dates CHECK (effective_end_date IS NULL OR effective_end_date > effective_start_date),
  CONSTRAINT ck_di_current CHECK ((is_current = 'Y' AND effective_end_date IS NULL) OR (is_current = 'N' AND effective_end_date IS NOT NULL)),
  CONSTRAINT ck_di_code CHECK (CHAR_LENGTH(TRIM(service_industry_code)) > 0),
  CONSTRAINT ck_di_class CHECK (CHAR_LENGTH(TRIM(classification_version)) > 0),
  CONSTRAINT ck_di_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Grain: reporting period x exact area version x exact industry version.
CREATE TABLE FACT_AREA_SALES (
  period_key BIGINT UNSIGNED NOT NULL,
  area_key BIGINT UNSIGNED NOT NULL,
  industry_key BIGINT UNSIGNED NOT NULL,
  estimated_sales_amount DECIMAL(24,2) NOT NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (period_key, area_key, industry_key),
  KEY ix_fas_area (area_key),
  KEY ix_fas_industry (industry_key),
  CONSTRAINT fk_fas_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_fas_area FOREIGN KEY (area_key) REFERENCES DIM_AREA(area_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_fas_industry FOREIGN KEY (industry_key) REFERENCES DIM_INDUSTRY(industry_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_fas_sales CHECK (estimated_sales_amount >= 0),
  CONSTRAINT ck_fas_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Grain: reporting period x observation period x area version x industry version. Rates in percent 0..100.
CREATE TABLE FACT_AREA_STORE (
  period_key BIGINT UNSIGNED NOT NULL,
  area_key BIGINT UNSIGNED NOT NULL,
  industry_key BIGINT UNSIGNED NOT NULL,
  observation_period_key BIGINT UNSIGNED NOT NULL,
  store_count BIGINT UNSIGNED NOT NULL,
  similar_industry_store_count BIGINT UNSIGNED NULL,
  opening_rate DECIMAL(12,6) NULL,
  opened_store_count BIGINT UNSIGNED NULL,
  closure_rate DECIMAL(12,6) NULL,
  closed_store_count BIGINT UNSIGNED NULL,
  franchise_store_count BIGINT UNSIGNED NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (period_key, area_key, industry_key, observation_period_key),
  KEY ix_fast_area (area_key),
  KEY ix_fast_industry (industry_key),
  KEY ix_fast_observation (observation_period_key),
  CONSTRAINT fk_fast_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_fast_area FOREIGN KEY (area_key) REFERENCES DIM_AREA(area_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_fast_industry FOREIGN KEY (industry_key) REFERENCES DIM_INDUSTRY(industry_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_fast_observation FOREIGN KEY (observation_period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_fast_open CHECK (opening_rate IS NULL OR opening_rate BETWEEN 0 AND 100),
  CONSTRAINT ck_fast_close CHECK (closure_rate IS NULL OR closure_rate BETWEEN 0 AND 100),
  CONSTRAINT ck_fast_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

