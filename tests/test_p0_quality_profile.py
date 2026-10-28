"""Synthetic-only tests for quality profile rules (no private CSV in GitHub)."""
import csv
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from profile_p0_quality import FILES, profile

HEADER_AREA=["상권_구분_코드","상권_구분_코드_명","상권_코드","상권_코드_명",
"엑스좌표_값","와이좌표_값","자치구_코드","자치구_코드_명","행정동_코드","행정동_코드_명","영역_면적"]
HEADER_COMMON=["기준_년분기_코드","상권_구분_코드","상권_구분_코드_명","상권_코드","상권_코드_명",
"서비스_업종_코드","서비스_업종_코드_명"]
HEADER_SALES=HEADER_COMMON+["당월_매출_금액","당월_매출_건수",
"주중_매출_금액","주말_매출_금액","주중_매출_건수","주말_매출_건수"]
for d in ("월","화","수","목","금","토","일"):
    HEADER_SALES.extend([d+"요일_매출_금액",d+"요일_매출_건수"])
HEADER_SALES+=["시간대_00~06_매출_금액","시간대_건수~06_매출_건수",
"남성_매출_금액","여성_매출_금액","남성_매출_건수","여성_매출_건수",
"연령대_10_매출_금액","연령대_10_매출_건수"]
HEADER_STORE=HEADER_COMMON+["점포_수","유사_업종_점포_수","개업_율","개업_점포_수",
"폐업_률","폐업_점포_수","프랜차이즈_점포_수"]


class ProfileTests(unittest.TestCase):
    def test_detect_nonnegative_rates_and_missing_store_sales(self):
        with tempfile.TemporaryDirectory() as root:
            tmp=Path(root)
            base={"기준_년분기_코드":"20221","상권_구분_코드":"A",
                  "상권_구분_코드_명":"골목상권","상권_코드":"3110001",
                  "상권_코드_명":"한글상권","서비스_업종_코드":"CS100001",
                  "서비스_업종_코드_명":"음식점"}
            area={"상권_구분_코드":"A","상권_구분_코드_명":"골목상권",
                  "상권_코드":"3110001","상권_코드_명":"한글상권",
                  "엑스좌표_값":"190000","와이좌표_값":"450000",
                  "자치구_코드":"11110","자치구_코드_명":"종로구",
                  "행정동_코드":"11110515","행정동_코드_명":"청운효자동","영역_면적":"1000"}
            sales={**{name:"0" for name in HEADER_SALES},**base,
                   "당월_매출_금액":"100","당월_매출_건수":"10",
                   "주중_매출_금액":"100","주중_매출_건수":"10",
                   "월요일_매출_금액":"100","월요일_매출_건수":"10",
                   "시간대_00~06_매출_금액":"100","시간대_건수~06_매출_건수":"10"}
            store={**base,"점포_수":"1","유사_업종_점포_수":"2","개업_율":"200",
                   "개업_점포_수":"2","폐업_률":"4800","폐업_점포_수":"2",
                   "프랜차이즈_점포_수":"0"}
            path=tmp/"fixture.zip"
            with zipfile.ZipFile(path,"w") as archive:
                for kind,header,data in [
                    ("area",HEADER_AREA,area),("sales",HEADER_SALES,sales),
                    ("store",HEADER_STORE,store)]:
                    local=tmp/FILES[kind]
                    with local.open("w",encoding="cp949",newline="") as stream:
                        writer=csv.DictWriter(stream,fieldnames=header)
                        writer.writeheader()
                        writer.writerow(data)
                    archive.write(local,"fixture/1/"+FILES[kind])
            result=profile(path)
            self.assertEqual([result["files"][x]["row_count"] for x in FILES],[1,1,1])
            self.assertEqual(result["files"]["store"]["issues"]["opening_rate_gt_100"],1)
            self.assertEqual(result["files"]["store"]["issues"]["closure_rate_gt_100"],1)
            self.assertEqual(result["files"]["store"]["issues"]["either_rate_gt_100"],1)
            self.assertEqual(result["cross_source"]["store_business_keys_missing_from_sales"],0)
            self.assertEqual(result["files"]["sales"]["issues"].get("days_amount_mismatch",0),0)


if __name__=="__main__":
    unittest.main()
