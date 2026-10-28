import csv
import json
import tempfile
import unittest
import zipfile
from pathlib import Path
from franchise_dw.ingest_p0_csv import SOURCES, InputError, ingest_csv, read_rows, sha256_source

class CsvIngestTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path=Path(self.tmp.name)

    def write_csv(self,kind,extra=None,drop=None):
        cols=list(SOURCES[kind].column_map)
        if drop: cols.remove(drop)
        if extra: cols+=extra
        path=self.path/(kind+".csv")
        data={k:"00001" for k in cols}
        data.update({"상권_코드_명":"종로·청계 관광특구",
                     "당월_매출_금액":"340449266",
                     "개업_율":"200","폐업_률":"4800",
                     "기준_년분기_코드":"20221"})
        with path.open("w",encoding="cp949",newline="") as fp:
            writer=csv.writer(fp)
            writer.writerow(cols)
            writer.writerow([data[k] for k in cols])
        return path

    def test_mapping_preserves_raw_cells(self):
        for kind in SOURCES:
            with self.subTest(kind=kind):
                path=self.write_csv(kind,["당월_매출_건수"] if kind=="sales" else None)
                digest=sha256_source(path,None)
                items=list(read_rows(SOURCES[kind],path,None,digest,"test",None,None))
                self.assertEqual(len(items),1)
                self.assertEqual(items[0]["area_code"],"00001")
                self.assertEqual(json.loads(items[0]["raw_record_text"])["상권_코드_명"],"종로·청계 관광특구")
                if kind=="store":
                    self.assertEqual(items[0]["closure_rate"],"4800")
                if kind=="sales":
                    self.assertEqual(json.loads(items[0]["raw_record_text"])["당월_매출_건수"],"00001")

    def test_zip_selection_is_explicit(self):
        path=self.write_csv("area")
        archive=self.path/"source.zip"
        with zipfile.ZipFile(archive,"w") as z:
            z.write(path,"a/area.csv")
            z.write(path,"b/area.csv")
        with self.assertRaisesRegex(InputError,"zip-member"):
            ingest_csv(kind="area",input_path=archive,dry_run=True)
        result=ingest_csv(kind="area",input_path=archive,zip_member="a/area.csv",dry_run=True)
        self.assertEqual(result["rows_scanned"],1)

    def test_missing_columns_rejected(self):
        path=self.write_csv("sales",drop="당월_매출_금액")
        with self.assertRaisesRegex(InputError,"Missing columns"):
            ingest_csv(kind="sales",input_path=path,dry_run=True)

    def test_dry_run_and_stable_batch(self):
        path=self.write_csv("store")
        first=ingest_csv(kind="store",input_path=path,dry_run=True)
        second=ingest_csv(kind="store",input_path=path,dry_run=True)
        self.assertEqual(first["collection_batch_id"],second["collection_batch_id"])
        self.assertEqual(first["rows_scanned"],1)
        self.assertEqual(first["rows_inserted"],0)

if __name__=="__main__":
    unittest.main()
