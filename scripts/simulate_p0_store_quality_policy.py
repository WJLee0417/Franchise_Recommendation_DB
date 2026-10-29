"""Read-only simulation of corrected historical STORE quality semantics.

Uses original archived /1/ CP949 CSV. Does not change SRC/STG/FACT.
"""
import argparse,csv,hashlib,io,json,zipfile
from collections import Counter
from pathlib import Path
SUFFIX="/1/서울시 상권분석서비스(점포-상권).csv"
SHA="8f6932112d355554a290b01ca67cd697474107fc6ad478a23b499a742cc98561"
def status(row,corrected=False):
 ordinary=int(row["점포_수"]);franchise=int(row["프랜차이즈_점포_수"])
 total=int(row["유사_업종_점포_수"]);opened=int(row["개업_점포_수"]);closed=int(row["폐업_점포_수"])
 op=float(row["개업_율"]);cl=float(row["폐업_률"])
 base=total if corrected else ordinary
 warn=(op>100 or cl>100) or (not corrected and total>ordinary)
 review=(base==0 and (opened or closed)) or (opened>base or closed>base) or (op==0 and opened>0) or (cl==0 and closed>0) or (not corrected and franchise>ordinary)
 return "REVIEW" if review else ("WARN" if warn else "ACCEPT")
def analyze(path):
 with zipfile.ZipFile(path) as z:
  members=[x for x in z.namelist() if x.endswith(SUFFIX)]
  if len(members)!=1:raise ValueError("Must have exactly one audited /1/ STORE CSV")
  name=members[0]
  with z.open(name) as f:
   h=hashlib.sha256()
   for block in iter(lambda:f.read(1048576),b""):h.update(block)
  if h.hexdigest()!=SHA:raise ValueError("Source checksum differs from audited file")
  old=Counter();new=Counter();change=Counter();invariant=Counter()
  with z.open(name) as raw,io.TextIOWrapper(raw,encoding="cp949",newline="") as f:
   for row in csv.DictReader(f):
    ordinary=int(row["점포_수"]);franchise=int(row["프랜차이즈_점포_수"])
    total=int(row["유사_업종_점포_수"])
    invariant["rows"]+=1;invariant["equality"]+=(total==ordinary+franchise)
    invariant["total_gt_ordinary"]+=(total>ordinary)
    invariant["franchise_gt_ordinary"]+=(franchise>ordinary)
    a=status(row);b=status(row,corrected=True);old[a]+=1;new[b]+=1
    if a!=b:change[a+"->"+b]+=1
 if invariant["rows"]!=457043 or invariant["equality"]!=457043:raise AssertionError("Historical data invariant fails")
 if old!=Counter({"ACCEPT":383390,"WARN":49873,"REVIEW":23780}):raise AssertionError("v0.1 decisions drift")
 return {"source_sha256":SHA,"invariants":dict(invariant),"original_v0_1":dict(old),
 "unapproved_v0_2_simulation":dict(new),"transitions":dict(change),
 "warning":"Read-only simulation; no original data or quality decisions changed"}
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument("--zip",required=True,type=Path);p.add_argument("--output",required=True,type=Path)
 a=p.parse_args();r=analyze(a.zip)
 a.output.parent.mkdir(parents=True,exist_ok=True)
 a.output.write_text(json.dumps(r,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 print(json.dumps(r,ensure_ascii=False))
if __name__=="__main__":main()
