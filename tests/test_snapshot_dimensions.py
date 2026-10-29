import unittest
from franchise_dw.snapshot_dimensions import DOCS,make_evidence,quarter,snapshot_id

class SnapshotDimensionsTest(unittest.TestCase):
 def test_exact_hashes_and_determinism(self):
  e=make_evidence()
  self.assertEqual(sum(x["expected_rows"] for x in e),584385)
  self.assertEqual({x["source_kind"] for x in e},{"area","sales","store"})
  for x in e:
   self.assertEqual(len(x["snapshot_id"]),64)
   self.assertEqual(x["snapshot_id"],snapshot_id(x["source_kind"],x["document_sha256"]))
  self.assertEqual(len({x["snapshot_id"] for x in e}),3)
 def test_quarters(self):
  self.assertEqual(quarter("2022Q1")[0].isoformat(),"2022-01-01")
  self.assertEqual(quarter("2022Q4")[1].isoformat(),"2023-01-01")
  self.assertEqual(quarter("2023Q2")[1].isoformat(),"2023-07-01")
  for bad in ("2023Q0","2023Q5","20231","2023-1","2022Q1x"):
   with self.assertRaises(ValueError):quarter(bad)
 def test_invalid_digest(self):
  for bad in ("bad","f"*63,"G"*64):
   with self.assertRaises(ValueError):snapshot_id("area",bad)
