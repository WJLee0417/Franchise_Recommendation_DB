import unittest
from franchise_dw.transform_p0_quality import evaluate, decimal_value

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

if __name__=="__main__":unittest.main()
