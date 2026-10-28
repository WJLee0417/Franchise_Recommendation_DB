"""Actual MySQL 8 integration: staging inserts, decisions, safe rerun and no DIM/FACT writes."""
from franchise_dw.ingest_p0_csv import connect_db
from franchise_dw.transform_p0_quality import run

BATCH="phase3-4-ci-synthetic"
def source(table, path, **values):
    columns=["collection_batch_id","source_document_id","source_record_path","raw_record_text",*values]
    args=[BATCH,"synthetic-doc",path,values.pop("raw_record_text","{}"),*values.values()]
    with connect_db() as conn:
        with conn.cursor() as cur:
            cur.execute(f"INSERT INTO {table} ("+",".join(columns)+") VALUES ("+
                        ",".join(["%s"]*len(columns))+")",args)
        conn.commit()

def main():
    source("SRC_SEOUL_AREA","area/1",area_code="00001",area_type_code="A",
           x_coordinate="190000",y_coordinate="450000",area_size="2500")
    source("SRC_SEOUL_SALES","sales/1",base_year_quarter="20221",area_code="00001",
           area_type_code="A",service_industry_code="CS100001",
           estimated_sales_amount="123456")
    source("SRC_SEOUL_STORE","store/1",base_year_quarter="20221",area_code="00001",
           area_type_code="A",service_industry_code="CS100001",
           store_count="5",similar_industry_store_count="5",
           opening_rate="200",opened_store_count="1",
           closure_rate="4800",closed_store_count="1",franchise_store_count="0")
    source("SRC_SEOUL_STORE","store/2",base_year_quarter="20221",area_code="00002",
           area_type_code="A",service_industry_code="CS100001",
           store_count="3",similar_industry_store_count="2",
           opening_rate="-1",opened_store_count="0",
           closure_rate="0",closed_store_count="0",franchise_store_count="0")
    expected={"area":(1,{"REVIEW":1}),
              "sales":(1,{"ACCEPT":1}),
              "store":(2,{"WARN":1,"REJECT":1})}
    for kind,(count,statuses) in expected.items():
        first=run(kind,BATCH,chunk=1)
        assert first["processed"]==count,first
        assert first["decisions"]==statuses,first
        second=run(kind,BATCH,chunk=2)
        assert second["decisions"]==statuses,second
        print("PASS",kind,first["decisions"],"rerun hash stable")
    with connect_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT source_kind,decision,COUNT(*) FROM STG_P0_QUALITY GROUP BY source_kind,decision")
            assert sorted(cur.fetchall())==sorted([
                ("area","REVIEW",1),("sales","ACCEPT",1),
                ("store","REJECT",1),("store","WARN",1)])
            cur.execute("SELECT COUNT(*) FROM V_P0_QUALITY_QUARANTINE")
            assert cur.fetchone()[0]==2
            cur.execute("SELECT COUNT(*) FROM STG_P0_QUALITY WHERE dim_area_eligible<>0 OR fact_eligible<>0")
            assert cur.fetchone()[0]==0
            cur.execute("SELECT COUNT(*) FROM DIM_AREA")
            assert cur.fetchone()[0]==0
            cur.execute("SELECT COUNT(*) FROM FACT_AREA_STORE")
            assert cur.fetchone()[0]==0
    print("PASS MySQL P0 quality staging: ACCEPT/WARN/REVIEW/REJECT, replay, gating")

if __name__=="__main__":main()
