-- Phase 3-5-4: separate snapshot dimensions (not SCD, no inferred valid-from).
USE franchise_dw_p0;
CREATE TABLE SNAP_SOURCE_DOCUMENT (
  snapshot_id CHAR(64) PRIMARY KEY,
  source_kind ENUM('area','sales','store') NOT NULL,
  source_batch_id VARCHAR(50) NOT NULL,
  source_document_id VARCHAR(200) NOT NULL,
  source_sha256 CHAR(64) NOT NULL,
  expected_rows BIGINT UNSIGNED NOT NULL,
  source_scope VARCHAR(100) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  UNIQUE KEY uq_snap_source (source_kind,source_batch_id,source_document_id),
  CONSTRAINT ck_snap_sha CHECK (source_sha256 REGEXP '^[a-f0-9]{64}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE SNAP_PERIOD (
  period_code CHAR(6) PRIMARY KEY,
  base_year SMALLINT UNSIGNED NOT NULL,
  quarter_no TINYINT UNSIGNED NOT NULL,
  period_start DATE NOT NULL,
  period_end_exclusive DATE NOT NULL,
  UNIQUE KEY uq_snap_year_quarter (base_year,quarter_no),
  CONSTRAINT ck_snap_quarter CHECK (quarter_no BETWEEN 1 AND 4),
  CONSTRAINT ck_snap_dates CHECK (period_end_exclusive > period_start)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE SNAP_AREA (
  snapshot_id CHAR(64) NOT NULL,
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
  source_row_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY(snapshot_id,area_code),
  UNIQUE KEY uq_snap_area_source (snapshot_id,source_row_id),
  CONSTRAINT fk_snap_area_source FOREIGN KEY(snapshot_id) REFERENCES SNAP_SOURCE_DOCUMENT(snapshot_id),
  CONSTRAINT fk_snap_area_orig FOREIGN KEY(source_row_id) REFERENCES SRC_SEOUL_AREA(source_row_id),
  CONSTRAINT ck_snap_area_size CHECK (area_size IS NULL OR area_size>=0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE SNAP_INDUSTRY (
  service_industry_code VARCHAR(50) NOT NULL,
  service_industry_name VARCHAR(200) NOT NULL,
  taxonomy_scope VARCHAR(100) NOT NULL,
  PRIMARY KEY(taxonomy_scope,service_industry_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE SNAP_INDUSTRY_SOURCE (
  snapshot_id CHAR(64) NOT NULL,
  service_industry_code VARCHAR(50) NOT NULL,
  rows_observed BIGINT UNSIGNED NOT NULL,
  taxonomy_scope VARCHAR(100) NOT NULL,
  PRIMARY KEY(snapshot_id,service_industry_code),
  CONSTRAINT fk_snap_is_source FOREIGN KEY(snapshot_id) REFERENCES SNAP_SOURCE_DOCUMENT(snapshot_id),
  CONSTRAINT fk_snap_is_industry FOREIGN KEY(taxonomy_scope,service_industry_code)
      REFERENCES SNAP_INDUSTRY(taxonomy_scope,service_industry_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
