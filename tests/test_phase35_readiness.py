"""Tests confirm the phase 3-5-1 gate is permanently HOLD without authoritative evidence."""
import json
from pathlib import Path
from unittest import TestCase
import importlib.util
from unittest.mock import MagicMock
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/"config"/"phase35_load_gates.v1.json"

class ReadinessGateTests(TestCase):
 def test_manifest_blocks_loading(self):
  m=json.loads(MANIFEST.read_text(encoding="utf-8"))
  self.assertEqual(m["overall_decision"],"HOLD_FACT_LOADING")
  self.assertEqual(len(m["gates"]),12)
  self.assertEqual(len({x["id"] for x in m["gates"]}),12)
  self.assertEqual(sum(x["state"]=="BLOCKED" for x in m["gates"]),6)
  self.assertFalse(any(x["id"]=="G02" and x["state"]!="BLOCKED" for x in m["gates"]))
  self.assertEqual(m["evidence"]["quality_stage"]["processed"],584385)
 def test_preflight_uses_read_only_sql(self):
  p=ROOT/"scripts"/"preflight_p0_dim_fact.py"
  body=p.read_text(encoding="utf-8")
  self.assertIn('"can_load_dim_fact":False',body)
  self.assertIn('"can_load_dim_fact"',body)
  self.assertNotIn("INSERT INTO",body)
  self.assertNotIn("DELETE FROM",body)
  self.assertNotIn("UPDATE DIM_",body)
  self.assertNotIn("UPDATE FACT_",body)
 def test_known_source_counts(self):
  p=ROOT/"scripts"/"preflight_p0_dim_fact.py"
  import ast
  module=ast.parse(p.read_text(encoding="utf-8"))
  assignment=next(x for x in module.body if isinstance(x,ast.Assign) and any(isinstance(t,ast.Name) and t.id=="BATCH" for t in x.targets))
  values=ast.literal_eval(assignment.value)
  self.assertEqual(sum(x[2] for x in values.values()),584385)
  self.assertEqual(set(values),{"area","sales","store"})
