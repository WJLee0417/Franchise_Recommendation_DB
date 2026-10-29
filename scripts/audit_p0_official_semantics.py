"""Audit original archived P0 industry code stability and STORE metric semantics.

Produces aggregate-only JSON. Official reference:
https://data.seoul.go.kr/dataList/OA-15577/S/1/datasetView.do
This is a source-schema audit, NOT a historical classification version proof.
"""
import argparse
import csv
import hashlib
import io
import json
import zipfile
from collections import Counter, defaultdict
from pathlib import Path

FILES={
 "area":("서울시 상권분석서비스(영역-상권).csv","b6281497b242d25569dcf61cc8bd05e80d300101eea5079577e42d0d280bf137"),
 "sales":("서울시 상권분석서비스(추정매출-상권).csv","ac2ba3a8f74ec3ccbcb0ca87ba0a9cdb7b1c4cbe21d1f17331d12fa644db786d"),
 "store":("서울시 상권분석서비스(점포-상권).csv","8f6932112d355554a290b01ca67cd697474107fc6ad478a23b499a742cc98561"),
}
QUARTERS={"20221","20222","20223","20224","20231","20232"}

def audit_archive(path,strict_hash=True):
 result={"scope":"audited historical 2022Q1..2023Q2 Seoul P0 archive","source_sha256_verified":strict_hash,
         "area":{},"industry":{},"store":{},"area_version_verified":False,"historical_taxonomy_effective_date_verified":False,
         "store_observation_date_verified":False}
 with zipfile.ZipFile(path) as archive:
  for kind,(name,expected_hash) in FILES.items():
   options=[x for x in archive.namelist() if x.endswith("/1/"+name)]
   if len(options)!=1:raise ValueError(f"{kind}: expected exactly one original /1/ entry; got {len(options)}")
   filename=options[0]
   if strict_hash:
    with archive.open(filename) as f:
     digest=hashlib.sha256()
     for chunk in iter(lambda:f.read(1048576),b""):digest.update(chunk)
    if digest.hexdigest()!=expected_hash:raise ValueError(f"{kind}: source sha256 mismatch")
   count=0
   code_names=defaultdict(set)
   codes_per_q=defaultdict(set)
   labels_by_area=defaultdict(set)
   store_stats=Counter()
   with archive.open(filename) as raw,io.TextIOWrapper(raw,encoding="cp949",errors="strict",newline="") as stream:
    for row in csv.DictReader(stream):
     count+=1
     if kind=="area":
      labels_by_area[row["상권_코드"]].add(row["상권_코드_명"])
     else:
      quarter=row["기준_년분기_코드"]
      if quarter not in QUARTERS:raise ValueError(f"{kind}: quarter outside verified archive")
      code=row["서비스_업종_코드"]
      code_names[code].add(row["서비스_업종_코드_명"])
      codes_per_q[quarter].add(code)
     if kind=="store":
      ordinary=int(row["점포_수"])
      franchised=int(row["프랜차이즈_점포_수"])
      archived_total=int(row["유사_업종_점포_수"])
      store_stats["total_invariant_pass"]+=archived_total==ordinary+franchised
      store_stats["total_invariant_fail"]+=archived_total!=ordinary+franchised
      store_stats["archived_total_gt_ordinary"]+=archived_total>ordinary
      store_stats["franchised_gt_ordinary"]+=franchised>ordinary
   result[kind]["rows"]=count
   if kind=="area":
    result["area"].update({"rows":count,"unique_codes":len(labels_by_area),
      "multiple_names_for_same_code":sum(len(x)>1 for x in labels_by_area.values()),
      "has_effective_date_in_source":False,"has_polygon_version_in_source":False})
   else:
    result["industry"][kind]={"unique_codes":len(code_names),
       "one_code_multiple_names":sum(len(x)>1 for x in code_names.values()),
       "counts_by_quarter":{q:len(codes_per_q[q]) for q in sorted(QUARTERS)},
       "category_counts":dict(sorted(Counter(k[:5] for k in code_names).items())),
       "code_to_name":{k:next(iter(v)) for k,v in sorted(code_names.items())}}
   if kind=="store":result["store"].update(store_stats)
  sc=result["industry"]["sales"]["code_to_name"]
  tc=result["industry"]["store"]["code_to_name"]
  result["industry"]["sales_not_in_store"] = len(set(sc)-set(tc))
  result["industry"]["cross_source_name_conflicts"]=sum(sc[k]!=tc[k] for k in sc if k in tc)
  # Official portal states 'total stores = ordinary stores + franchise stores';
  # historical CSV field '유사_업종_점포_수' satisfies that equality for ALL source rows.
  result["store"]["historical_field_mapping_candidate"]={
    "점포_수":"ordinary_store_count","프랜차이즈_점포_수":"franchise_store_count",
    "유사_업종_점포_수":"total_store_count"}
  result["store"]["mapping_supported_by_all_rows"]=(
   result["store"]["total_invariant_fail"]==0 and result["store"]["total_invariant_pass"]==result["store"]["rows"])
  return result

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument("--zip",required=True,type=Path)
 p.add_argument("--output",required=True,type=Path)
 args=p.parse_args()
 r=audit_archive(args.zip)
 args.output.parent.mkdir(parents=True,exist_ok=True)
 args.output.write_text(json.dumps(r,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 print(json.dumps({ "source_rows":{k:r[k]["rows"] for k in FILES},
   "store_total_invariant_fail":r["store"]["total_invariant_fail"],
   "industry_code_name_conflicts":r["industry"]["cross_source_name_conflicts"]},ensure_ascii=False))
if __name__=="__main__":main()
