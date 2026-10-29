import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock
from franchise_dw.transform_p0_quality import (POLICY_PATH, evaluate, decimal_value,
                                                load_policy, run)

BASE={"source_row_id":1,"collection_batch_id":"b","source_document_id":"d",
      "source_record_path":"csv-record/2","area_code":"0311001",
      "area_type_code":"A","base_year_quarter":"20221",
      "service_industry_code":"CS100001","raw_record_text":"{}"}

def test_row(**kwargs):
    return {**BASE,**kwargs}

class P0QualityTests(unittest.TestCase):
    def test_numeric_and_period(self):
        self.assertEqual(decimal_value("00012",integer=True),12)
        self.assertEqual(decimal_value("4800"),"4800")
        for bad in ("NaN","Infinity","-1","N/A","1.5"):
            with self.assertRaises(ValueError):
                decimal_value(bad,integer=True)
        r=evaluate("sales",test_row(estimated_sales_amount="100"))
        self.assertEqual(r["normalized_period_code"],"2022Q1")
        self.assertEqual(r["decision"],"ACCEPT") # no invalid detailed metrics supplied
        self.assertEqual(r["normalized_metrics"]["estimated_sales_amount"],100)
    def test_store_warning_rates_are_preserved(self):
        r=evaluate("store",test_row(store_count="5",similar_industry_store_count="5",
                   opening_rate="200",opened_store_count="1",closure_rate="4800",
                   closed_store_count="1",franchise_store_count="1"))
        self.assertEqual(r["decision"],"WARN")
        self.assertEqual(r["normalized_metrics"]["closure_rate"],"4800")
        self.assertIn("P0-DQ-003_CLOSE_GT_100",r["issue_codes"])
    def test_store_review_overrides_warning(self):
        r=evaluate("store",test_row(store_count="1",similar_industry_store_count="3",
                    opening_rate="200",opened_store_count="2",closure_rate="0",
                    closed_store_count="2",franchise_store_count="2"))
        self.assertEqual(r["decision"],"REVIEW")
        self.assertEqual(r["normalized_metrics"]["store_count"],1)
    def test_reject_and_no_imputation(self):
        r=evaluate("store",test_row(store_count="N/A",similar_industry_store_count="5",
                    opening_rate="200",opened_store_count="1",closure_rate="0",
                    closed_store_count="1",franchise_store_count="0"))
        self.assertEqual(r["decision"],"REJECT")
        self.assertIsNone(r["normalized_metrics"]["store_count"])
    def test_invalid_quarter_reject(self):
        r=evaluate("sales",test_row(base_year_quarter="20225",estimated_sales_amount="5"))
        self.assertEqual(r["decision"],"REJECT")
        self.assertIsNone(r["normalized_period_code"])
    def test_area_gated(self):
        r=evaluate("area",test_row(x_coordinate="190000",y_coordinate="450000",area_size="500"))
        self.assertEqual(r["decision"],"REVIEW")
        self.assertFalse(r["dim_area_eligible"])
        self.assertFalse(r["fact_eligible"])
    def test_determinism(self):
        row=test_row(store_count="1",similar_industry_store_count="1",opening_rate="0",
                     opened_store_count="0",closure_rate="0",closed_store_count="0",
                     franchise_store_count="0")
        self.assertEqual(evaluate("store",row)["result_sha256"],
                         evaluate("store",row)["result_sha256"])

    def test_policy_changes_fail_before_database_connection(self):
        original=json.loads(POLICY_PATH.read_text(encoding="utf-8"))
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/"policy.json"
            path.write_text(json.dumps(original,ensure_ascii=False,indent=4),encoding="utf-8")
            self.assertEqual(load_policy(path),load_policy())
            for change in ("condition", "version", "missing_version"):
                policy=json.loads(json.dumps(original))
                if change=="condition": policy["rules"][0]["condition"]="changed"
                elif change=="version": policy["version"]="0.1.1"
                else: del policy["version"]
                path.write_text(json.dumps(policy,ensure_ascii=False),encoding="utf-8")
                connection=Mock()
                with self.assertRaisesRegex(RuntimeError,"policy validation failed"):
                    run("area","batch",connection_factory=connection,policy_path=path)
                connection.assert_not_called()

    def test_invalid_missing_or_duplicate_policy_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/"policy.json"
            for contents in ('{', '{"version":"0.1.0","version":"0.1.0"}',
                             '{"version":"0.1.0","value":NaN}'):
                path.write_text(contents,encoding="utf-8")
                with self.assertRaisesRegex(RuntimeError,"policy validation failed"):
                    load_policy(path)
            path.unlink()
            with self.assertRaisesRegex(RuntimeError,"policy validation failed"):
                load_policy(path)

    def test_evaluate_rejects_unapproved_policy(self):
        with self.assertRaisesRegex(RuntimeError,"Unapproved"):
            evaluate("sales",test_row(estimated_sales_amount="1"),policy=("0.1.0","other"))

if __name__=="__main__":unittest.main()
