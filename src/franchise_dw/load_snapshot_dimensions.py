"""Build source-snapshot DIMs from audited SRC, without SCD or FACT writes.

Run once on an isolated schema with migration 007:
  PYTHONPATH=src python -m franchise_dw.load_snapshot_dimensions
All writes are a single transaction. Re-running identical sources is idempotent.
"""
from __future__ import annotations
import argparse
from collections import defaultdict
from decimal import Decimal
from franchise_dw.ingest_p0_csv import connect_db
from franchise_dw.snapshot_dimensions import DOCS,make_evidence,quarter

KIND_TABLE={"area":"SRC_SEOUL_AREA","sales":"SRC_SEOUL_SALES","store":"SRC_SEOUL_STORE"}
EXPECTED_PERIODS={f"{year}Q{q}" for year,quarters in ((2022,(1,2,3,4)),(2023,(1,2))) for q in quarters}
SCOPE="SEOUL_100_ARCHIVED_2022Q1_2023Q2_UNDATED"

def run(connection):
 evidence=make_evidence()
 snapshots={e["source_kind"]:e["snapshot_id"] for e in evidence}
 conn=connection
 with conn.cursor() as cur:
  for e in evidence:
   kind=e["source_kind"];table=KIND_TABLE[kind];batch=e["batch"];doc=e["source_document_id"]
   cur.execute(f"SELECT COUNT(*),COUNT(DISTINCT source_record_path) FROM {table} WHERE collection_batch_id=%s AND source_document_id=%s",(batch,doc))
   rows,paths=cur.fetchone()
   if rows!=e["expected_rows"] or paths!=rows:
    raise ValueError(f"{kind}: original document count/path drift {rows}/{paths}")
   cur.execute("SELECT COUNT(*) FROM STG_P0_QUALITY WHERE source_kind=%s AND source_batch_id=%s AND source_document_id=%s",(kind,batch,doc))
   if cur.fetchone()[0]!=rows:raise ValueError(f"{kind}: staging mismatch")
  cur.execute("SELECT COUNT(*) FROM SNAP_SOURCE_DOCUMENT")
  existing=cur.fetchone()[0]
  if existing:
   if existing!=3:raise ValueError("unexpected snapshot inventory; refuse to merge")
   for e in evidence:
    cur.execute("SELECT source_kind,source_batch_id,source_document_id,source_sha256,expected_rows FROM SNAP_SOURCE_DOCUMENT WHERE snapshot_id=%s",(e["snapshot_id"],))
    row=cur.fetchone()
    if row!=(e["source_kind"],e["batch"],e["source_document_id"],e["document_sha256"],e["expected_rows"]):
     raise ValueError("snapshot inventory has changed")
   expected={"SNAP_AREA":1650,"SNAP_PERIOD":6,"SNAP_INDUSTRY":100,"SNAP_INDUSTRY_SOURCE":163}
   for table,n in expected.items():
    cur.execute(f"SELECT COUNT(*) FROM {table}")
    if cur.fetchone()[0]!=n:raise ValueError(f"{table}: partial/inconsistent snapshot")
   return {"replayed":True,**expected}
  for e in evidence:
   cur.execute("INSERT INTO SNAP_SOURCE_DOCUMENT(snapshot_id,source_kind,source_batch_id,source_document_id,source_sha256,expected_rows,source_scope) VALUES(%s,%s,%s,%s,%s,%s,%s)",
   (e["snapshot_id"],e["source_kind"],e["batch"],e["source_document_id"],e["document_sha256"],e["expected_rows"],SCOPE))
  periods=set()
  names={}
  counts=defaultdict(int)
  for kind in ("sales","store"):
   e=next(x for x in evidence if x["source_kind"]==kind)
   cur.execute(f"SELECT base_year_quarter,service_industry_code,service_industry_name,COUNT(*) FROM {KIND_TABLE[kind]} WHERE collection_batch_id=%s AND source_document_id=%s GROUP BY base_year_quarter,service_industry_code,service_industry_name",(e["batch"],e["source_document_id"]))
   for period,code,name,n in cur.fetchall():
    p=period[:4]+"Q"+period[4:] if len(period)==5 else period
    quarter(p)
    periods.add(p)
    if not code or not name or (code in names and names[code]!=name):
     raise ValueError(f"industry code/name conflict for {code}")
    names[code]=name
    counts[(kind,code)]+=n
  if periods!=EXPECTED_PERIODS or len(names)!=100 or len({c for k,c in counts if k=="sales"})!=63:
   raise ValueError("historical period/industry coverage changed")
  for p in sorted(periods):
   start,end=quarter(p)
   cur.execute("INSERT INTO SNAP_PERIOD(period_code,base_year,quarter_no,period_start,period_end_exclusive) VALUES(%s,%s,%s,%s,%s)",(p,int(p[:4]),int(p[-1]),start,end))
  for code,name in sorted(names.items()):
   cur.execute("INSERT INTO SNAP_INDUSTRY(service_industry_code,service_industry_name,taxonomy_scope) VALUES(%s,%s,%s)",(code,name,SCOPE))
  for (kind,code),n in sorted(counts.items()):
   cur.execute("INSERT INTO SNAP_INDUSTRY_SOURCE(snapshot_id,service_industry_code,rows_observed,taxonomy_scope) VALUES(%s,%s,%s,%s)",(snapshots[kind],code,n,SCOPE))
  area_e=next(x for x in evidence if x["source_kind"]=="area")
  cur.execute("SELECT source_row_id,area_code,area_name,area_type_code,area_type_name,district_code,district_name,dong_code,dong_name,x_coordinate,y_coordinate,area_size FROM SRC_SEOUL_AREA WHERE collection_batch_id=%s AND source_document_id=%s ORDER BY source_row_id",(area_e["batch"],area_e["source_document_id"]))
  area_rows=cur.fetchall()
  if len(area_rows)!=1650 or len({r[1] for r in area_rows})!=1650:raise ValueError("area grain drift")
  insert="INSERT INTO SNAP_AREA(snapshot_id,source_row_id,area_code,area_name,area_type_code,area_type_name,district_code,district_name,dong_code,dong_name,x_coordinate,y_coordinate,area_size) VALUES("+",".join(["%s"]*13)+")"
  for row in area_rows:
   rid,code,name,typ,typname,dcode,dname,dong,dongname,x,y,area=row
   if any(v is None or not str(v).strip() for v in (code,name,typ,typname,dcode,dname,dong,dongname)):
    raise ValueError("area has blank required dimension field")
   cur.execute(insert,(snapshots["area"],rid,code,name,typ,typname,dcode,dname,dong,dongname,
                      str(Decimal(x)) if x is not None else None,
                      str(Decimal(y)) if y is not None else None,
                      str(Decimal(area)) if area is not None else None))
  expected={"SNAP_AREA":1650,"SNAP_PERIOD":6,"SNAP_INDUSTRY":100,"SNAP_INDUSTRY_SOURCE":163}
  for table,n in expected.items():
   cur.execute(f"SELECT COUNT(*) FROM {table}")
   if cur.fetchone()[0]!=n:raise ValueError(f"{table}: expected {n}")
 return {"replayed":False,**expected}

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument("--dry-run",action="store_true",help="rollback after validation and insert tests")
 args=p.parse_args()
 c=connect_db()
 try:
  result=run(c)
  if args.dry_run:c.rollback()
  else:c.commit()
  print({"dry_run":args.dry_run,**result})
 except BaseException:
  c.rollback()
  raise
 finally:c.close()

if __name__=="__main__":main()
