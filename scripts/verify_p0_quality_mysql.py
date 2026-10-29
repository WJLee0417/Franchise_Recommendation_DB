"""Run and independently verify all 584,385 ORIGINAL P0 SRC rows in MySQL 8.

Never publishes source rows. Requires schema migration 005 and the previously
verified historic ZIP batches already loaded into SRC. Does not touch DIM/FACT.
Run: PYTHONPATH=src python scripts/verify_p0_quality_mysql.py --report data/local/p0_dq_mysql.json
"""
import argparse
import hashlib
import json
import time
from collections import Counter
from datetime import datetime
from pathlib import Path

from franchise_dw.ingest_p0_csv import connect_db
from franchise_dw.transform_p0_quality import TABLES, evaluate, run

ORIGINAL = {
    "area": {"batch_id": "p0-4dd5c697615606676fc0235b9c43", "rows": 1650,
             "source_hash": "b6281497b242d25569dcf61cc8bd05e80d300101eea5079577e42d0d280bf137",
             "decisions": {"ACCEPT": 0, "WARN": 0, "REVIEW": 1650, "REJECT": 0}},
    "sales": {"batch_id": "p0-e0c1f62afc9bd322c42e525e5345", "rows": 125692,
              "source_hash": "ac2ba3a8f74ec3ccbcb0ca87ba0a9cdb7b1c4cbe21d1f17331d12fa644db786d",
              "decisions": {"ACCEPT": 51974, "WARN": 73714, "REVIEW": 4, "REJECT": 0}},
    "store": {"batch_id": "p0-271600360236b23608faf2ae6fdf", "rows": 457043,
              "source_hash": "8f6932112d355554a290b01ca67cd697474107fc6ad478a23b499a742cc98561",
              "decisions": {"ACCEPT": 383390, "WARN": 49873, "REVIEW": 23780, "REJECT": 0}},
}


def count_analytic_rows(conn):
    with conn.cursor() as c:
        c.execute("SELECT TABLE_NAME FROM information_schema.TABLES "
                  "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE='BASE TABLE' "
                  "AND (TABLE_NAME LIKE 'DIM\\_%' OR TABLE_NAME LIKE 'FACT\\_%')")
        names=[r[0] for r in c.fetchall()]
        if len(names)!=28:
            raise RuntimeError("Expected 28 DIM/FACT tables; database/schema selection may be wrong")
        result={}
        for table in names:
            c.execute("SELECT COUNT(*) FROM `"+table+"`")
            result[table]=c.fetchone()[0]
        return result


def stage_fingerprint(conn,kind,batch):
    sha=hashlib.sha256()
    with conn.cursor() as c:
        c.execute("SELECT source_row_id,result_sha256,written_at "
                  "FROM STG_P0_QUALITY WHERE source_kind=%s AND source_batch_id=%s "
                  "ORDER BY source_row_id",(kind,batch))
        while chunk:=c.fetchmany(3000):
            for rowid,result_sha,ts in chunk:
                sha.update(f"{rowid}:{result_sha}:{ts.isoformat() if isinstance(ts,datetime) else ts}\n".encode())
    return sha.hexdigest()


