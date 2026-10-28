"""Stream historical Seoul P0 CSV files to the original-text SRC tables.

No API calls, no ZIP extraction to disk, and no DIM/FACT writes.
Rows are indexed by CSV record position (not physical newline number).
"""
from __future__ import annotations

import argparse
import contextlib
import csv
import hashlib
import io
import json
import os
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterator


@dataclass(frozen=True)
class Source:
    table: str
    column_map: dict[str, str]
    unit_metadata: dict[str, str] | None = None


COMMON = {
    "상권_구분_코드": "area_type_code",
    "상권_구분_코드_명": "area_type_name",
    "상권_코드": "area_code",
    "상권_코드_명": "area_name",
}
QUARTER = {"기준_년분기_코드": "base_year_quarter"}
INDUSTRY = {
    "서비스_업종_코드": "service_industry_code",
    "서비스_업종_코드_명": "service_industry_name",
}
SOURCES: dict[str, Source] = {
    "area": Source("SRC_SEOUL_AREA", {**COMMON,
        "엑스좌표_값": "x_coordinate", "와이좌표_값": "y_coordinate",
        "자치구_코드": "district_code", "자치구_코드_명": "district_name",
        "행정동_코드": "dong_code", "행정동_코드_명": "dong_name",
        "영역_면적": "area_size"}),
    "sales": Source("SRC_SEOUL_SALES", {**QUARTER, **COMMON, **INDUSTRY,
        "당월_매출_금액": "estimated_sales_amount"},
        {"measure": "quarterly_estimated_sales", "amount_unit": "KRW",
         "source_period_column": "기준_년분기_코드"}),
    "store": Source("SRC_SEOUL_STORE", {**QUARTER, **COMMON, **INDUSTRY,
        "점포_수": "store_count", "유사_업종_점포_수": "similar_industry_store_count",
        "개업_율": "opening_rate", "개업_점포_수": "opened_store_count",
        "폐업_률": "closure_rate", "폐업_점포_수": "closed_store_count",
        "프랜차이즈_점포_수": "franchise_store_count"},
        {"opening_rate_unit": "percent", "closure_rate_unit": "percent",
         "source_period_column": "기준_년분기_코드"}),
}


class InputError(ValueError):
    """CSV structure or selection error. Stop ingestion; never drop rows."""


@contextlib.contextmanager
def open_source(input_path: Path, zip_member: str | None) -> Iterator[io.BufferedIOBase]:
    if not input_path.is_file():
        raise InputError(f"Input does not exist: {input_path}")
    if input_path.suffix.lower() == ".zip":
        if not zip_member:
            raise InputError("ZIP input requires --zip-member. Use --list-zip-members.")
        with zipfile.ZipFile(input_path) as archive:
            try:
                info = archive.getinfo(zip_member)
            except KeyError as exc:
                raise InputError(f"No ZIP member: {zip_member}") from exc
            if info.is_dir() or not info.filename.lower().endswith(".csv"):
                raise InputError("The ZIP member must be a CSV file")
            with archive.open(info) as stream:
                yield stream
    else:
        if zip_member or input_path.suffix.lower() != ".csv":
            raise InputError("Input must be CSV or ZIP with --zip-member")
        with input_path.open("rb") as stream:
            yield stream


def sha256_source(input_path: Path, zip_member: str | None) -> str:
    digest = hashlib.sha256()
    with open_source(input_path, zip_member) as source:
        while block := source.read(1024 * 1024):
            digest.update(block)
    return digest.hexdigest()


@contextlib.contextmanager
def csv_records(input_path: Path, zip_member: str | None,
                encoding: str = "cp949") -> Iterator[csv.DictReader]:
    with open_source(input_path, zip_member) as binary:
        with io.TextIOWrapper(binary, encoding=encoding, errors="strict", newline="") as text:
            yield csv.DictReader(text, restkey="__EXTRA_CELLS__", restval=None)


def validate_headers(reader: csv.DictReader, source: Source) -> None:
    header = reader.fieldnames
    if not header:
        raise InputError("Missing CSV header")
    if len(header) != len(set(header)):
        raise InputError("Duplicate CSV column names")
    if any(not col or not col.strip() for col in header):
        raise InputError("Blank CSV header name")
    missing = set(source.column_map).difference(header)
    if missing:
        raise InputError(f"Missing columns for {source.table}: {sorted(missing)}")


def make_batch_id(source: Source, digest: str) -> str:
    return "p0-" + hashlib.sha256((source.table + ":" + digest).encode("ascii")).hexdigest()[:28]


def read_rows(source: Source, input_path: Path, zip_member: str | None,
              digest: str, batch_id: str, source_version: str | None,
              source_url: str | None, limit: int | None = None
              ) -> Iterator[dict[str, object]]:
    with csv_records(input_path, zip_member) as reader:
        validate_headers(reader, source)
        for ordinal, row in enumerate(reader, start=2):
            if limit is not None and ordinal - 2 >= limit:
                break
            if "__EXTRA_CELLS__" in row or any(v is None for v in row.values()):
                raise InputError(f"CSV record {ordinal}: column count does not match header")
            record: dict[str, object] = {
                "collection_batch_id": batch_id,
                "source_document_id": "sha256:" + digest,
                "source_record_path": f"csv-record/{ordinal}",
                "source_url": source_url,
                "source_version": source_version,
                "reference_period_text": row.get("기준_년분기_코드"),
                "unit_metadata_text": json.dumps(source.unit_metadata, ensure_ascii=False, separators=(",", ":")) if source.unit_metadata else None,
                "raw_record_text": json.dumps(row, ensure_ascii=False, separators=(",", ":")),
            }
            record.update({target: row[original] for original, target in source.column_map.items()})
            yield record


