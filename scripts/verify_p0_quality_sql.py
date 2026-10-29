"""Independently compare audited MySQL SRC/STG values using SQL expressions.

Run with PYTHONPATH=src and FRANCHISE_DW_* configured:
  python scripts/verify_p0_quality_sql.py --report data/local/p0_sql_checks.json

This checks stored values and SHA-256, not the complete decision algorithm.
"""
import argparse
import json
from pathlib import Path

from franchise_dw.ingest_p0_csv import connect_db
from franchise_dw.transform_p0_quality import METRICS, TABLES
from verify_p0_quality_mysql import ORIGINAL


def verify(conn, kind, meta):
    tests = {
        'raw_hash': 's.source_raw_sha256 <> SHA2(r.raw_record_text,256)',
        'area_code': 'NOT (BINARY s.area_code <=> BINARY TRIM(r.area_code))',
        'area_type_code': 'NOT (BINARY s.area_type_code <=> BINARY TRIM(r.area_type_code))',
        'gating': 's.dim_area_eligible <> 0 OR s.fact_eligible <> 0',
    }
    if kind != 'area':
        tests['period'] = "NOT (BINARY s.normalized_period_code <=> BINARY CONCAT(LEFT(r.base_year_quarter,4),'Q',RIGHT(r.base_year_quarter,1)))"
        tests['industry_code'] = 'NOT (BINARY s.industry_code <=> BINARY TRIM(r.service_industry_code))'
    for metric in METRICS[kind]:
        # Fail instead of silently accepting MySQL coercion or DECIMAL rounding.
        tests[metric+'_source_format'] = (
            "r."+metric+" IS NULL OR TRIM(r."+metric+") NOT REGEXP '^[0-9]+([.][0-9]{1,10})?$' OR "
            "LENGTH(SUBSTRING_INDEX(TRIM(r."+metric+"),'.',1)) > 55")
        tests[metric] = ("NOT (CAST(JSON_UNQUOTE(JSON_EXTRACT(s.normalized_metrics, '$."
                         + metric + "')) AS DECIMAL(65,10)) <=> CAST(r." + metric
                         + " AS DECIMAL(65,10)))")
    selections = ', '.join('SUM(CASE WHEN '+condition+' THEN 1 ELSE 0 END)'
                           for condition in tests.values())
    sql = ('SELECT COUNT(*), '+selections+' FROM '+TABLES[kind]
           +' r JOIN STG_P0_QUALITY s ON s.source_kind=%s AND s.source_row_id=r.source_row_id'
           +' WHERE r.collection_batch_id=%s')
    with conn.cursor() as cursor:
        cursor.execute(sql, (kind, meta['batch_id']))
        values = cursor.fetchone()
    result = {'joined_rows': values[0],
              'mismatches': dict(zip(tests, (int(x or 0) for x in values[1:])))}
    if result['joined_rows'] != meta['rows'] or any(result['mismatches'].values()):
        raise AssertionError((kind, result))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', required=True, type=Path)
    parser.add_argument('--source', choices=tuple(ORIGINAL), nargs='+', default=list(ORIGINAL))
    args = parser.parse_args()
    result = {}
    with connect_db() as conn:
        for kind, meta in ORIGINAL.items():
            if kind not in args.source:
                continue
            result[kind] = verify(conn, kind, meta)
            print(f"PASS independent SQL {kind}: {result[kind]['joined_rows']} rows", flush=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    main()
