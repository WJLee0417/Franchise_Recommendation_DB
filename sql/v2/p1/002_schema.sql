-- P1 extension (27 tables). Prerequisite: sql/v2/p0/001_schema.sql
-- MySQL 8.0.16+; run only against the separate franchise_dw_p0 schema.
-- Source model: user-provided 상권분석ERD(1).damx, P1 physical fields preserved.
-- Source fields kept as original text. Business keys/periods must be validated by ETL.
-- Running this twice intentionally fails to reveal schema drift.
USE franchise_dw_p0;

-- Raw SRC_SEOUL_FACILITY: retain source text and document lineage; permit incomplete/invalid business cells.
CREATE TABLE SRC_SEOUL_FACILITY (
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
  attracting_facility_count VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_seoulfacility_origin (collection_batch_id, source_document_id, source_record_path),
  KEY ix_seoulfacility_batch (collection_batch_id),
  CONSTRAINT ck_seoulfacility_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id)) > 0),
  CONSTRAINT ck_seoulfacility_doc CHECK (CHAR_LENGTH(TRIM(source_document_id)) > 0),
  CONSTRAINT ck_seoulfacility_path CHECK (CHAR_LENGTH(TRIM(source_record_path)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw SRC_SEOUL_APARTMENT: retain source text and document lineage; permit incomplete/invalid business cells.
CREATE TABLE SRC_SEOUL_APARTMENT (
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
  apartment_complex_count VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_seoulapartment_origin (collection_batch_id, source_document_id, source_record_path),
  KEY ix_seoulapartment_batch (collection_batch_id),
  CONSTRAINT ck_seoulapartment_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id)) > 0),
  CONSTRAINT ck_seoulapartment_doc CHECK (CHAR_LENGTH(TRIM(source_document_id)) > 0),
  CONSTRAINT ck_seoulapartment_path CHECK (CHAR_LENGTH(TRIM(source_record_path)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw SRC_SEOUL_FLOW_POP: retain source text and document lineage; permit incomplete/invalid business cells.
CREATE TABLE SRC_SEOUL_FLOW_POP (
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
  total_flow_population VARCHAR(100) NULL,
  male_flow_population VARCHAR(100) NULL,
  female_flow_population VARCHAR(100) NULL,
  age_10_flow_population VARCHAR(100) NULL,
  age_20_flow_population VARCHAR(100) NULL,
  age_30_flow_population VARCHAR(100) NULL,
  age_40_flow_population VARCHAR(100) NULL,
  age_50_flow_population VARCHAR(100) NULL,
  age_60_flow_population VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_seoulflowpop_origin (collection_batch_id, source_document_id, source_record_path),
  KEY ix_seoulflowpop_batch (collection_batch_id),
  CONSTRAINT ck_seoulflowpop_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id)) > 0),
  CONSTRAINT ck_seoulflowpop_doc CHECK (CHAR_LENGTH(TRIM(source_document_id)) > 0),
  CONSTRAINT ck_seoulflowpop_path CHECK (CHAR_LENGTH(TRIM(source_record_path)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw SRC_SEOUL_RESIDENT_POP: retain source text and document lineage; permit incomplete/invalid business cells.
CREATE TABLE SRC_SEOUL_RESIDENT_POP (
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
  total_resident_population VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_seoulresidentpop_origin (collection_batch_id, source_document_id, source_record_path),
  KEY ix_seoulresidentpop_batch (collection_batch_id),
  CONSTRAINT ck_seoulresidentpop_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id)) > 0),
  CONSTRAINT ck_seoulresidentpop_doc CHECK (CHAR_LENGTH(TRIM(source_document_id)) > 0),
  CONSTRAINT ck_seoulresidentpop_path CHECK (CHAR_LENGTH(TRIM(source_record_path)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw SRC_SEOUL_WORK_POP: retain source text and document lineage; permit incomplete/invalid business cells.
CREATE TABLE SRC_SEOUL_WORK_POP (
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
  total_work_population VARCHAR(100) NULL,
  male_work_population VARCHAR(100) NULL,
  female_work_population VARCHAR(100) NULL,
  age_10_work_population VARCHAR(100) NULL,
  age_20_work_population VARCHAR(100) NULL,
  age_30_work_population VARCHAR(100) NULL,
  age_40_work_population VARCHAR(100) NULL,
  age_50_work_population VARCHAR(100) NULL,
  age_60_work_population VARCHAR(100) NULL,
  male_age_10_work_population VARCHAR(100) NULL,
  male_age_20_work_population VARCHAR(100) NULL,
  male_age_30_work_population VARCHAR(100) NULL,
  male_age_40_work_population VARCHAR(100) NULL,
  male_age_50_work_population VARCHAR(100) NULL,
  male_age_60_work_population VARCHAR(100) NULL,
  female_age_10_work_population VARCHAR(100) NULL,
  female_age_20_work_population VARCHAR(100) NULL,
  female_age_30_work_population VARCHAR(100) NULL,
  female_age_40_work_population VARCHAR(100) NULL,
  female_age_50_work_population VARCHAR(100) NULL,
  female_age_60_work_population VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_seoulworkpop_origin (collection_batch_id, source_document_id, source_record_path),
  KEY ix_seoulworkpop_batch (collection_batch_id),
  CONSTRAINT ck_seoulworkpop_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id)) > 0),
  CONSTRAINT ck_seoulworkpop_doc CHECK (CHAR_LENGTH(TRIM(source_document_id)) > 0),
  CONSTRAINT ck_seoulworkpop_path CHECK (CHAR_LENGTH(TRIM(source_record_path)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw SRC_SEOUL_CONSUMPTION: retain source text and document lineage; permit incomplete/invalid business cells.
CREATE TABLE SRC_SEOUL_CONSUMPTION (
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
  total_expenditure_amount VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_seoulconsumption_origin (collection_batch_id, source_document_id, source_record_path),
  KEY ix_seoulconsumption_batch (collection_batch_id),
  CONSTRAINT ck_seoulconsumption_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id)) > 0),
  CONSTRAINT ck_seoulconsumption_doc CHECK (CHAR_LENGTH(TRIM(source_document_id)) > 0),
  CONSTRAINT ck_seoulconsumption_path CHECK (CHAR_LENGTH(TRIM(source_record_path)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw SRC_SEOUL_INCOME_ARCHIVE: retain source text and document lineage; permit incomplete/invalid business cells.
CREATE TABLE SRC_SEOUL_INCOME_ARCHIVE (
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
  monthly_average_income VARCHAR(100) NULL,
  income_bracket_code VARCHAR(50) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_seoulincomearchive_origin (collection_batch_id, source_document_id, source_record_path),
  KEY ix_seoulincomearchive_batch (collection_batch_id),
  CONSTRAINT ck_seoulincomearchive_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id)) > 0),
  CONSTRAINT ck_seoulincomearchive_doc CHECK (CHAR_LENGTH(TRIM(source_document_id)) > 0),
  CONSTRAINT ck_seoulincomearchive_path CHECK (CHAR_LENGTH(TRIM(source_record_path)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw SRC_FTC_DISCLOSURE: retain source text and document lineage; permit incomplete/invalid business cells.
CREATE TABLE SRC_FTC_DISCLOSURE (
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
  company_name VARCHAR(200) NULL,
  brand_name VARCHAR(200) NULL,
  source_industry_code VARCHAR(50) NULL,
  source_industry_name VARCHAR(200) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_ftcdisclosure_origin (collection_batch_id, source_document_id, source_record_path),
  KEY ix_ftcdisclosure_batch (collection_batch_id),
  CONSTRAINT ck_ftcdisclosure_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id)) > 0),
  CONSTRAINT ck_ftcdisclosure_doc CHECK (CHAR_LENGTH(TRIM(source_document_id)) > 0),
  CONSTRAINT ck_ftcdisclosure_path CHECK (CHAR_LENGTH(TRIM(source_record_path)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw SRC_FTC_FINANCE: retain source text and document lineage; permit incomplete/invalid business cells.
CREATE TABLE SRC_FTC_FINANCE (
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
  business_year VARCHAR(20) NULL,
  assets VARCHAR(100) NULL,
  liabilities VARCHAR(100) NULL,
  capital VARCHAR(100) NULL,
  revenue VARCHAR(100) NULL,
  operating_income VARCHAR(100) NULL,
  net_income VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_ftcfinance_origin (collection_batch_id, source_document_id, source_record_path),
  KEY ix_ftcfinance_batch (collection_batch_id),
  CONSTRAINT ck_ftcfinance_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id)) > 0),
  CONSTRAINT ck_ftcfinance_doc CHECK (CHAR_LENGTH(TRIM(source_document_id)) > 0),
  CONSTRAINT ck_ftcfinance_path CHECK (CHAR_LENGTH(TRIM(source_record_path)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw SRC_FTC_STORE: retain source text and document lineage; permit incomplete/invalid business cells.
CREATE TABLE SRC_FTC_STORE (
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
  business_year VARCHAR(20) NULL,
  source_region_name VARCHAR(100) NULL,
  franchise_store_count VARCHAR(100) NULL,
  direct_store_count VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_ftcstore_origin (collection_batch_id, source_document_id, source_record_path),
  KEY ix_ftcstore_batch (collection_batch_id),
  CONSTRAINT ck_ftcstore_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id)) > 0),
  CONSTRAINT ck_ftcstore_doc CHECK (CHAR_LENGTH(TRIM(source_document_id)) > 0),
  CONSTRAINT ck_ftcstore_path CHECK (CHAR_LENGTH(TRIM(source_record_path)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw SRC_FTC_STORE_CHANGE: retain source text and document lineage; permit incomplete/invalid business cells.
CREATE TABLE SRC_FTC_STORE_CHANGE (
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
  business_year VARCHAR(20) NULL,
  new_store_count VARCHAR(100) NULL,
  contract_expired_count VARCHAR(100) NULL,
  contract_terminated_count VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_ftcstorechange_origin (collection_batch_id, source_document_id, source_record_path),
  KEY ix_ftcstorechange_batch (collection_batch_id),
  CONSTRAINT ck_ftcstorechange_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id)) > 0),
  CONSTRAINT ck_ftcstorechange_doc CHECK (CHAR_LENGTH(TRIM(source_document_id)) > 0),
  CONSTRAINT ck_ftcstorechange_path CHECK (CHAR_LENGTH(TRIM(source_record_path)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Raw SRC_FTC_AVG_SALES: retain source text and document lineage; permit incomplete/invalid business cells.
CREATE TABLE SRC_FTC_AVG_SALES (
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
  source_region_name VARCHAR(100) NULL,
  average_sales_amount VARCHAR(100) NULL,
  sales_amount_per_area VARCHAR(100) NULL,
  PRIMARY KEY (source_row_id),
  UNIQUE KEY uq_ftcavgsales_origin (collection_batch_id, source_document_id, source_record_path),
  KEY ix_ftcavgsales_batch (collection_batch_id),
  CONSTRAINT ck_ftcavgsales_batch CHECK (CHAR_LENGTH(TRIM(collection_batch_id)) > 0),
  CONSTRAINT ck_ftcavgsales_doc CHECK (CHAR_LENGTH(TRIM(source_document_id)) > 0),
  CONSTRAINT ck_ftcavgsales_path CHECK (CHAR_LENGTH(TRIM(source_record_path)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Headquarter type-2 dimension: one current version per business key maximum.
CREATE TABLE DIM_HEADQUARTER (
  headquarter_key BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  headquarter_management_no VARCHAR(50) NOT NULL,
  version_no INT NOT NULL,
  company_name VARCHAR(200) NOT NULL,
  effective_start_date DATE NOT NULL,
  effective_end_date DATE NULL,
  is_current CHAR(1) NOT NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  current_headquarter_no VARCHAR(50) GENERATED ALWAYS AS (CASE WHEN is_current='Y' THEN headquarter_management_no ELSE NULL END) STORED,
  PRIMARY KEY (headquarter_key),
  UNIQUE KEY uq_dhq_version (headquarter_management_no, version_no),
  UNIQUE KEY uq_dhq_current (current_headquarter_no),
  KEY ix_dhq_eff (headquarter_management_no, effective_start_date, effective_end_date),
  CONSTRAINT ck_dhq_ver CHECK (version_no>0),
  CONSTRAINT ck_dhq_dates CHECK (effective_end_date IS NULL OR effective_end_date>effective_start_date),
  CONSTRAINT ck_dhq_current CHECK ((is_current='Y' AND effective_end_date IS NULL) OR (is_current='N' AND effective_end_date IS NOT NULL)),
  CONSTRAINT ck_dhq_code CHECK (CHAR_LENGTH(TRIM(headquarter_management_no))>0),
  CONSTRAINT ck_dhq_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Franchise brand type-2; nullable industry_key means FTC→Seoul classification mapping remains UNVERIFIED.
CREATE TABLE DIM_FRANCHISE (
  franchise_key BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  brand_management_no VARCHAR(50) NOT NULL,
  version_no INT NOT NULL,
  brand_name VARCHAR(200) NOT NULL,
  headquarter_key BIGINT UNSIGNED NOT NULL,
  industry_key BIGINT UNSIGNED NULL,
  effective_start_date DATE NOT NULL,
  effective_end_date DATE NULL,
  is_current CHAR(1) NOT NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  current_brand_no VARCHAR(50) GENERATED ALWAYS AS (CASE WHEN is_current='Y' THEN brand_management_no ELSE NULL END) STORED,
  PRIMARY KEY (franchise_key),
  UNIQUE KEY uq_df_version (brand_management_no, version_no),
  UNIQUE KEY uq_df_current (current_brand_no),
  KEY ix_df_hq (headquarter_key),
  KEY ix_df_industry (industry_key),
  KEY ix_df_eff (brand_management_no, effective_start_date, effective_end_date),
  CONSTRAINT fk_df_hq FOREIGN KEY (headquarter_key) REFERENCES DIM_HEADQUARTER(headquarter_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_df_industry FOREIGN KEY (industry_key) REFERENCES DIM_INDUSTRY(industry_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_df_ver CHECK (version_no>0),
  CONSTRAINT ck_df_dates CHECK (effective_end_date IS NULL OR effective_end_date>effective_start_date),
  CONSTRAINT ck_df_current CHECK ((is_current='Y' AND effective_end_date IS NULL) OR (is_current='N' AND effective_end_date IS NOT NULL)),
  CONSTRAINT ck_df_code CHECK (CHAR_LENGTH(TRIM(brand_management_no))>0),
  CONSTRAINT ck_df_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Region code system explicit; never merge FTC region name with Seoul district by name.
CREATE TABLE DIM_REGION (
  region_key BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  region_system_code VARCHAR(50) NOT NULL,
  region_code VARCHAR(50) NOT NULL,
  region_name VARCHAR(100) NOT NULL,
  region_level_code VARCHAR(20) NOT NULL,
  region_version VARCHAR(100) NOT NULL,
  effective_start_date DATE NOT NULL,
  effective_end_date DATE NULL,
  is_current CHAR(1) NOT NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  current_system VARCHAR(50) GENERATED ALWAYS AS (CASE WHEN is_current='Y' THEN region_system_code ELSE NULL END) STORED,
  current_region VARCHAR(50) GENERATED ALWAYS AS (CASE WHEN is_current='Y' THEN region_code ELSE NULL END) STORED,
  PRIMARY KEY (region_key),
  UNIQUE KEY uq_dr_version (region_system_code, region_code, region_version),
  UNIQUE KEY uq_dr_current (current_system, current_region),
  KEY ix_dr_eff (region_system_code, region_code, effective_start_date, effective_end_date),
  CONSTRAINT ck_dr_dates CHECK (effective_end_date IS NULL OR effective_end_date>effective_start_date),
  CONSTRAINT ck_dr_current CHECK ((is_current='Y' AND effective_end_date IS NULL) OR (is_current='N' AND effective_end_date IS NOT NULL)),
  CONSTRAINT ck_dr_system CHECK (CHAR_LENGTH(TRIM(region_system_code))>0),
  CONSTRAINT ck_dr_code CHECK (CHAR_LENGTH(TRIM(region_code))>0),
  CONSTRAINT ck_dr_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Disclosure version requires verified disclosure number and version; no synthetic publication dates.
CREATE TABLE DIM_DISCLOSURE_VERSION (
  disclosure_version_key BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  disclosure_no VARCHAR(50) NOT NULL,
  disclosure_version_code VARCHAR(100) NOT NULL,
  franchise_key BIGINT UNSIGNED NOT NULL,
  publication_date DATE NULL,
  condition_start_date DATE NULL,
  condition_end_date DATE NULL,
  initial_contract_period DECIMAL(12,4) NULL,
  initial_contract_unit_code VARCHAR(20) NULL,
  renewal_contract_period DECIMAL(12,4) NULL,
  renewal_contract_unit_code VARCHAR(20) NULL,
  content_hash CHAR(64) NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (disclosure_version_key),
  UNIQUE KEY uq_ddv_version (disclosure_no, disclosure_version_code),
  KEY ix_ddv_franchise (franchise_key),
  CONSTRAINT fk_ddv_franchise FOREIGN KEY (franchise_key) REFERENCES DIM_FRANCHISE(franchise_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_ddv_dates CHECK (condition_end_date IS NULL OR (condition_start_date IS NOT NULL AND condition_end_date>condition_start_date)),
  CONSTRAINT ck_ddv_init CHECK (initial_contract_period IS NULL OR initial_contract_period>=0),
  CONSTRAINT ck_ddv_renew CHECK (renewal_contract_period IS NULL OR renewal_contract_period>=0),
  CONSTRAINT ck_ddv_init_unit CHECK ((initial_contract_period IS NULL AND initial_contract_unit_code IS NULL) OR (initial_contract_period IS NOT NULL AND initial_contract_unit_code IS NOT NULL)),
  CONSTRAINT ck_ddv_renew_unit CHECK ((renewal_contract_period IS NULL AND renewal_contract_unit_code IS NULL) OR (renewal_contract_period IS NOT NULL AND renewal_contract_unit_code IS NOT NULL)),
  CONSTRAINT ck_ddv_no CHECK (CHAR_LENGTH(TRIM(disclosure_no))>0),
  CONSTRAINT ck_ddv_vcode CHECK (CHAR_LENGTH(TRIM(disclosure_version_code))>0),
  CONSTRAINT ck_ddv_hash CHECK (content_hash IS NULL OR (CHAR_LENGTH(content_hash)=64 AND content_hash REGEXP '^[0-9A-Fa-f]{64}$')),
  CONSTRAINT ck_ddv_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Area statistics. Grain: reporting period x area version x observation period.
CREATE TABLE FACT_AREA_FACILITY (
  period_key BIGINT UNSIGNED NOT NULL,
  area_key BIGINT UNSIGNED NOT NULL,
  observation_period_key BIGINT UNSIGNED NOT NULL,
  attracting_facility_count BIGINT UNSIGNED NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (period_key, area_key, observation_period_key),
  KEY ix_faf_area (area_key),
  KEY ix_faf_obs (observation_period_key),
  CONSTRAINT fk_faf_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_faf_area FOREIGN KEY (area_key) REFERENCES DIM_AREA(area_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_faf_obs FOREIGN KEY (observation_period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_faf_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Area statistics. Grain: reporting period x area version x observation period.
CREATE TABLE FACT_AREA_APARTMENT (
  period_key BIGINT UNSIGNED NOT NULL,
  area_key BIGINT UNSIGNED NOT NULL,
  observation_period_key BIGINT UNSIGNED NOT NULL,
  apartment_complex_count BIGINT UNSIGNED NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (period_key, area_key, observation_period_key),
  KEY ix_faa_area (area_key),
  KEY ix_faa_obs (observation_period_key),
  CONSTRAINT fk_faa_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_faa_area FOREIGN KEY (area_key) REFERENCES DIM_AREA(area_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_faa_obs FOREIGN KEY (observation_period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_faa_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Area statistics. Grain: reporting period x area version x observation period.
CREATE TABLE FACT_AREA_RESIDENT_POP (
  period_key BIGINT UNSIGNED NOT NULL,
  area_key BIGINT UNSIGNED NOT NULL,
  observation_period_key BIGINT UNSIGNED NOT NULL,
  total_resident_population BIGINT UNSIGNED NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (period_key, area_key, observation_period_key),
  KEY ix_farp_area (area_key),
  KEY ix_farp_obs (observation_period_key),
  CONSTRAINT fk_farp_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_farp_area FOREIGN KEY (area_key) REFERENCES DIM_AREA(area_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_farp_obs FOREIGN KEY (observation_period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_farp_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Area statistics. Grain: reporting period x area version x observation period.
CREATE TABLE FACT_AREA_FLOW_POP (
  period_key BIGINT UNSIGNED NOT NULL,
  area_key BIGINT UNSIGNED NOT NULL,
  observation_period_key BIGINT UNSIGNED NOT NULL,
  total_flow_population DECIMAL(24,4) NULL,
  male_flow_population DECIMAL(24,4) NULL,
  female_flow_population DECIMAL(24,4) NULL,
  age_10_flow_population DECIMAL(24,4) NULL,
  age_20_flow_population DECIMAL(24,4) NULL,
  age_30_flow_population DECIMAL(24,4) NULL,
  age_40_flow_population DECIMAL(24,4) NULL,
  age_50_flow_population DECIMAL(24,4) NULL,
  age_60_flow_population DECIMAL(24,4) NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (period_key, area_key, observation_period_key),
  KEY ix_fafp_area (area_key),
  KEY ix_fafp_obs (observation_period_key),
  CONSTRAINT fk_fafp_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_fafp_area FOREIGN KEY (area_key) REFERENCES DIM_AREA(area_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_fafp_obs FOREIGN KEY (observation_period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_fafp_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0),
  CONSTRAINT ck_fafp_total_flow_population CHECK (total_flow_population IS NULL OR total_flow_population>=0),
  CONSTRAINT ck_fafp_male_flow_population CHECK (male_flow_population IS NULL OR male_flow_population>=0),
  CONSTRAINT ck_fafp_female_flow_population CHECK (female_flow_population IS NULL OR female_flow_population>=0),
  CONSTRAINT ck_fafp_age_10_flow_population CHECK (age_10_flow_population IS NULL OR age_10_flow_population>=0),
  CONSTRAINT ck_fafp_age_20_flow_population CHECK (age_20_flow_population IS NULL OR age_20_flow_population>=0),
  CONSTRAINT ck_fafp_age_30_flow_population CHECK (age_30_flow_population IS NULL OR age_30_flow_population>=0),
  CONSTRAINT ck_fafp_age_40_flow_population CHECK (age_40_flow_population IS NULL OR age_40_flow_population>=0),
  CONSTRAINT ck_fafp_age_50_flow_population CHECK (age_50_flow_population IS NULL OR age_50_flow_population>=0),
  CONSTRAINT ck_fafp_age_60_flow_population CHECK (age_60_flow_population IS NULL OR age_60_flow_population>=0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Area statistics. Grain: reporting period x area version x observation period.
CREATE TABLE FACT_AREA_WORK_POP (
  period_key BIGINT UNSIGNED NOT NULL,
  area_key BIGINT UNSIGNED NOT NULL,
  observation_period_key BIGINT UNSIGNED NOT NULL,
  total_work_population BIGINT UNSIGNED NULL,
  male_work_population BIGINT UNSIGNED NULL,
  female_work_population BIGINT UNSIGNED NULL,
  age_10_work_population BIGINT UNSIGNED NULL,
  age_20_work_population BIGINT UNSIGNED NULL,
  age_30_work_population BIGINT UNSIGNED NULL,
  age_40_work_population BIGINT UNSIGNED NULL,
  age_50_work_population BIGINT UNSIGNED NULL,
  age_60_work_population BIGINT UNSIGNED NULL,
  male_age_10_work_population BIGINT UNSIGNED NULL,
  male_age_20_work_population BIGINT UNSIGNED NULL,
  male_age_30_work_population BIGINT UNSIGNED NULL,
  male_age_40_work_population BIGINT UNSIGNED NULL,
  male_age_50_work_population BIGINT UNSIGNED NULL,
  male_age_60_work_population BIGINT UNSIGNED NULL,
  female_age_10_work_population BIGINT UNSIGNED NULL,
  female_age_20_work_population BIGINT UNSIGNED NULL,
  female_age_30_work_population BIGINT UNSIGNED NULL,
  female_age_40_work_population BIGINT UNSIGNED NULL,
  female_age_50_work_population BIGINT UNSIGNED NULL,
  female_age_60_work_population BIGINT UNSIGNED NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (period_key, area_key, observation_period_key),
  KEY ix_fawp_area (area_key),
  KEY ix_fawp_obs (observation_period_key),
  CONSTRAINT fk_fawp_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_fawp_area FOREIGN KEY (area_key) REFERENCES DIM_AREA(area_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_fawp_obs FOREIGN KEY (observation_period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_fawp_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Area statistics. Grain: reporting period x area version.
CREATE TABLE FACT_AREA_INCOME (
  period_key BIGINT UNSIGNED NOT NULL,
  area_key BIGINT UNSIGNED NOT NULL,
  monthly_average_income DECIMAL(24,2) NULL,
  income_bracket_code VARCHAR(50) NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (period_key, area_key),
  KEY ix_fai_area (area_key),
  CONSTRAINT fk_fai_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_fai_area FOREIGN KEY (area_key) REFERENCES DIM_AREA(area_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_fai_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0),
  CONSTRAINT ck_fai_monthly_average_income CHECK (monthly_average_income IS NULL OR monthly_average_income>=0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Area statistics. Grain: reporting period x area version.
CREATE TABLE FACT_AREA_CONSUMPTION (
  period_key BIGINT UNSIGNED NOT NULL,
  area_key BIGINT UNSIGNED NOT NULL,
  total_expenditure_amount DECIMAL(24,2) NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (period_key, area_key),
  KEY ix_fac_area (area_key),
  CONSTRAINT fk_fac_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_fac_area FOREIGN KEY (area_key) REFERENCES DIM_AREA(area_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_fac_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0),
  CONSTRAINT ck_fac_total_expenditure_amount CHECK (total_expenditure_amount IS NULL OR total_expenditure_amount>=0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- FTC analytical grain: franchise_key x period_key x region_key. Negative equity/profit is permitted where financially meaningful.
CREATE TABLE FACT_FRANCHISE_STORE (
  franchise_key BIGINT UNSIGNED NOT NULL,
  period_key BIGINT UNSIGNED NOT NULL,
  region_key BIGINT UNSIGNED NOT NULL,
  franchise_store_count BIGINT UNSIGNED NULL,
  direct_store_count BIGINT UNSIGNED NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (franchise_key, period_key, region_key),
  KEY ix_ffs_period (period_key),
  CONSTRAINT fk_ffs_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_ffs_franchise FOREIGN KEY (franchise_key) REFERENCES DIM_FRANCHISE(franchise_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  ,
  KEY ix_ffs_region (region_key),
  CONSTRAINT fk_ffs_region FOREIGN KEY (region_key) REFERENCES DIM_REGION(region_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_ffs_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- FTC analytical grain: franchise_key x period_key. Negative equity/profit is permitted where financially meaningful.
CREATE TABLE FACT_FRANCHISE_CHANGE (
  franchise_key BIGINT UNSIGNED NOT NULL,
  period_key BIGINT UNSIGNED NOT NULL,
  new_store_count BIGINT UNSIGNED NULL,
  contract_expired_count BIGINT UNSIGNED NULL,
  contract_terminated_count BIGINT UNSIGNED NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (franchise_key, period_key),
  KEY ix_ffc_period (period_key),
  CONSTRAINT fk_ffc_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_ffc_franchise FOREIGN KEY (franchise_key) REFERENCES DIM_FRANCHISE(franchise_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  ,
  ,
  CONSTRAINT ck_ffc_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- FTC analytical grain: franchise_key x period_key x region_key. Negative equity/profit is permitted where financially meaningful.
CREATE TABLE FACT_FRANCHISE_AVG_SALES (
  franchise_key BIGINT UNSIGNED NOT NULL,
  period_key BIGINT UNSIGNED NOT NULL,
  region_key BIGINT UNSIGNED NOT NULL,
  average_sales_amount DECIMAL(24,2) NULL,
  sales_amount_per_area DECIMAL(24,6) NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (franchise_key, period_key, region_key),
  KEY ix_ffas_period (period_key),
  CONSTRAINT fk_ffas_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_ffas_franchise FOREIGN KEY (franchise_key) REFERENCES DIM_FRANCHISE(franchise_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  ,
  KEY ix_ffas_region (region_key),
  CONSTRAINT fk_ffas_region FOREIGN KEY (region_key) REFERENCES DIM_REGION(region_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_ffas_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0),
  CONSTRAINT ck_ffas_avg CHECK (average_sales_amount IS NULL OR average_sales_amount>=0),
  CONSTRAINT ck_ffas_area CHECK (sales_amount_per_area IS NULL OR sales_amount_per_area>=0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- FTC analytical grain: headquarter_key x period_key x accounting_scope_code. Negative equity/profit is permitted where financially meaningful.
CREATE TABLE FACT_HQ_FINANCE (
  headquarter_key BIGINT UNSIGNED NOT NULL,
  period_key BIGINT UNSIGNED NOT NULL,
  accounting_scope_code VARCHAR(30) NOT NULL,
  assets DECIMAL(24,2) NULL,
  liabilities DECIMAL(24,2) NULL,
  capital DECIMAL(24,2) NULL,
  revenue DECIMAL(24,2) NULL,
  operating_income DECIMAL(24,2) NULL,
  net_income DECIMAL(24,2) NULL,
  lineage_group_id VARCHAR(50) NOT NULL,
  loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (headquarter_key, period_key, accounting_scope_code),
  KEY ix_fhf_period (period_key),
  CONSTRAINT fk_fhf_period FOREIGN KEY (period_key) REFERENCES DIM_PERIOD(period_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  ,
  CONSTRAINT fk_fhf_hq FOREIGN KEY (headquarter_key) REFERENCES DIM_HEADQUARTER(headquarter_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  ,
  CONSTRAINT ck_fhf_lineage CHECK (CHAR_LENGTH(TRIM(lineage_group_id))>0),
  CONSTRAINT ck_fhf_scope CHECK (CHAR_LENGTH(TRIM(accounting_scope_code))>0),
  CONSTRAINT ck_fhf_assets CHECK (assets IS NULL OR assets>=0),
  CONSTRAINT ck_fhf_liabilities CHECK (liabilities IS NULL OR liabilities>=0),
  CONSTRAINT ck_fhf_revenue CHECK (revenue IS NULL OR revenue>=0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

