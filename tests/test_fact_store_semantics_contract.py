"""Static tests: store semantic contract, safe migration and held temporal gates."""
import json
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class StoreContractTests(unittest.TestCase):
 def test_mappings(self):
  x=json.loads((ROOT/"config/phase35_fact_store_contract.v1.json").read_text(encoding="utf-8"))
  f={r["target"]:r for r in x["fields"]}
  self.assertEqual(f["ordinary_store_count"]["source"],"SRC_SEOUL_STORE.store_count")
  self.assertEqual(f["total_store_count"]["source"],"SRC_SEOUL_STORE.similar_industry_store_count")
  self.assertEqual(f["franchise_store_count"]["source"],"SRC_SEOUL_STORE.franchise_store_count")
  self.assertEqual(x["fact_load_status"],"BLOCKED_UNTIL_TEMPORAL_GATES_PASS")
 def test_guarded_migration(self):
  sql=(ROOT/"sql/v2/migrations/006_fact_area_store_semantic_names.sql").read_text(encoding="utf-8")
  self.assertIn("IF n <> 0 THEN",sql)
  self.assertIn("CHANGE COLUMN store_count ordinary_store_count",sql)
  self.assertIn("CHANGE COLUMN similar_industry_store_count total_store_count",sql)
  self.assertIn("total_store_count = ordinary_store_count + franchise_store_count",sql)
  self.assertNotIn("UPDATE SRC_",sql)
  self.assertNotIn("INSERT INTO FACT_",sql)
if __name__=="__main__":unittest.main()
