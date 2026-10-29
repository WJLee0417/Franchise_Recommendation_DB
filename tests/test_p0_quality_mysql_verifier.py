"""Verifier observes commits made by the separate transformation connection."""
import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts import verify_p0_quality_mysql as verifier


class Cursor:
    def __enter__(self): return self
    def __exit__(self, *args): pass
    def execute(self, *args): pass
    def fetchone(self): return (0,)


class Connection:
    def __init__(self, events): self.events = events
    def cursor(self): return Cursor()
    def commit(self): self.events.append('commit')
    def close(self): pass


class VerifierTests(unittest.TestCase):
    def exercise(self, verify_only):
        events = []
        conn = Connection(events)
        meta = {'batch_id': 'synthetic', 'rows': 584385}
        def run(*args):
            events.append('run')
            return {'processed': 584385}
        def fingerprint(*args):
            events.append('fingerprint')
            return 'same'
        def verify(*args):
            events.append('verify')
            return {'staged_rows': 584385, 'decisions': {}}
        with tempfile.TemporaryDirectory() as folder:
            report = Path(folder) / 'report.json'
            argv = ['verify', '--report', str(report)] + (['--verify-only'] if verify_only else [])
            with patch.object(sys, 'argv', argv), patch.object(verifier, 'ORIGINAL', {'area': meta}), \
                 patch.object(verifier, 'connect_db', return_value=conn), \
                 patch.object(verifier, 'count_analytic_rows', return_value={}), \
                 patch.object(verifier, 'run', side_effect=run), \
                 patch.object(verifier, 'stage_fingerprint', side_effect=fingerprint), \
                 patch.object(verifier, 'verify_one', side_effect=verify), \
                 contextlib.redirect_stdout(io.StringIO()):
                verifier.main()
            self.assertTrue(json.loads(report.read_text(encoding='utf-8'))['all_checks_pass'])
        return events

    def test_refreshes_snapshot_after_each_separate_run(self):
        self.assertEqual(self.exercise(False), ['fingerprint', 'run', 'commit', 'verify',
                                               'fingerprint', 'run', 'commit', 'fingerprint'])

    def test_verify_only_initializes_source_report(self):
        self.assertEqual(self.exercise(True), ['fingerprint', 'verify', 'fingerprint'])


if __name__ == '__main__':
    unittest.main()
