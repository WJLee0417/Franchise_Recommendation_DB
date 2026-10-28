-- Phase 3-4-2: operational quality/staging tables, OUTSIDE the original 49-table ERD.
-- P0 SRC (three tables) must already exist. No DIM/FACT rows are written.
-- Run this migration once; deliberate failure on duplicate objects exposes drift.
USE franchise_dw_p0;

CREATE TABLE DQ_P0_RUN (
  run_id CHAR(36) NOT NULL,
  source_kind ENUM('area','sales','store') NOT NULL,
  source_batch_id VARCHAR(50) NOT NULL,
  policy_version VARCHAR(20) NOT NULL,
  status ENUM('RUNNING','SUCCEEDED','FAILED') NOT NULL,
  processed_rows BIGINT UNSIGNED NOT NULL DEFAULT 0,
  accept_rows BIGINT UNSIGNED NOT NULL DEFAULT 0,
  warn_rows BIGINT UNSIGNED NOT NULL DEFAULT 0,
  review_rows BIGINT UNSIGNED NOT NULL DEFAULT 0,
  reject_rows BIGINT UNSIGNED NOT NULL DEFAULT 0,
  started_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  finished_at DATETIME(6) NULL,
  error_category VARCHAR(100) NULL,
  PRIMARY KEY (run_id),
  KEY ix_dq_run_batch (source_kind, source_batch_id, started_at),
  CONSTRAINT ck_dq_run_counts CHECK
    (processed_rows = accept_rows + warn_rows + review_rows + reject_rows)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE STG_P0_QUALITY (
  source_kind ENUM('area','sales','store') NOT NULL,
  source_row_id BIGINT UNSIGNED NOT NULL,
  source_batch_id VARCHAR(50) NOT NULL,
  source_document_id VARCHAR(200) NOT NULL,
  source_record_path VARCHAR(500) NOT NULL,
  source_raw_sha256 CHAR(64) NOT NULL,
  rule_version VARCHAR(20) NOT NULL,
  decision ENUM('ACCEPT','WARN','REVIEW','REJECT') NOT NULL,
  issue_codes JSON NOT NULL,
  normalized_period_code CHAR(6) NULL,
  area_code VARCHAR(50) NULL,
  industry_code VARCHAR(50) NULL,
  area_type_code VARCHAR(50) NULL,
  normalized_metrics JSON NOT NULL,
  dim_area_eligible BOOLEAN NOT NULL DEFAULT FALSE,
  fact_eligible BOOLEAN NOT NULL DEFAULT FALSE,
  result_sha256 CHAR(64) NOT NULL,
  written_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (source_kind, source_row_id),
  KEY ix_stg_p0_batch_status (source_kind, source_batch_id, decision),
  KEY ix_stg_p0_area_period (area_code, normalized_period_code),
  CONSTRAINT ck_stg_p0_area_gate CHECK (dim_area_eligible = 0),
  CONSTRAINT ck_stg_p0_fact_gate CHECK (fact_eligible = 0),
  CONSTRAINT ck_stg_p0_result_hash CHECK (CHAR_LENGTH(result_sha256) = 64),
  CONSTRAINT ck_stg_p0_raw_hash CHECK (CHAR_LENGTH(source_raw_sha256) = 64)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE VIEW V_P0_QUALITY_QUARANTINE AS
SELECT source_kind, source_row_id, source_batch_id, source_document_id,
       source_record_path, decision, issue_codes, rule_version, written_at
FROM STG_P0_QUALITY
WHERE decision IN ('REVIEW','REJECT');
