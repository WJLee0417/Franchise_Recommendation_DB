-- Phase 2-3: P2 expansion (SRC 6 + FACT 5 = 11 new tables).
-- Precondition: sql/v2/p0/001_schema.sql -> sql/v2/p1/002_schema.sql.
-- MySQL 8.0.16+ required to enforce CHECK constraints.
-- Source: 상권분석ERD(1).damx (SHA256 0fd22beb5239b071b39035deb3adb1485cc4261a07283927d3bca75f4d3de1b0).
-- Root P0/P1 schemas and original franchise_demo remain unchanged.
-- Not idempotent: running twice fails deliberately, rather than silently masking drift.
USE franchise_dw_p0;

-- Raw FTC SRC_FTC_CONTRACT: do not coerce unknown, withheld or malformed numbers to zero. Raw version is source data.
CREATE TABLE SRC_FTC_CONTRACT (
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
  disclosure_no VARCHAR(50) NULL,
  initial_contract_period VARCHAR(100) NULL,
  renewal_contract_period VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_ftccon_origin (collection_batch_id,source_document_id,source_record_path),
  KEY ix_ftccon_batch (collection_batch_id),
  CONSTRAINT ck_ftccon_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id))>0),
  CONSTRAINT ck_ftccon_doc CHECK (CHAR_LENGTH(TRIM(source_document_id))>0),
  CONSTRAINT ck_ftccon_path CHECK (CHAR_LENGTH(TRIM(source_record_path))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw FTC SRC_FTC_STARTUP_COST: do not coerce unknown, withheld or malformed numbers to zero. Raw version is source data.
CREATE TABLE SRC_FTC_STARTUP_COST (
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
  disclosure_no VARCHAR(50) NULL,
  joining_fee VARCHAR(100) NULL,
  training_fee VARCHAR(100) NULL,
  security_deposit VARCHAR(100) NULL,
  other_cost VARCHAR(100) NULL,
  escrow_franchise_fee VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_ftcsc_origin (collection_batch_id,source_document_id,source_record_path),
  KEY ix_ftcsc_batch (collection_batch_id),
  CONSTRAINT ck_ftcsc_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id))>0),
  CONSTRAINT ck_ftcsc_doc CHECK (CHAR_LENGTH(TRIM(source_document_id))>0),
  CONSTRAINT ck_ftcsc_path CHECK (CHAR_LENGTH(TRIM(source_record_path))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw FTC SRC_FTC_INTERIOR: do not coerce unknown, withheld or malformed numbers to zero. Raw version is source data.
CREATE TABLE SRC_FTC_INTERIOR (
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
  disclosure_no VARCHAR(50) NULL,
  standard_store_area VARCHAR(100) NULL,
  interior_cost_per_area VARCHAR(100) NULL,
  interior_total_cost VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_ftcint_origin (collection_batch_id,source_document_id,source_record_path),
  KEY ix_ftcint_batch (collection_batch_id),
  CONSTRAINT ck_ftcint_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id))>0),
  CONSTRAINT ck_ftcint_doc CHECK (CHAR_LENGTH(TRIM(source_document_id))>0),
  CONSTRAINT ck_ftcint_path CHECK (CHAR_LENGTH(TRIM(source_record_path))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw FTC SRC_FTC_AD_PROMOTION: do not coerce unknown, withheld or malformed numbers to zero. Raw version is source data.
CREATE TABLE SRC_FTC_AD_PROMOTION (
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
  disclosure_no VARCHAR(50) NULL,
  base_year VARCHAR(20) NULL,
  advertising_amount VARCHAR(100) NULL,
  promotion_amount VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_ftcad_origin (collection_batch_id,source_document_id,source_record_path),
  KEY ix_ftcad_batch (collection_batch_id),
  CONSTRAINT ck_ftcad_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id))>0),
  CONSTRAINT ck_ftcad_doc CHECK (CHAR_LENGTH(TRIM(source_document_id))>0),
  CONSTRAINT ck_ftcad_path CHECK (CHAR_LENGTH(TRIM(source_record_path))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw FTC SRC_FTC_EMPLOYEE: do not coerce unknown, withheld or malformed numbers to zero. Raw version is source data.
CREATE TABLE SRC_FTC_EMPLOYEE (
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
  disclosure_no VARCHAR(50) NULL,
  base_year VARCHAR(20) NULL,
  executive_count VARCHAR(100) NULL,
  employee_count VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_ftcemp_origin (collection_batch_id,source_document_id,source_record_path),
  KEY ix_ftcemp_batch (collection_batch_id),
  CONSTRAINT ck_ftcemp_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id))>0),
  CONSTRAINT ck_ftcemp_doc CHECK (CHAR_LENGTH(TRIM(source_document_id))>0),
  CONSTRAINT ck_ftcemp_path CHECK (CHAR_LENGTH(TRIM(source_record_path))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw FTC SRC_FTC_LEGAL: do not coerce unknown, withheld or malformed numbers to zero. Raw version is source data.
CREATE TABLE SRC_FTC_LEGAL (
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
  disclosure_no VARCHAR(50) NULL,
  corrective_action_count VARCHAR(100) NULL,
  civil_case_count VARCHAR(100) NULL,
  criminal_sentence_count VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_ftcleg_origin (collection_batch_id,source_document_id,source_record_path),
  KEY ix_ftcleg_batch (collection_batch_id),
  CONSTRAINT ck_ftcleg_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id))>0),
  CONSTRAINT ck_ftcleg_doc CHECK (CHAR_LENGTH(TRIM(source_document_id))>0),
  CONSTRAINT ck_ftcleg_path CHECK (CHAR_LENGTH(TRIM(source_record_path))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- A disclosure version must belong to the same brand as its P2 fees / interior facts.
-- A separate composite UNIQUE is required as the target of a composite FK.
-- This additive index is safe after P1 if its PK/FK structure remains unchanged.
ALTER TABLE DIM_DISCLOSURE_VERSION
  ADD UNIQUE KEY uq_ddv_version_franchise (disclosure_version_key,franchise_key);

-- Grain: published disclosure version × its brand; cost is NULL if unknown, never automatically zero.
CREATE TABLE FACT_FRANCHISE_STARTUP_COST (
  disclosure_version_key BIGINT UNSIGNED NOT NULL,
  franchise_key BIGINT UNSIGNED NOT NULL,
  joining_fee DECIMAL(24,2) NULL,
  training_fee DECIMAL(24,2) NULL,
  security_deposit DECIMAL(24,2) NULL,
  other_cost DECIMAL(24,2) NULL,
  escrow_franchise_fee DECIMAL(24,2) NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (disclosure_version_key,franchise_key),
  KEY ix_ffsc_franchise (franchise_key),
  CONSTRAINT fk_ffsc_version_brand FOREIGN KEY (disclosure_version_key,franchise_key),
  REFERENCES DIM_DISCLOSURE_VERSION(disclosure_version_key,franchise_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_ffsc_join CHECK (joining_fee IS NULL OR joining_fee>=0),
  CONSTRAINT ck_ffsc_train CHECK (training_fee IS NULL OR training_fee>=0),
  CONSTRAINT ck_ffsc_deposit CHECK (security_deposit IS NULL OR security_deposit>=0),
  CONSTRAINT ck_ffsc_other CHECK (other_cost IS NULL OR other_cost>=0),
  CONSTRAINT ck_ffsc_escrow CHECK (escrow_franchise_fee IS NULL OR escrow_franchise_fee>=0),
  CONSTRAINT ck_ffsc_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Grain: disclosure version × explicit store specification × its brand; no made-up specification codes from source.
CREATE TABLE FACT_FRANCHISE_INTERIOR (
  disclosure_version_key BIGINT UNSIGNED NOT NULL,
  specification_code VARCHAR(100) NOT NULL,
  franchise_key BIGINT UNSIGNED NOT NULL,
  standard_store_area DECIMAL(18,4) NULL,
  interior_cost_per_area DECIMAL(24,2) NULL,
  interior_total_cost DECIMAL(24,2) NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (disclosure_version_key,specification_code,franchise_key),
  KEY ix_ffi_franchise (franchise_key),
  CONSTRAINT fk_ffi_version_brand FOREIGN KEY (disclosure_version_key,franchise_key),
  REFERENCES DIM_DISCLOSURE_VERSION(disclosure_version_key,franchise_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_ffi_spec CHECK (CHAR_LENGTH(TRIM(specification_code))>0),
  CONSTRAINT ck_ffi_area CHECK (standard_store_area IS NULL OR standard_store_area>0),
  CONSTRAINT ck_ffi_per_area CHECK (interior_cost_per_area IS NULL OR interior_cost_per_area>=0),
  CONSTRAINT ck_ffi_total CHECK (interior_total_cost IS NULL OR interior_total_cost>=0),
  CONSTRAINT ck_ffi_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Grain: headquarters version × reporting period; nonnegative advertising and promotional spending.
CREATE TABLE FACT_AD_PROMOTION (
  headquarter_key BIGINT UNSIGNED NOT NULL,
  period_key BIGINT UNSIGNED NOT NULL,
  advertising_amount DECIMAL(24,2) NULL,
  promotion_amount DECIMAL(24,2) NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (headquarter_key,period_key),
  KEY ix_fad_period (period_key),
  CONSTRAINT fk_fad_hq FOREIGN KEY (headquarter_key) REFERENCES DIM_HEADQUARTER(headquarter_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_fad_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_fad_adv CHECK (advertising_amount IS NULL OR advertising_amount>=0),
  CONSTRAINT ck_fad_promo CHECK (promotion_amount IS NULL OR promotion_amount>=0),
  CONSTRAINT ck_fad_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Grain: headquarters version × reporting period; executive/employee headcount may be unpublished.
CREATE TABLE FACT_HQ_EMPLOYEE (
  headquarter_key BIGINT UNSIGNED NOT NULL,
  period_key BIGINT UNSIGNED NOT NULL,
  executive_count BIGINT UNSIGNED NULL,
  employee_count BIGINT UNSIGNED NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (headquarter_key,period_key),
  KEY ix_fhe_period (period_key),
  CONSTRAINT fk_fhe_hq FOREIGN KEY (headquarter_key) REFERENCES DIM_HEADQUARTER(headquarter_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_fhe_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_fhe_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Grain: headquarters version × reported period; legal count definitions and true observation years require external validation.
CREATE TABLE FACT_HQ_LEGAL (
  headquarter_key BIGINT UNSIGNED NOT NULL,
  period_key BIGINT UNSIGNED NOT NULL,
  corrective_action_count BIGINT UNSIGNED NULL,
  civil_case_count BIGINT UNSIGNED NULL,
  criminal_sentence_count BIGINT UNSIGNED NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (headquarter_key,period_key),
  KEY ix_fhl_period (period_key),
  CONSTRAINT fk_fhl_hq FOREIGN KEY (headquarter_key) REFERENCES DIM_HEADQUARTER(headquarter_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_fhl_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_fhl_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