def verify_one(conn,kind,config,chunk_size):
    table=TABLES[kind]
    batch=config["batch_id"]
    source_hash=config["source_hash"]
    expected=config["rows"]
    counts=Counter()
    rules=Counter()
    count=0
    with conn.cursor() as cursor:
        cursor.execute(f"SELECT COUNT(*),COUNT(DISTINCT source_record_path) "
                       f"FROM {table} WHERE collection_batch_id=%s AND source_document_id=%s",
                       (batch,"sha256:"+source_hash))
        actual,paths=cursor.fetchone()
        if actual!=expected or paths!=expected:
            raise AssertionError(f"{kind}: SRC batch count/path count {actual}/{paths} != {expected}")
        cursor.execute("SELECT COUNT(*) FROM STG_P0_QUALITY "
                       "WHERE source_kind=%s AND source_batch_id=%s",(kind,batch))
        staged=cursor.fetchone()[0]
        if staged!=expected:
            raise AssertionError(f"{kind}: staged count {staged} != {expected}")
        last_id=0
        while True:
            cursor.execute(f"SELECT * FROM {table} WHERE collection_batch_id=%s "
                           "AND source_row_id>%s ORDER BY source_row_id LIMIT %s",
                           (batch,last_id,chunk_size))
            cols=[x[0] for x in cursor.description]
            values=cursor.fetchall()
            if not values:
                break
            raws=[dict(zip(cols,r)) for r in values]
            ids=[r["source_row_id"] for r in raws]
            cursor.execute("SELECT source_row_id,source_batch_id,source_document_id,"
                           "source_record_path,source_raw_sha256,rule_version,decision,"
                           "issue_codes,normalized_period_code,area_code,industry_code,"
                           "area_type_code,normalized_metrics,dim_area_eligible,"
                           "fact_eligible,result_sha256 FROM STG_P0_QUALITY WHERE "
                           "source_kind=%s AND source_row_id IN ("
                           + ",".join(["%s"]*len(ids))+")",(kind,*ids))
            fieldnames=[c[0] for c in cursor.description]
            staged_by_id={r[0]:dict(zip(fieldnames,r)) for r in cursor.fetchall()}
            if len(staged_by_id)!=len(ids):
                raise AssertionError(f"{kind}: missing staging rows in chunk ending {ids[-1]}")
            for raw in raws:
                rid=raw["source_row_id"]
                if raw["source_document_id"]!="sha256:"+source_hash:
                    raise AssertionError(f"{kind}: incorrect original source hash in row {rid}")
                predicted=evaluate(kind,raw)
                observed=staged_by_id[rid]
                for key in ("source_batch_id","source_document_id","source_record_path",
                            "source_raw_sha256","rule_version","decision",
                            "normalized_period_code","area_code","industry_code",
                            "area_type_code","result_sha256"):
                    if observed[key]!=predicted[key]:
                        raise AssertionError(f"{kind} {rid}: {key} mismatch")
                for key in ("issue_codes","normalized_metrics"):
                    val=observed[key]
                    if isinstance(val,str): val=json.loads(val)
                    if val!=predicted[key]:
                        raise AssertionError(f"{kind} {rid}: {key} mismatch")
                if observed["dim_area_eligible"]!=0 or observed["fact_eligible"]!=0:
                    raise AssertionError(f"{kind} {rid}: premature DIM/FACT eligibility")
                counts[predicted["decision"]]+=1
                rules.update(predicted["issue_codes"])
                count+=1
            last_id=ids[-1]
    assert count==expected,(kind,count,expected)
    decisions={key:counts[key] for key in ("ACCEPT","WARN","REVIEW","REJECT")}
    if decisions!=config["decisions"]:
        raise AssertionError(f"{kind}: decision distribution drift: {decisions}")
    return {"source_rows":count,"staged_rows":staged,"decisions":decisions,
            "issue_counts":dict(rules),"all_rows_source_stage_exact":True}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report",required=True,type=Path)
    parser.add_argument("--verify-only",action="store_true",
                        help="Verify an already completed staging run without writing")
    parser.add_argument("--chunk-size",type=int,default=500)
    args=parser.parse_args()
    if args.chunk_size<1 or args.chunk_size>2000:
        parser.error("chunk-size must be 1..2000")
    result={"type":"REAL_MYSQL_SOURCE_TO_STAGING","verify_only":args.verify_only,
            "all_checks_pass":False,"sources":{}}
    conn=connect_db()
    try:
        before=count_analytic_rows(conn)
        for kind,meta in ORIGINAL.items():
            result["sources"][kind]={}
            with conn.cursor() as cursor:
                cursor.execute("SELECT COUNT(*) FROM STG_P0_QUALITY WHERE source_kind=%s AND source_batch_id=%s", (kind,meta["batch_id"]))
                staged_before=cursor.fetchone()[0]
            fingerprint_before=stage_fingerprint(conn,kind,meta["batch_id"])
            if not args.verify_only:
                started=time.monotonic()
                first=run(kind,meta["batch_id"],args.chunk_size)
                first_seconds=time.monotonic()-started
                # MySQL's default REPEATABLE READ otherwise retains the snapshot
                # opened by count_analytic_rows/stage_fingerprint before run().
                conn.commit()
                result["sources"][kind].update({"run":first,"first_run_seconds":round(first_seconds,3),"staging_rows_before":staged_before})
            details=verify_one(conn,kind,meta,args.chunk_size)
            fingerprint_loaded=stage_fingerprint(conn,kind,meta["batch_id"])
            if not args.verify_only:
                started=time.monotonic()
                replay=run(kind,meta["batch_id"],args.chunk_size)
                replay_seconds=time.monotonic()-started
                # Observe replay commits, rather than comparing a stale snapshot.
                conn.commit()
                fingerprint_replay=stage_fingerprint(conn,kind,meta["batch_id"])
                if fingerprint_replay!=fingerprint_loaded:
                    raise AssertionError(f"{kind}: re-run modified stored result/timestamp")
                if replay["processed"]!=meta["rows"]:
                    raise AssertionError(f"{kind}: replay count drift")
                result["sources"][kind]["replay"]=replay
                result["sources"][kind]["replay_seconds"]=round(replay_seconds,3)
                result["sources"][kind]["staging_first_run_net_new_rows"]=details["staged_rows"]-staged_before
                result["sources"][kind]["staging_second_run_new_or_modified_rows"]=0
            result["sources"][kind]["validation"]={**details,
                "staging_fingerprint_sha256":fingerprint_loaded}
            print(f"PASS {kind}: {details['staged_rows']} MySQL STG rows; "
                  f"{details['decisions']}",flush=True)
        after=count_analytic_rows(conn)
        if before!=after:
            raise AssertionError("DIM/FACT row counts changed")
        result["dim_fact_rows_unchanged"]=True
        result["total_rows"]=sum(x["validation"]["staged_rows"] for x in result["sources"].values())
        if result["total_rows"]!=584385: raise AssertionError("Total rows != 584385")
        result["all_checks_pass"]=True
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",
                               encoding="utf-8")
        print(f"PASS all 584385 original MySQL staging rows; report: {args.report}")
    finally:
        conn.close()


if __name__=="__main__":
    main()
