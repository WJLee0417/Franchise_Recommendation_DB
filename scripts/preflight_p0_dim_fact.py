"""Phase 3-5-1 read-only MySQL evidence collection. NEVER writes DIM/FACT/SRC/STG.

PYTHONPATH=src python scripts/preflight_p0_dim_fact.py --output data/local/phase35_preflight.json
Requires the original 3 batch IDs in franchise_dw_p0. Outputs aggregates only.
"""
import argparse
import json
from pathlib import Path
from franchise_dw.ingest_p0_csv import connect_db

BATCH={
 "area":("SRC_SEOUL_AREA","p0-4dd5c697615606676fc0235b9c43",1650),
 "sales":("SRC_SEOUL_SALES","p0-e0c1f62afc9bd322c42e525e5345",125692),
 "store":("SRC_SEOUL_STORE","p0-271600360236b23608faf2ae6fdf",457043)}
def scalar(cur,sql,args=()):
 cur.execute(sql,args);return cur.fetchone()[0]

def collect(connection):
 data={"status":"HOLD_FACT_LOADING","sources":{},"checks":{},"gate_failures":[]}
 with connection.cursor() as c:
  for kind,(table,batch,expected) in BATCH.items():
   count=scalar(c,f"SELECT COUNT(*) FROM {table} WHERE collection_batch_id=%s",(batch,))
   stages=scalar(c,"SELECT COUNT(*) FROM STG_P0_QUALITY WHERE source_kind=%s AND source_batch_id=%s",(kind,batch))
   duplicate=0
   if kind!="area":
    dup_sql=f"SELECT COUNT(*) FROM (SELECT base_year_quarter,area_code,service_industry_code FROM {table} WHERE collection_batch_id=%s GROUP BY base_year_quarter,area_code,service_industry_code HAVING COUNT(*)>1) AS x"
   else:
    dup_sql=f"SELECT COUNT(*) FROM (SELECT area_code FROM {table} WHERE collection_batch_id=%s GROUP BY area_code HAVING COUNT(*)>1) AS x"
   duplicate=scalar(c,dup_sql,(batch,))
   data["sources"][kind]={"src_rows":count,"staged_rows":stages,"expected":expected,"duplicate_business_keys":duplicate}
   if (count,stages,duplicate)!=(expected,expected,0):
    data["gate_failures"].append(f"SRC_STAGE_{kind.upper()}_COUNT_OR_UNIQUE")
  a=BATCH["area"][1];s=BATCH["sales"][1];t=BATCH["store"][1]
  data["checks"]["sales_area_unmatched"]=scalar(c,"SELECT COUNT(*) FROM SRC_SEOUL_SALES s LEFT JOIN SRC_SEOUL_AREA a ON a.area_code=s.area_code AND a.collection_batch_id=%s WHERE s.collection_batch_id=%s AND a.source_row_id IS NULL",(a,s))
  data["checks"]["store_area_unmatched"]=scalar(c,"SELECT COUNT(*) FROM SRC_SEOUL_STORE s LEFT JOIN SRC_SEOUL_AREA a ON a.area_code=s.area_code AND a.collection_batch_id=%s WHERE s.collection_batch_id=%s AND a.source_row_id IS NULL",(a,t))
  data["checks"]["sales_without_store"]=scalar(c,"SELECT COUNT(*) FROM SRC_SEOUL_SALES s LEFT JOIN SRC_SEOUL_STORE t ON t.collection_batch_id=%s AND t.base_year_quarter=s.base_year_quarter AND t.area_code=s.area_code AND t.service_industry_code=s.service_industry_code WHERE s.collection_batch_id=%s AND t.source_row_id IS NULL",(t,s))
  data["checks"]["store_without_sales"]=scalar(c,"SELECT COUNT(*) FROM SRC_SEOUL_STORE t LEFT JOIN SRC_SEOUL_SALES s ON s.collection_batch_id=%s AND s.base_year_quarter=t.base_year_quarter AND s.area_code=t.area_code AND s.service_industry_code=t.service_industry_code WHERE t.collection_batch_id=%s AND s.source_row_id IS NULL",(s,t))
  for kind in ("area","sales","store"):
   batch=BATCH[kind][1]
   c.execute("SELECT decision,COUNT(*) FROM STG_P0_QUALITY WHERE source_kind=%s AND source_batch_id=%s GROUP BY decision",(kind,batch))
   data["sources"][kind]["decisions"]=dict(c.fetchall())
  data["checks"]["dim_fact_nonempty_tables"]=scalar(c,"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_type='BASE TABLE' AND (table_name LIKE 'DIM\\_%' OR table_name LIKE 'FACT\\_%')") # number of objects, not rows
  data["checks"]["stg_eligible_rows"]=scalar(c,"SELECT COUNT(*) FROM STG_P0_QUALITY WHERE (source_kind='area' AND source_batch_id=%s OR source_kind='sales' AND source_batch_id=%s OR source_kind='store' AND source_batch_id=%s) AND (dim_area_eligible<>0 OR fact_eligible<>0)",(a,s,t))
  c.execute("SELECT CHECK_CLAUSE FROM information_schema.check_constraints WHERE constraint_schema=DATABASE() AND constraint_name IN ('ck_fast_open','ck_fast_close') ORDER BY constraint_name")
  data["checks"]["store_rate_check_clauses"]=[row[0] for row in c.fetchall()]
 for key in ("sales_area_unmatched","store_area_unmatched","sales_without_store","stg_eligible_rows"):
  if data["checks"][key]!=0:data["gate_failures"].append(key)
 if data["checks"]["store_without_sales"]!=331351:data["gate_failures"].append("store_without_sales_count_drift")
 if len(data["checks"]["store_rate_check_clauses"])!=2:data["gate_failures"].append("rate_constraint_missing")
 # Even if all technical checks pass, missing official area/industry source versions
 # and observation period semantics must never be auto-approved by this script.
 data["technical_preflight_pass"]=not data["gate_failures"]
 data["can_load_dim_fact"]=False
 data["mandatory_external_evidence"]=["area SCD version + effective date","Seoul industry classification version + effective date","store observation-period semantics","lineage bridge and target grain policy"]
 return data

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument("--output",required=True,type=Path)
 args=p.parse_args()
 with connect_db() as conn:r=collect(conn)
 args.output.parent.mkdir(parents=True,exist_ok=True)
 args.output.write_text(json.dumps(r,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 print(json.dumps({"technical_preflight_pass":r["technical_preflight_pass"],"can_load_dim_fact":False,"gate_failures":r["gate_failures"]},ensure_ascii=False))
 if r["gate_failures"]:raise SystemExit(2)
if __name__=="__main__":main()
