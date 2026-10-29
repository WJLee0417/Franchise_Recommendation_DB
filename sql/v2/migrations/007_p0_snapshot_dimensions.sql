-- Phase 3-5-4: additional SNAPSHOT dimension mart, deliberately outside existing
-- 49-table historical SCD2 model and the SRC/STG quality processing tables.
-- Source-document identity != historic valid time. No EFFECTIVE_START/END fields.
-- Run ONCE against franchise_dw_p0 after 001 and 005 (does not require 006).
USE franchise_dw_p0;

CREATE TABLE SNAP_P0_SOURCE (
  document_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  source_kind ENUM('area','sales','store') NOT NULL,
  source_batch_id VARCHAR(50) NOT NULL,
  source_document_id VARCHAR(200) NOT NULL,
  row_count BIGINT UNSIGNED NOT NULL,
  quality_rule_version VARCHAR(20) NOT NULL,
  snapshot_scope VARCHAR(100) NOT NULL DEFAULT 'ARCHIVED_P0_2022Q1_2023Q2',
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (document_sha256),
  UNIQUE KEY uq_snap_source_batch (source_kind,source_batch_id),
  CONSTRAINT ck_snap_src_sha CHECK (document_sha256 REGEXP '^[0-9a-f]{64}$'),
  CONSTRAINT ck_snap_src_rows CHECK (row_count > 0),
  CONSTRAINT ck_snap_src_document CHECK (source_document_id=CONCAT('sha256:',document_sha256))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE SNAP_P0_PERIOD (
  period_code CHAR(6) NOT NULL,
  original_quarter_code CHAR(5) NOT NULL,
  base_year SMALLINT UNSIGNED NOT NULL,
  quarter_no TINYINT UNSIGNED NOT NULL,
  report_start_date DATE NOT NULL,
  report_end_date DATE NOT NULL,
  date_semantics VARCHAR(80) NOT NULL DEFAULT 'CALENDAR_REPORTING_QUARTER_ONLY',
  PRIMARY KEY (period_code),
  UNIQUE KEY uq_snap_quarter_orig (original_quarter_code),
  CONSTRAINT ck_snap_period_quarter CHECK (quarter_no BETWEEN 1 AND 4),
  CONSTRAINT ck_snap_period_code CHECK (period_code REGEXP '^[0-9]{4}Q[1-4]$'),
  CONSTRAINT ck_snap_period_dates CHECK (report_end_date >= report_start_date),
  CONSTRAINT ck_snap_period_semantics CHECK (date_semantics='CALENDAR_REPORTING_QUARTER_ONLY')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE SNAP_P0_AREA (
  area_snapshot_key BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  area_document_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  source_row_id BIGINT UNSIGNED NOT NULL,
  source_record_path VARCHAR(500) NOT NULL,
  area_code VARCHAR(50) NOT NULL,
  area_name VARCHAR(200) NOT NULL,
  area_type_code VARCHAR(50) NOT NULL,
  area_type_name VARCHAR(100) NOT NULL,
  district_code VARCHAR(50) NOT NULL,
  district_name VARCHAR(100) NOT NULL,
  dong_code VARCHAR(50) NOT NULL,
  dong_name VARCHAR(100) NOT NULL,
  x_coordinate DECIMAL(18,6) NULL,
  y_coordinate DECIMAL(18,6) NULL,
  area_size DECIMAL(24,6) NULL,
  snapshot_record_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  interpretation VARCHAR(100) NOT NULL DEFAULT 'SOURCE_AREA_RECORD_NOT_HISTORIC_BOUNDARY_VERSION',
  PRIMARY KEY (area_snapshot_key),
  UNIQUE KEY uq_snap_area_document_code (area_document_sha256,area_code),
  UNIQUE KEY uq_snap_area_source_row (source_row_id),
  KEY ix_snap_area_code (area_code),
  CONSTRAINT fk_snap_area_document FOREIGN KEY (area_document_sha256)
    REFERENCES SNAP_P0_SOURCE(document_sha256),
  CONSTRAINT fk_snap_area_src_row FOREIGN KEY (source_row_id)
    REFERENCES SRC_SEOUL_AREA(source_row_id),
  CONSTRAINT ck_snap_area_code CHECK (CHAR_LENGTH(TRIM(area_code)) > 0),
  CONSTRAINT ck_snap_area_size CHECK (area_size IS NULL OR area_size >= 0),
  CONSTRAINT ck_snap_area_identity CHECK
    (interpretation='SOURCE_AREA_RECORD_NOT_HISTORIC_BOUNDARY_VERSION')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE SNAP_P0_TAXONOMY (
  taxonomy_snapshot_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  sales_document_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  store_document_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  interpretation VARCHAR(100) NOT NULL DEFAULT 'OBSERVED_SOURCE_CODES_NOT_OFFICIAL_RELEASE',
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (taxonomy_snapshot_sha256),
  UNIQUE KEY uq_snap_tax_docs (sales_document_sha256,store_document_sha256),
  CONSTRAINT fk_snap_tax_sales FOREIGN KEY (sales_document_sha256)
    REFERENCES SNAP_P0_SOURCE(document_sha256),
  CONSTRAINT fk_snap_tax_store FOREIGN KEY (store_document_sha256)
    REFERENCES SNAP_P0_SOURCE(document_sha256),
  CONSTRAINT ck_snap_tax_interpretation CHECK
    (interpretation='OBSERVED_SOURCE_CODES_NOT_OFFICIAL_RELEASE')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE SNAP_P0_INDUSTRY (
  taxonomy_snapshot_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  industry_code VARCHAR(50) NOT NULL,
  industry_name VARCHAR(200) NOT NULL,
  observation_semantics VARCHAR(80) NOT NULL DEFAULT 'CODE_LABEL_FROM_ARCHIVED_SOURCE_ONLY',
  PRIMARY KEY (taxonomy_snapshot_sha256,industry_code),
  CONSTRAINT fk_snap_ind_tax FOREIGN KEY (taxonomy_snapshot_sha256)
    REFERENCES SNAP_P0_TAXONOMY(taxonomy_snapshot_sha256),
  CONSTRAINT ck_snap_ind_code CHECK (CHAR_LENGTH(TRIM(industry_code)) > 0),
  CONSTRAINT ck_snap_ind_name CHECK (CHAR_LENGTH(TRIM(industry_name)) > 0),
  CONSTRAINT ck_snap_ind_meaning CHECK
    (observation_semantics='CODE_LABEL_FROM_ARCHIVED_SOURCE_ONLY')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE SNAP_P0_INDUSTRY_COVERAGE (
  taxonomy_snapshot_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  industry_code VARCHAR(50) NOT NULL,
  document_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  observed_rows BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (taxonomy_snapshot_sha256,industry_code,document_sha256),
  CONSTRAINT fk_snap_cov_ind FOREIGN KEY (taxonomy_snapshot_sha256,industry_code)
    REFERENCES SNAP_P0_INDUSTRY(taxonomy_snapshot_sha256,industry_code),
  CONSTRAINT fk_snap_cov_doc FOREIGN KEY (document_sha256)
    REFERENCES SNAP_P0_SOURCE(document_sha256),
  CONSTRAINT ck_snap_cov_count CHECK (observed_rows > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
