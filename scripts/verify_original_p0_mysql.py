"""Verify all three historical original CSVs against a real MySQL 8 SRC database.

Run privately: PYTHONPATH=src python scripts/verify_original_p0_mysql.py
  --input data/local/archive.zip --report data/local/mysql-validation.json

No source CSVs, passwords or raw values are uploaded to GitHub.
"""
import argparse
import hashlib
import json
import zipfile
from pathlib import Path

from franchise_dw.ingest_p0_csv import (
    SOURCES, connect_db, ingest_csv, make_batch_id, read_rows, sha256_source,
)

SAMPLES = {
    "area": ("서울시 상권분석서비스(영역-상권).csv",
             "b6281497b242d25569dcf61cc8bd05e80d300101eea5079577e42d0d280bf137", 1650),
    "sales": ("서울시 상권분석서비스(추정매출-상권).csv",
              "ac2ba3a8f74ec3ccbcb0ca87ba0a9cdb7b1c4cbe21d1f17331d12fa644db786d", 125692),
    "store": ("서울시 상권분석서비스(점포-상권).csv",
              "8f6932112d355554a290b01ca67cd697474107fc6ad478a23b499a742cc98561", 457043),
}
PREFIX = "2023_Franchise_Recommendation_DB/1/"


def select_members(zip_path):
    with zipfile.ZipFile(zip_path) as z:
        names = z.namelist()
    result = {}
    for kind, (suffix, _, _) in SAMPLES.items():
        matches = [name for name in names if name.startswith(PREFIX) and name.endswith(suffix)]
        if len(matches) != 1:
            raise RuntimeError(f"{kind}: expected one member in /1/, got {len(matches)}")
        result[kind] = matches[0]
    return result


def verify_persisted(kind, archive, member, file_hash, batch_id, expected_count):
    import pymysql
    src = SOURCES[kind]
    columns = [
        "source_record_path", "source_document_id", "raw_record_text",
        "reference_period_text", *src.column_map.values(),
    ]
    digest = hashlib.sha256()
    anomalies = {"opening": 0, "closure": 0, "either": 0}
    with connect_db() as conn:
        with conn.cursor() as cur:
            cur.execute(f"SELECT COUNT(*) FROM {src.table} WHERE collection_batch_id=%s", (batch_id,))
            actual_count = cur.fetchone()[0]
        if actual_count != expected_count:
            raise AssertionError(f"{kind}: {actual_count} persisted, expected {expected_count}")
        sql = (
            "SELECT " + ", ".join(columns) + f" FROM {src.table} "
            + "WHERE collection_batch_id=%s ORDER BY source_row_id"
        )
        with conn.cursor(pymysql.cursors.SSCursor) as cur:
            cur.execute(sql, (batch_id,))
            count = 0
            for row in read_rows(src, archive, member, file_hash, batch_id, None, None):
                stored_tuple = cur.fetchone()
                if stored_tuple is None:
                    raise AssertionError(f"{kind}: too few MySQL rows")
                count += 1
                stored = dict(zip(columns, stored_tuple))
                for key in columns:
                    if row[key] != stored[key]:
                        raise AssertionError(f"{kind}: record {count}, field {key} mismatch")
                fields = json.loads(stored["raw_record_text"])
                for source_field, target_field in src.column_map.items():
                    if fields[source_field] != stored[target_field]:
                        raise AssertionError(
                            f"{kind}: record {count}, unmodified original field {source_field} differs"
                        )
                digest.update(
                    (stored["source_record_path"] + "\t"
                     + stored["raw_record_text"] + "\n").encode("utf-8")
                )
                if kind == "store":
                    a, b = float(fields["개업_율"]), float(fields["폐업_률"])
                    anomalies["opening"] += a > 100
                    anomalies["closure"] += b > 100
                    anomalies["either"] += (a > 100 or b > 100)
            if cur.fetchone() is not None or count != expected_count:
                raise AssertionError(f"{kind}: stored count and source order inconsistent")
    if kind == "store" and anomalies != {"opening": 5, "closure": 124, "either": 128}:
        raise AssertionError(f"Store source above-100 values changed: {anomalies}")
    return {"rows_verified": expected_count, "all_mapped_fields_and_raw_json_match": True,
            "raw_record_sha256": digest.hexdigest(),
            "rate_anomalies": anomalies if kind == "store" else None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--batch-size", type=int, default=1000)
    args = parser.parse_args()
    if args.input.suffix.lower() != ".zip":
        parser.error("input must be a private .zip")
    if args.input.resolve() == args.report.resolve():
        parser.error("report must not overwrite the archive")

    result = {"verification": "REAL_MYSQL", "source_zip": args.input.name,
              "all_checks_pass": False, "tables": {}}
    for kind, member in select_members(args.input).items():
        _, expected_hash, expected_count = SAMPLES[kind]
        digest = sha256_source(args.input, member)
        if digest != expected_hash:
            raise RuntimeError(f"{kind}: ZIP member SHA256 differs from audited archive")
        batch_id = make_batch_id(SOURCES[kind], digest)
        first = ingest_csv(kind=kind, input_path=args.input,
                           zip_member=member, batch_size=args.batch_size)
        again = ingest_csv(kind=kind, input_path=args.input,
                           zip_member=member, batch_size=args.batch_size)
        if first["rows_scanned"] != expected_count:
            raise AssertionError(f"{kind}: source count differs")
        if again["rows_inserted"] or again["rows_already_present"] != expected_count:
            raise AssertionError(f"{kind}: rerun should insert zero rows")
        verified = verify_persisted(kind, args.input, member, digest, batch_id, expected_count)
        result["tables"][kind] = {
            "source_sha256": digest, "batch_id": batch_id,
            "first_run": {k: first[k] for k in
                          ("rows_scanned", "rows_inserted", "rows_already_present")},
            "second_run": {k: again[k] for k in
                           ("rows_scanned", "rows_inserted", "rows_already_present")},
            **verified,
        }
        print(f"PASS {kind}: {expected_count} persisted, rerun inserted 0, raw matches", flush=True)
    result["all_checks_pass"] = True
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Verification report: {args.report}")


if __name__ == "__main__":
    main()