def build_query(table: str, record: dict[str, object]) -> tuple[str, tuple[str, ...]]:
    if table not in {source.table for source in SOURCES.values()}:
        raise ValueError("Unapproved table identifier")
    fields = tuple(record)
    columns = ",".join(fields)
    binds = ",".join(["%s"] * len(fields))
    return (f"INSERT INTO {table} ({columns}) VALUES ({binds}) "
            "ON DUPLICATE KEY UPDATE source_row_id = source_row_id"), fields


def connect_db():
    try:
        import pymysql
    except ImportError as exc:
        raise RuntimeError("Install PyMySQL: python -m pip install pymysql") from exc
    if "FRANCHISE_DW_PASSWORD" not in os.environ:
        raise InputError("FRANCHISE_DW_PASSWORD is required for DB writes")
    return pymysql.connect(
        host=os.getenv("FRANCHISE_DW_HOST", "127.0.0.1"),
        port=int(os.getenv("FRANCHISE_DW_PORT", "3306")),
        user=os.getenv("FRANCHISE_DW_USER", "franchise"),
        password=os.environ["FRANCHISE_DW_PASSWORD"],
        database=os.getenv("FRANCHISE_DW_NAME", "franchise_dw_p0"),
        charset="utf8mb4", autocommit=False, connect_timeout=10)


def ingest_csv(*, kind: str, input_path: Path, zip_member: str | None = None,
               source_version: str | None = None, source_url: str | None = None,
               batch_id: str | None = None, limit: int | None = None,
               batch_size: int = 500, dry_run: bool = False,
               connection_factory: Callable | None = None) -> dict[str, object]:
    if kind not in SOURCES:
        raise InputError(f"Unknown source: {kind}")
    if limit is not None and limit < 1:
        raise InputError("--limit must be positive")
    if batch_size < 1 or batch_size > 10000:
        raise InputError("--batch-size must be in 1..10000")
    source = SOURCES[kind]
    digest = sha256_source(input_path, zip_member)
    resolved_batch = batch_id or make_batch_id(source, digest)
    if not resolved_batch.strip() or len(resolved_batch) > 50:
        raise InputError("batch ID must have 1..50 non-blank characters")
    if source_version is not None and len(source_version) > 100:
        raise InputError("source version exceeds 100 characters")
    if source_url is not None and len(source_url) > 2048:
        raise InputError("source URL exceeds 2048 characters")
    report: dict[str, object] = {
        "source": kind, "target_table": source.table,
        "source_document_id": "sha256:" + digest,
        "collection_batch_id": resolved_batch,
        "zip_member": zip_member, "dry_run": dry_run,
        "rows_scanned": 0, "rows_inserted": 0, "rows_already_present": 0,
        "limit": limit,
    }
    connection = None if dry_run else (connection_factory or connect_db)()
    try:
        pending: list[dict[str, object]] = []
        query = None
        fields: tuple[str, ...] = ()

        def flush() -> None:
            nonlocal pending
            if not pending:
                return
            if connection is None:
                pending.clear()
                return
            try:
                with connection.cursor() as cursor:
                    affected = cursor.executemany(
                        query, [tuple(row[col] for col in fields) for row in pending])
                if affected < 0 or affected > len(pending):
                    raise RuntimeError("Unexpected affected row count in idempotent INSERT")
                connection.commit()
            except Exception:
                connection.rollback()
                raise
            report["rows_inserted"] += affected
            report["rows_already_present"] += len(pending) - affected
            pending.clear()

        for record in read_rows(source, input_path, zip_member, digest,
                                resolved_batch, source_version, source_url, limit):
            if query is None:
                query, fields = build_query(source.table, record)
            pending.append(record)
            report["rows_scanned"] += 1
            if len(pending) >= batch_size:
                flush()
        flush()
        return report
    finally:
        if connection is not None:
            connection.close()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Stream archived Seoul CP949 CSV into P0 SRC only")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--source", choices=sorted(SOURCES))
    parser.add_argument("--zip-member", help="Exact CSV path inside ZIP")
    parser.add_argument("--list-zip-members", action="store_true")
    parser.add_argument("--source-version", help="Verified source version only; otherwise NULL")
    parser.add_argument("--source-url", help="Original URL, if independently verified")
    parser.add_argument("--batch-id", help="Optional; defaults to deterministic source SHA batch ID")
    parser.add_argument("--batch-size", type=int, default=500)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.list_zip_members:
            if not zipfile.is_zipfile(args.input):
                raise InputError("--list-zip-members requires ZIP input")
            with zipfile.ZipFile(args.input) as archive:
                for name in archive.namelist():
                    if name.casefold().endswith(".csv"):
                        print(name)
            return 0
        if not args.source:
            raise InputError("--source required unless --list-zip-members is set")
        result = ingest_csv(
            kind=args.source, input_path=args.input, zip_member=args.zip_member,
            source_version=args.source_version, source_url=args.source_url,
            batch_id=args.batch_id, batch_size=args.batch_size,
            limit=args.limit, dry_run=args.dry_run)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (InputError, csv.Error, UnicodeError) as exc:
        print(f"INPUT ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
