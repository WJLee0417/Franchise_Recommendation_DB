"""Run snapshot dry-run, load and replay after independent preflight approval.

Requires the caller to verify the original files, SRC/STG and database baseline
first. Refuses non-empty snapshots. Writes aggregate results only.
"""
import argparse
import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from franchise_dw.ingest_p0_csv import connect_db
from franchise_dw.load_snapshot_dimensions import run
from verify_snapshot_dimensions_mysql import fingerprints, verify


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', required=True, type=Path)
    args = parser.parse_args()
    result = {'started_utc': datetime.now(timezone.utc).isoformat(), 'status': 'in_progress'}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    def save():
        args.report.write_text(json.dumps(result, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    save()
    try:
        conn = connect_db()
        try:
            before = fingerprints(conn)
            if any(v['rows'] for v in before.values()):
                raise RuntimeError('Snapshot tables are not empty; refusing initial-load procedure')
            # Test the actual module entry point and then inspect uncommitted rows
            # on the same connection to verify the full dry-run before rollback.
            start = time.monotonic()
            process = subprocess.run([sys.executable, '-m', 'franchise_dw.load_snapshot_dimensions', '--dry-run'], check=True, capture_output=True, text=True)
            result['module_dry_run_seconds'] = round(time.monotonic()-start, 3)
            result['module_dry_run_output'] = process.stdout.strip()
            conn.rollback()  # refresh REPEATABLE READ after subprocess
            assert fingerprints(conn) == before, 'module dry-run left data behind'
            start = time.monotonic()
            try:
                run(conn)
                result['dry_run_full_comparison'] = verify(conn)
            finally:
                conn.rollback()
            result['verified_dry_run_seconds'] = round(time.monotonic()-start, 3)
            assert fingerprints(conn) == before, 'verified dry-run left data behind'
            result['dry_run_rollback_unchanged'] = True
            save()
        finally:
            conn.close()
        start = time.monotonic()
        process = subprocess.run([sys.executable, '-m', 'franchise_dw.load_snapshot_dimensions'], check=True, capture_output=True, text=True)
        result['first_load_seconds'] = round(time.monotonic()-start, 3)
        result['first_load_output'] = process.stdout.strip()
        save()
        with connect_db() as conn:
            result['first_load_validation'] = verify(conn)
        save()
        start = time.monotonic()
        process = subprocess.run([sys.executable, '-m', 'franchise_dw.load_snapshot_dimensions'], check=True, capture_output=True, text=True)
        result['replay_seconds'] = round(time.monotonic()-start, 3)
        result['replay_output'] = process.stdout.strip()
        with connect_db() as conn:
            result['replay_validation'] = verify(conn)
        assert result['first_load_validation'] == result['replay_validation'], 'replay changed snapshot data'
        result['replay_all_columns_and_primary_keys_unchanged'] = True
        result['status'] = 'passed'
    except BaseException as exc:
        result['status'] = 'failed'
        result['error'] = str(exc)
        raise
    finally:
        result['finished_utc'] = datetime.now(timezone.utc).isoformat()
        save()
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
