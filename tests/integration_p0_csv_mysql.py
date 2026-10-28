"""Integration test against a REAL MySQL 8 service, with synthetic CSV fixtures.

Run: PYTHONPATH=src FRANCHISE_DW_* configured python tests/integration_p0_csv_mysql.py
The uploaded historical ZIP is intentionally not committed to GitHub.
"""
import csv
import json
import tempfile
from pathlib import Path

from franchise_dw.ingest_p0_csv import SOURCES, connect_db, ingest_csv


def make_csv(path: Path, kind: str, count: int = 3) -> None:
    headers = list(SOURCES[kind].column_map)
    if kind == "sales":
        headers += ["당월_매출_건수", "월요일_매출_금액"]
    with path.open("w", encoding="cp949", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=headers)
        writer.writeheader()
        for seq in range(1, count + 1):
            row = {key: str(100 + seq) for key in headers}
            row.update({
                "상권_코드": f"0311000{seq}",
                "상권_코드_명": "종로·청계 관광특구",
                "상권_구분_코드": "A",
                "상권_구분_코드_명": "골목상권",
            })
            if kind != "area":
                row["기준_년분기_코드"] = "20221"
                row["서비스_업종_코드"] = "CS100001"
                row["서비스_업종_코드_명"] = "한식음식점"
            if kind == "sales":
                row["당월_매출_금액"] = "340449266"
                row["당월_매출_건수"] = "9508"
                row["월요일_매출_금액"] = "1000"
            if kind == "store":
                row["개업_율"] = "200"
                row["폐업_률"] = "4800"
            writer.writerow(row)


def check_db(kind: str, report: dict, expected_count: int, index: int = 1) -> None:
    table = SOURCES[kind].table
    with connect_db() as conn:
        with conn.cursor() as cursor:
            cursor.execute(
                f"SELECT COUNT(*) FROM `{table}` WHERE collection_batch_id=%s",
                (report["collection_batch_id"],),
            )
            assert cursor.fetchone()[0] == expected_count, (kind, report)
            cursor.execute(
                f"SELECT area_code, area_name, raw_record_text "
                f"FROM `{table}` WHERE collection_batch_id=%s "
                "AND source_record_path=%s",
                (report["collection_batch_id"], f"csv-record/{index + 1}"),
            )
            area_code, area_name, raw_text = cursor.fetchone()
            assert area_code == f"0311000{index}"
            assert area_name == "종로·청계 관광특구"
            raw = json.loads(raw_text)
            assert raw["상권_코드"] == f"0311000{index}"
            if kind == "sales":
                assert raw["당월_매출_건수"] == "9508"
                cursor.execute(
                    "SELECT estimated_sales_amount FROM SRC_SEOUL_SALES "
                    "WHERE collection_batch_id=%s AND source_record_path=%s",
                    (report["collection_batch_id"], f"csv-record/{index + 1}"),
                )
                assert cursor.fetchone()[0] == "340449266"
            if kind == "store":
                assert raw["개업_율"] == "200"
                assert raw["폐업_률"] == "4800"
                cursor.execute(
                    "SELECT opening_rate, closure_rate FROM SRC_SEOUL_STORE "
                    "WHERE collection_batch_id=%s AND source_record_path=%s",
                    (report["collection_batch_id"], f"csv-record/{index + 1}"),
                )
                assert cursor.fetchone() == ("200", "4800")


def main() -> None:
    with tempfile.TemporaryDirectory() as folder:
        # Fail during a transaction after one committed batch. The actual MySQL
        # connection rolls the second batch back, and a retry must resume it.
        interrupted = Path(folder) / "interrupted.csv"
        make_csv(interrupted, "area", count=5)

        class FailSecondCommit:
            def __init__(self):
                self.conn = connect_db()
                self.commits = 0

            def cursor(self):
                return self.conn.cursor()

            def commit(self):
                self.commits += 1
                if self.commits == 2:
                    raise RuntimeError("simulated interruption before commit")
                self.conn.commit()

            def rollback(self):
                self.conn.rollback()

            def close(self):
                self.conn.close()

        try:
            ingest_csv(kind="area", input_path=interrupted, batch_size=2,
                       connection_factory=FailSecondCommit)
            raise AssertionError("interruption was not triggered")
        except RuntimeError as exc:
            assert str(exc) == "simulated interruption before commit"
        resumed = ingest_csv(kind="area", input_path=interrupted, batch_size=2)
        assert (resumed["rows_scanned"], resumed["rows_inserted"],
                resumed["rows_already_present"]) == (5, 3, 2), resumed
        check_db("area", resumed, 5, index=5)
        print("PASS MySQL synthetic interruption: committed batch retained, active batch rolled back, retry resumed")

        for kind in ("area", "sales", "store"):
            path = Path(folder) / f"{kind}.csv"
            make_csv(path, kind)
            partial = ingest_csv(kind=kind, input_path=path, limit=2, batch_size=1)
            assert (partial["rows_scanned"], partial["rows_inserted"], partial["rows_already_present"]) == (2, 2, 0), partial
            check_db(kind, partial, 2)
            full = ingest_csv(kind=kind, input_path=path, batch_size=2)
            assert (full["rows_scanned"], full["rows_inserted"], full["rows_already_present"]) == (3, 1, 2), full
            assert full["collection_batch_id"] == partial["collection_batch_id"]
            check_db(kind, full, 3, index=3)
            replay = ingest_csv(kind=kind, input_path=path, batch_size=2)
            assert (replay["rows_scanned"], replay["rows_inserted"], replay["rows_already_present"]) == (3, 0, 3), replay
            check_db(kind, replay, 3)
            print(f"PASS MySQL {kind}: partial insert, resume, idempotent replay, Korean text, raw values")

    # No P0 Python module creates DIM/FACT rows.
    with connect_db() as conn:
        with conn.cursor() as cursor:
            for table in ("DIM_AREA", "DIM_INDUSTRY", "FACT_AREA_SALES", "FACT_AREA_STORE"):
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                assert cursor.fetchone()[0] == 0, table
    print("PASS MySQL integration: SRC only; 3 sources/9 rows, no duplicate on replay")


if __name__ == "__main__":
    main()
