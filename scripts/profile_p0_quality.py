"""Profile the three audited 2022Q1–2023Q2 Seoul P0 CP949 CSVs.

Stdlib only. Prints no raw records; outputs aggregate quality evidence as JSON.
Run: python scripts/profile_p0_quality.py --zip data/local/archive.zip --output data/local/p0_quality.json
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import re
import zipfile
from collections import Counter, defaultdict
from decimal import Decimal
from pathlib import Path

FILES = {
    "area": "서울시 상권분석서비스(영역-상권).csv",
    "sales": "서울시 상권분석서비스(추정매출-상권).csv",
    "store": "서울시 상권분석서비스(점포-상권).csv",
}
AUDITED_SHA256 = {
    "area": "b6281497b242d25569dcf61cc8bd05e80d300101eea5079577e42d0d280bf137",
    "sales": "ac2ba3a8f74ec3ccbcb0ca87ba0a9cdb7b1c4cbe21d1f17331d12fa644db786d",
    "store": "8f6932112d355554a290b01ca67cd697474107fc6ad478a23b499a742cc98561",
}
KEYS = {
    "area": ("상권_코드",),
    "sales": ("기준_년분기_코드", "상권_코드", "서비스_업종_코드"),
    "store": ("기준_년분기_코드", "상권_코드", "서비스_업종_코드"),
}
DIMENSIONS = {
    "기준_년분기_코드", "상권_구분_코드", "상권_구분_코드_명",
    "상권_코드", "상권_코드_명", "서비스_업종_코드", "서비스_업종_코드_명",
    "자치구_코드", "자치구_코드_명", "행정동_코드", "행정동_코드_명",
}
NUMERIC = re.compile(r"^-?\d+(?:\.\d+)?$")
PERIOD = re.compile(r"^(19|20)\d{2}[1-4]$")
SENTINELS = {"", "NULL", "NA", "N/A", "NONE", "-", "-9999", "미상", "정보없음"}


def select_members(archive: zipfile.ZipFile) -> dict[str, str]:
    names = archive.namelist()
    matches = {}
    for kind, filename in FILES.items():
        candidates = [s for s in names if s.endswith("/1/" + filename)]
        if len(candidates) != 1:
            raise ValueError(f"{kind}: expected one /1/ original; got {len(candidates)}")
        matches[kind] = candidates[0]
    return matches


def subgroup(row: dict[str, str], starts: str, suffix: str) -> int:
    return sum(int(value) for name, value in row.items()
               if name.startswith(starts) and name.endswith(suffix))


def profile(zip_path: Path, strict_audit: bool = False) -> dict:
    result = {"scope": "historical Seoul P0 CSV; not 2026 API",
              "source": zip_path.name, "files": {}, "cross_source": {}}
    keysets = {k: set() for k in FILES}
    area_codes = {k: set() for k in FILES}
    industry_codes = {k: set() for k in ("sales", "store")}
    all_names = defaultdict(set)
    all_types = defaultdict(set)
    with zipfile.ZipFile(zip_path) as archive:
        for kind, member in select_members(archive).items():
            digest = hashlib.sha256()
            with archive.open(member) as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(block)
            if strict_audit and digest.hexdigest() != AUDITED_SHA256[kind]:
                raise ValueError(f"{kind}: SHA256 differs from audited source")

            counters = {"rows": 0, "duplicate_keys": 0, "blank_keys": 0,
                        "invalid_periods": 0}
            missing = Counter()
            nonnumeric = Counter()
            negative = Counter()
            zero = Counter()
            fractional = Counter()
            maxima: dict[str, Decimal] = {}
            minima: dict[str, Decimal] = {}
            issues = Counter()
            issue_by_period: dict[str, Counter] = defaultdict(Counter)
            periods = Counter()
            with archive.open(member) as binary:
                with io.TextIOWrapper(binary, encoding="cp949", errors="strict",
                                      newline="") as stream:
                    reader = csv.DictReader(stream, restkey="__EXTRA__", restval=None)
                    headers = reader.fieldnames or []
                    if not headers or len(headers) != len(set(headers)):
                        raise ValueError(f"{kind}: invalid/duplicate CSV header")
                    measure_headers = [name for name in headers if name not in DIMENSIONS]
                    for row_no, row in enumerate(reader, start=2):
                        if "__EXTRA__" in row or any(v is None for v in row.values()):
                            raise ValueError(f"{kind} record {row_no}: column count invalid")
                        counters["rows"] += 1
                        key = tuple(row[x] for x in KEYS[kind])
                        if any(not s.strip() for s in key):
                            counters["blank_keys"] += 1
                        if key in keysets[kind]:
                            counters["duplicate_keys"] += 1
                        keysets[kind].add(key)
                        area_codes[kind].add(row["상권_코드"])
                        all_names[row["상권_코드"]].add(row["상권_코드_명"])
                        all_types[row["상권_코드"]].add(row["상권_구분_코드"])
                        period = row.get("기준_년분기_코드")
                        if period:
                            periods[period] += 1
                            if not PERIOD.fullmatch(period):
                                counters["invalid_periods"] += 1
                        if kind != "area":
                            industry_codes[kind].add(row["서비스_업종_코드"])
                        for name in measure_headers:
                            value = row[name].strip()
                            if value.upper() in SENTINELS:
                                missing[name] += 1
                                continue
                            if not NUMERIC.fullmatch(value):
                                nonnumeric[name] += 1
                                continue
                            number = Decimal(value)
                            if number < 0:
                                negative[name] += 1
                            if number == 0:
                                zero[name] += 1
                            if number != number.to_integral_value():
                                fractional[name] += 1
                            if name not in minima or number < minima[name]:
                                minima[name] = number
                            if name not in maxima or number > maxima[name]:
                                maxima[name] = number
                        def flag(name: str, predicate: bool) -> None:
                            if predicate:
                                issues[name] += 1
                                if period is not None:
                                    issue_by_period[name][period] += 1
                        if kind == "store":
                            n = int(row["점포_수"])
                            op, cl = int(row["개업_점포_수"]), int(row["폐업_점포_수"])
                            opr, clr = Decimal(row["개업_율"]), Decimal(row["폐업_률"])
                            flag("opening_rate_gt_100", opr > 100)
                            flag("closure_rate_gt_100", clr > 100)
                            flag("either_rate_gt_100", opr > 100 or clr > 100)
                            flag("store_count_zero", n == 0)
                            flag("zero_stores_with_events", n == 0 and (op > 0 or cl > 0))
                            flag("franchise_count_gt_store", int(row["프랜차이즈_점포_수"]) > n)
                            flag("similar_count_gt_store", int(row["유사_업종_점포_수"]) > n)
                            flag("opened_count_gt_store", op > n)
                            flag("closed_count_gt_store", cl > n)
                            flag("zero_open_rate_positive_count", opr == 0 and op > 0)
                            flag("zero_close_rate_positive_count", clr == 0 and cl > 0)
                        if kind == "sales":
                            amt = int(row["당월_매출_금액"])
                            tx = int(row["당월_매출_건수"])
                            flag("zero_sales_amount", amt == 0)
                            flag("zero_sales_txns", tx == 0)
                            flag("positive_sales_zero_txns", amt > 0 and tx == 0)
                            flag("zero_sales_positive_txns", amt == 0 and tx > 0)
                            for label, target, components in (
                                ("weekday_weekend_amount", amt,
                                 int(row["주중_매출_금액"]) + int(row["주말_매출_금액"])),
                                ("weekday_weekend_txns", tx,
                                 int(row["주중_매출_건수"]) + int(row["주말_매출_건수"])),
                                ("days_amount", amt,
                                 sum(int(row[f"{d}요일_매출_금액"])
                                     for d in ("월", "화", "수", "목", "금", "토", "일"))),
                                ("days_txns", tx,
                                 sum(int(row[f"{d}요일_매출_건수"])
                                     for d in ("월", "화", "수", "목", "금", "토", "일"))),
                                ("time_amount", amt, subgroup(row, "시간대_", "_매출_금액")),
                                ("time_txns", tx, subgroup(row, "시간대_", "_매출_건수")),
                                ("sex_amount", amt,
                                 int(row["남성_매출_금액"]) + int(row["여성_매출_금액"])),
                                ("sex_txns", tx,
                                 int(row["남성_매출_건수"]) + int(row["여성_매출_건수"])),
                                ("age_amount", amt, subgroup(row, "연령대_", "_매출_금액")),
                                ("age_txns", tx, subgroup(row, "연령대_", "_매출_건수")),
                            ):
                                flag(label + "_mismatch", components != target)
                            flag("negative_time_txn_bins", any(
                                int(value) < 0 for name, value in row.items()
                                if name.startswith("시간대_") and name.endswith("_매출_건수")))
            result["files"][kind] = {
                "member": member, "sha256": digest.hexdigest(),
                "row_count": counters["rows"], "column_count": len(headers),
                **counters,
                "periods": dict(periods), "missing_by_column": dict(missing),
                "nonnumeric_by_column": dict(nonnumeric),
                "negative_by_column": dict(negative),
                "zero_by_column": dict(zero),
                "fractional_by_column": dict(fractional),
                "min_by_column": {k: str(v) for k, v in minima.items()},
                "max_by_column": {k: str(v) for k, v in maxima.items()},
                "issues": dict(issues),
                "issue_by_period": {k: dict(v) for k, v in issue_by_period.items()},
                "unique_area_codes": len(area_codes[kind]),
                "unique_industry_codes": len(industry_codes.get(kind, ())),
            }
    result["cross_source"] = {
        "sales_area_codes_missing_from_area": len(area_codes["sales"] - area_codes["area"]),
        "store_area_codes_missing_from_area": len(area_codes["store"] - area_codes["area"]),
        "sales_business_keys_missing_from_store": len(keysets["sales"] - keysets["store"]),
        "store_business_keys_missing_from_sales": len(keysets["store"] - keysets["sales"]),
        "store_only_industry_codes": len(industry_codes["store"] - industry_codes["sales"]),
        "area_codes_with_multiple_names": sum(len(v) > 1 for v in all_names.values()),
        "area_codes_with_multiple_types": sum(len(v) > 1 for v in all_types.values()),
    }
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zip", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--strict-audit", action="store_true")
    args = parser.parse_args()
    output = profile(args.zip, strict_audit=args.strict_audit)
    serialized = json.dumps(output, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(serialized, encoding="utf-8")
    else:
        print(serialized)


if __name__ == "__main__":
    main()
