"""Actual MySQL 8 integration: staging inserts, decisions, safe rerun and no DIM/FACT writes."""
import json
import tempfile
from pathlib import Path
from franchise_dw.ingest_p0_csv import connect_db
from franchise_dw.transform_p0_quality import POLICY_PATH, run

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
    test_policy_drift()


def test_policy_drift():
    batch="phase3-4-policy-drift-synthetic"
    with connect_db() as conn:
        with conn.cursor() as cur:
            for i in range(2):
                cur.execute("INSERT INTO SRC_SEOUL_AREA (collection_batch_id,source_document_id,"
                            "source_record_path,raw_record_text,area_code,area_type_code,"
                            "x_coordinate,y_coordinate,area_size) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)",
                            (batch,"synthetic",f"drift/{i}","{}",f"0000{i}","A","1","2","3"))
        conn.commit()
    with tempfile.TemporaryDirectory() as folder:
        path=Path(folder)/"policy.json"
        baseline=POLICY_PATH.read_text(encoding="utf-8")
        policy=json.loads(baseline)
        policy["rules"][0]["condition"]="modified policy condition"
        changed=json.dumps(policy,ensure_ascii=False)
        path.write_text(baseline,encoding="utf-8")

        class ChangeAfterFirstChunk:
            def __init__(self): self.conn=connect_db(); self.commits=0
            def cursor(self): return self.conn.cursor()
            def rollback(self): self.conn.rollback()
            def close(self): self.conn.close()
            def commit(self):
                self.conn.commit(); self.commits+=1
                if self.commits==2: path.write_text(changed,encoding="utf-8")

        try:
            run("area",batch,chunk=1,connection_factory=ChangeAfterFirstChunk,policy_path=path)
            raise AssertionError("policy drift during a run was not detected")
        except RuntimeError as exc:
            assert "policy validation failed" in str(exc),exc
        with connect_db() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT status FROM DQ_P0_RUN WHERE source_batch_id=%s",(batch,))
                assert cur.fetchall()==(("FAILED",),)
                cur.execute("SELECT COUNT(*) FROM STG_P0_QUALITY WHERE source_batch_id=%s",(batch,))
                assert cur.fetchone()[0]==1
        path.write_text(baseline,encoding="utf-8")
        assert run("area",batch,chunk=1,policy_path=path)["processed"]==2
        with connect_db() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT * FROM STG_P0_QUALITY WHERE source_batch_id=%s ORDER BY source_row_id",(batch,))
                before=cur.fetchall()
                cur.execute("SELECT COUNT(*) FROM DQ_P0_RUN WHERE source_batch_id=%s",(batch,))
                runs_before=cur.fetchone()[0]
        for drift in (changed, json.dumps({**json.loads(baseline),"version":"0.1.1"},ensure_ascii=False)):
            path.write_text(drift,encoding="utf-8")
            try:
                run("area",batch,chunk=1,policy_path=path)
                raise AssertionError("policy change was not rejected")
            except RuntimeError as exc:
                assert "policy validation failed" in str(exc),exc
        with connect_db() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT * FROM STG_P0_QUALITY WHERE source_batch_id=%s ORDER BY source_row_id",(batch,))
                assert cur.fetchall()==before
                cur.execute("SELECT COUNT(*) FROM DQ_P0_RUN WHERE source_batch_id=%s",(batch,))
                assert cur.fetchone()[0]==runs_before
        path.write_text(baseline,encoding="utf-8")
        assert run("area",batch,chunk=1,policy_path=path)["processed"]==2
        with connect_db() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT * FROM STG_P0_QUALITY WHERE source_batch_id=%s ORDER BY source_row_id",(batch,))
                assert cur.fetchall()==before
    print("PASS MySQL policy drift: preflight rejection, mid-run rollback, recovery, unchanged replay")

if __name__=="__main__":main()
