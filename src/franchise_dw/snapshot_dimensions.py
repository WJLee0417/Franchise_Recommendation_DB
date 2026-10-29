"""Design/check snapshot keys without creating historical validity timestamps."""
import hashlib
import json
from datetime import date

DOCS={
 "area":("p0-4dd5c697615606676fc0235b9c43","b6281497b242d25569dcf61cc8bd05e80d300101eea5079577e42d0d280bf137",1650),
 "sales":("p0-e0c1f62afc9bd322c42e525e5345","ac2ba3a8f74ec3ccbcb0ca87ba0a9cdb7b1c4cbe21d1f17331d12fa644db786d",125692),
 "store":("p0-271600360236b23608faf2ae6fdf","8f6932112d355554a290b01ca67cd697474107fc6ad478a23b499a742cc98561",457043)
}
def snapshot_id(kind,digest):
 if kind not in DOCS or len(digest)!=64 or any(c not in "0123456789abcdef" for c in digest):
  raise ValueError("Invalid audited source")
 return hashlib.sha256(("P0-SNAPSHOT-v1:"+kind+":"+digest).encode()).hexdigest()

def quarter(code):
 if len(code)!=6 or code[4]!="Q" or not code[:4].isdigit() or code[5] not in "1234":
  raise ValueError("Invalid source calendar quarter")
 y=int(code[:4]);q=int(code[5])
 if not 1900<=y<=2099:raise ValueError("Quarter out of source range")
 m=(q-1)*3+1
 start=date(y,m,1)
 end_exclusive=date(y+1,1,1) if q==4 else date(y,m+3,1)
 return start,end_exclusive

def make_evidence():
 return [{"source_kind":k,"batch":b,"document_sha256":d,"source_document_id":"sha256:"+d,
          "expected_rows":n,"snapshot_id":snapshot_id(k,d)}
         for k,(b,d,n) in DOCS.items()]
