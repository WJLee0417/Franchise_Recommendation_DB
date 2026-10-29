"""Read-only verification of snapshot dimensions against the audited SRC batches.

Requires migration 007 and a completed load. No source rows or credentials are
written to the report. Run with PYTHONPATH=src and FRANCHISE_DW_* configured.
"""
import argparse
import hashlib
import json
from decimal import Decimal
from pathlib import Path

from franchise_dw.ingest_p0_csv import connect_db
from franchise_dw.load_snapshot_dimensions import EXPECTED_PERIODS, KIND_TABLE, SCOPE
from franchise_dw.snapshot_dimensions import make_evidence, quarter

TABLES = ('SNAP_SOURCE_DOCUMENT', 'SNAP_PERIOD', 'SNAP_AREA',
          'SNAP_INDUSTRY', 'SNAP_INDUSTRY_SOURCE')
COUNTS = (3, 6, 1650, 100, 163)


def fingerprints(conn):
    result = {}
    with conn.cursor() as cur:
        for table in TABLES:
            cur.execute("SELECT COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE "
                        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s AND CONSTRAINT_NAME='PRIMARY' ORDER BY ORDINAL_POSITION", (table,))
            keys = [row[0] for row in cur.fetchall()]
            if not keys:
                raise AssertionError(f'{table}: missing primary key')
            cur.execute('SELECT * FROM `' + table + '` ORDER BY ' + ','.join('`'+x+'`' for x in keys))
            rows = cur.fetchall()
            digest = hashlib.sha256()
            for row in rows:
                digest.update((json.dumps(row, ensure_ascii=False, default=str, separators=(',', ':'))+'\n').encode())
            result[table] = {'rows': len(rows), 'sha256_all_columns_pk_order': digest.hexdigest(), 'primary_key': keys}
    return result


def verify(conn):
    evidence = {e['source_kind']: e for e in make_evidence()}
    fingerprints_result = fingerprints(conn)
    for table, expected in zip(TABLES, COUNTS):
        assert fingerprints_result[table]['rows'] == expected, table
    with conn.cursor() as cur:
        cur.execute('SELECT snapshot_id,source_kind,source_batch_id,source_document_id,source_sha256,expected_rows,source_scope FROM SNAP_SOURCE_DOCUMENT')
        actual = set(cur.fetchall())
        expected = {(e['snapshot_id'], e['source_kind'], e['batch'], e['source_document_id'], e['document_sha256'], e['expected_rows'], SCOPE) for e in evidence.values()}
        assert actual == expected, 'source evidence mismatch'
        cur.execute('SELECT period_code,base_year,quarter_no,period_start,period_end_exclusive FROM SNAP_PERIOD')
        periods = cur.fetchall()
        assert {r[0] for r in periods} == EXPECTED_PERIODS
        for code, year, q, start, end in periods:
            assert (year, q, start, end) == (int(code[:4]), int(code[-1]), *quarter(code))
        ordered = sorted(periods)
        assert all(a[4] == b[3] for a, b in zip(ordered, ordered[1:]))
        e = evidence['area']
        cur.execute('SELECT source_row_id,area_code,area_name,area_type_code,area_type_name,district_code,district_name,dong_code,dong_name,x_coordinate,y_coordinate,area_size FROM SRC_SEOUL_AREA WHERE collection_batch_id=%s AND source_document_id=%s', (e['batch'],e['source_document_id']))
        source_area = cur.fetchall()
        cur.execute('SELECT source_row_id,area_code,area_name,area_type_code,area_type_name,district_code,district_name,dong_code,dong_name,x_coordinate,y_coordinate,area_size FROM SNAP_AREA WHERE snapshot_id=%s', (e['snapshot_id'],))
        snap_area = {r[0]:r for r in cur.fetchall()}
        assert len(source_area) == len(snap_area) == 1650
        for raw in source_area:
            snap = snap_area.get(raw[0])
            assert snap is not None and raw[:9] == snap[:9], f'area fields differ: {raw[0]}'
            assert tuple(None if x is None else Decimal(x) for x in raw[9:]) == snap[9:], f'area numeric mismatch: {raw[0]}'
        cur.execute('SELECT service_industry_code,service_industry_name,taxonomy_scope FROM SNAP_INDUSTRY')
        industries = {(code, name, scope) for code, name, scope in cur.fetchall()}
        cur.execute('SELECT snapshot_id,service_industry_code,rows_observed,taxonomy_scope FROM SNAP_INDUSTRY_SOURCE')
        associations = set(cur.fetchall())
        source_industries = set()
        source_associations = set()
        mapping = {}
        for kind in ('sales','store'):
            e = evidence[kind]
            cur.execute(f'SELECT base_year_quarter,service_industry_code,service_industry_name,COUNT(*) FROM {KIND_TABLE[kind]} WHERE collection_batch_id=%s AND source_document_id=%s GROUP BY base_year_quarter,service_industry_code,service_industry_name', (e['batch'],e['source_document_id']))
            groups = cur.fetchall()
            totals = {}
            count = 0
            for period, code, name, n in groups:
                normalized = period[:4]+'Q'+period[4:] if len(period) == 5 else period
                assert normalized in EXPECTED_PERIODS and (code,name,SCOPE) in industries
                source_industries.add((code,name,SCOPE))
                totals[code] = totals.get(code,0) + n
                count += n
            assert count == e['expected_rows']
            mapping[kind] = {'records_mapped_to_one_period_and_industry': count, 'industry_codes': len(totals)}
            source_associations.update((e['snapshot_id'], code, n, SCOPE) for code,n in totals.items())
        assert industries == source_industries and associations == source_associations
        assert mapping['sales']['industry_codes'] == 63 and mapping['store']['industry_codes'] == 100
    return {'fingerprints': fingerprints_result, 'area_rows_compared': len(source_area), 'mapping': mapping,
            'source_documents_exact': True, 'periods_and_exclusive_boundaries_exact': True,
            'industry_names_and_observed_counts_exact': True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    with connect_db() as conn:
        result = verify(conn)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
