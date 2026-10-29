"""Phase 3-4-2: normalize MySQL SRC to separate quality staging. No DIM/FACT writes."""
import argparse
import hashlib
import json
import re
import uuid
from collections import Counter
from decimal import Decimal, InvalidOperation
from pathlib import Path
from franchise_dw.ingest_p0_csv import connect_db

TABLES = {"area":"SRC_SEOUL_AREA","sales":"SRC_SEOUL_SALES","store":"SRC_SEOUL_STORE"}
COUNTS = {"store_count","similar_industry_store_count","opened_store_count",
          "closed_store_count","franchise_store_count","estimated_sales_amount"}
METRICS = {"area":["x_coordinate","y_coordinate","area_size"],
           "sales":["estimated_sales_amount"],
           "store":["store_count","similar_industry_store_count","opening_rate",
                    "opened_store_count","closure_rate","closed_store_count","franchise_store_count"]}
LEVEL = {"ACCEPT":0,"WARN":1,"REVIEW":2,"REJECT":3}
MISSING = {"","NULL","N/A","NA","NONE","-","미상","정보없음"}
PERIOD = re.compile(r"^(19|20)[0-9]{2}[1-4]$")
POLICY_PATH = Path(__file__).resolve().parents[2] / "config" / "p0_quality_rules.v1.json"
# This fingerprint identifies the policy reviewed alongside this implementation.
# A changed policy must be reviewed and implemented before this pin is updated.
APPROVED_POLICY_VERSION = "0.1.0"
APPROVED_POLICY_SHA256 = "c517e44c856fe0ca99b563fff3fb54a58dffb10fdbf380e08384be529f6fd15c"


def load_policy(path=None):
    """Reject policy drift before writing; JSON formatting and key order are immaterial."""
    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"Duplicate policy JSON key: {key}")
            result[key] = value
        return result

    def invalid_constant(value):
        raise ValueError(f"Invalid policy JSON constant: {value}")

    try:
        data = json.loads(Path(path or POLICY_PATH).read_text(encoding="utf-8"),
                          object_pairs_hook=unique_object, parse_constant=invalid_constant)
        if not isinstance(data, dict) or data.get("version") != APPROVED_POLICY_VERSION:
            raise ValueError("Unsupported policy version")
        canonical = json.dumps(data, ensure_ascii=False, sort_keys=True,
                               separators=(",", ":"), allow_nan=False).encode("utf-8")
        digest = hashlib.sha256(canonical).hexdigest()
        if digest != APPROVED_POLICY_SHA256:
            raise ValueError("Policy JSON differs from the approved implementation")
    except (OSError, UnicodeError, ValueError, TypeError, RecursionError) as exc:
        raise RuntimeError(f"P0 quality policy validation failed: {exc}") from exc
    return APPROVED_POLICY_VERSION, digest

def decimal_value(value, *, integer=False, allow_negative=False):
    if value is None or str(value).strip().upper() in MISSING:
        raise ValueError("MISSING")
    try: n=Decimal(str(value).strip())
    except InvalidOperation: raise ValueError("INVALID") from None
    if not n.is_finite() or (n<0 and not allow_negative):
        raise ValueError("NEGATIVE_OR_NONFINITE")
    if integer and n!=n.to_integral_value():
        raise ValueError("FRACTIONAL")
    return int(n) if integer else format(n,"f")

def evaluate(kind, row, *, policy=None):
    """Return deterministic decision + flags + original-to-typed mapping."""
    if kind not in TABLES: raise ValueError("Unsupported SRC table")
    if policy is None: policy=load_policy()
    if policy != (APPROVED_POLICY_VERSION, APPROVED_POLICY_SHA256):
        raise RuntimeError("Unapproved P0 quality policy")
    issues=[]
    def add(code,level): issues.append((code,level))
    area=(row.get("area_code") or "").strip()
    typ=(row.get("area_type_code") or "").strip()
    industry=(row.get("service_industry_code") or "").strip() if kind!="area" else None
    if not area or not typ or (kind!="area" and not industry):
        add("P0-DQ-001_KEY","REJECT")
    period=None
    if kind!="area":
        raw_period=(row.get("base_year_quarter") or "").strip()
        if not PERIOD.fullmatch(raw_period):
            add("P0-DQ-001_PERIOD","REJECT")
        else: period=raw_period[:4]+"Q"+raw_period[-1]
    metrics={}
    for name in METRICS[kind]:
        try: metrics[name]=decimal_value(row.get(name),integer=name in COUNTS)
        except ValueError as ex:
            metrics[name]=None
            add("P0-DQ-002_"+name.upper()+"_"+str(ex),"REJECT")
    if kind=="area":
        add("P0-DQ-009_AREA_VALID_TIME_MISSING","REVIEW")
    elif kind=="store" and all(x is not None for x in metrics.values()):
        n=metrics["store_count"]
        opening=Decimal(metrics["opening_rate"])
        closure=Decimal(metrics["closure_rate"])
        if opening>100: add("P0-DQ-003_OPEN_GT_100","WARN")
        if closure>100: add("P0-DQ-003_CLOSE_GT_100","WARN")
        if metrics["similar_industry_store_count"]>n: add("P0-DQ-004_SIMILAR_GT_STORE","WARN")
        if metrics["franchise_store_count"]>n: add("P0-DQ-005_FRANCHISE_GT_STORE","REVIEW")
        opened,closed=metrics["opened_store_count"],metrics["closed_store_count"]
        if n==0 and (opened or closed): add("P0-DQ-006_ZERO_STORES_WITH_EVENTS","REVIEW")
        if opened>n or closed>n: add("P0-DQ-006_EVENTS_GT_STORE","REVIEW")
        if opening==0 and opened>0: add("P0-DQ-006_OPEN_ZERO_WITH_EVENTS","REVIEW")
        if closure==0 and closed>0: add("P0-DQ-006_CLOSE_ZERO_WITH_EVENTS","REVIEW")
    elif kind=="sales" and metrics["estimated_sales_amount"] is not None:
        try:
            raw=json.loads(row["raw_record_text"])
            total=metrics["estimated_sales_amount"]
            groups=[
                ("WEEK",["주중_매출_금액","주말_매출_금액"]),
                ("DAY",[d+"요일_매출_금액" for d in "월화수목금토일"]),
                ("SEX",["남성_매출_금액","여성_매출_금액"]),
                ("AGE",[k for k in raw if k.startswith("연령대_") and k.endswith("_매출_금액")])
            ]
            for label,names in groups:
                if not names or not all(name in raw for name in names): continue
                try: subtotal=sum(decimal_value(raw[name],integer=True) for name in names)
                except ValueError:
                    add("P0-DQ-008_DETAIL_NONNUMERIC","REVIEW"); continue
                if subtotal!=total:
                    code="P0-DQ-007_" if label in ("SEX","AGE") else "P0-DQ-013_"
                    add(code+label+"_DIFF","WARN")
            time_bins=[v for k,v in raw.items() if k.startswith("시간대_") and k.endswith("_매출_건수")]
            if time_bins:
                values=[decimal_value(v,integer=True,allow_negative=True) for v in time_bins]
                if any(v<0 for v in values): add("P0-DQ-008_TIME_NEGATIVE","REVIEW")
                transaction_count=decimal_value(raw["당월_매출_건수"],integer=True)
                if sum(values)!=transaction_count: add("P0-DQ-008_TIME_MISMATCH","REVIEW")
        except (KeyError,ValueError,TypeError,InvalidOperation,json.JSONDecodeError):
            add("P0-DQ-008_DETAIL_UNREADABLE","REVIEW")
    decision=max(["ACCEPT",*(level for _,level in issues)],key=lambda k:LEVEL[k])
    clean={
        "source_kind":kind,"source_row_id":row["source_row_id"],
        "source_batch_id":row["collection_batch_id"],
        "source_document_id":row["source_document_id"],
        "source_record_path":row["source_record_path"],
        "source_raw_sha256":hashlib.sha256(row["raw_record_text"].encode("utf-8")).hexdigest(),
        "rule_version":policy[0],"decision":decision,"issue_codes":[k for k,_ in issues],
        "normalized_period_code":period,"area_code":area or None,
        "industry_code":industry,"area_type_code":typ or None,
        "normalized_metrics":metrics,"dim_area_eligible":0,"fact_eligible":0
    }
    fingerprint=json.dumps(clean,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    clean["result_sha256"]=hashlib.sha256(fingerprint.encode("utf-8")).hexdigest()
    return clean

def run(kind,batch_id,chunk=500,connection_factory=connect_db, *, policy_path=None):
    if kind not in TABLES: raise ValueError("Unapproved source")
    if not batch_id or len(batch_id)>50 or chunk<1 or chunk>5000: raise ValueError("Invalid arguments")
    policy=load_policy(policy_path)
    conn=connection_factory(); run_id=str(uuid.uuid4()); counts=Counter()
    fields=["source_kind","source_row_id","source_batch_id","source_document_id",
            "source_record_path","source_raw_sha256","rule_version","decision",
            "issue_codes","normalized_period_code","area_code","industry_code","area_type_code",
            "normalized_metrics","dim_area_eligible","fact_eligible","result_sha256"]
    insert="INSERT INTO STG_P0_QUALITY ("+",".join(fields)+") VALUES ("+",".join(["%s"]*len(fields))+")"
    def bind(r):
        return tuple(json.dumps(r[k],ensure_ascii=False,separators=(",",":"))
            if k in ("issue_codes","normalized_metrics") else r[k] for k in fields)
    try:
        with conn.cursor() as cur:
            cur.execute("INSERT INTO DQ_P0_RUN(run_id,source_kind,source_batch_id,policy_version,status) VALUES (%s,%s,%s,%s,'RUNNING')",
                        (run_id,kind,batch_id,policy[0]))
        conn.commit()
        last=0
        while True:
            with conn.cursor() as cur:
                cur.execute(f"SELECT * FROM {TABLES[kind]} WHERE collection_batch_id=%s AND source_row_id>%s ORDER BY source_row_id LIMIT %s",(batch_id,last,chunk))
                columns=[col[0] for col in cur.description]
                raw_rows=cur.fetchall()
                if not raw_rows: break
                for record in raw_rows:
                    source=dict(zip(columns,record));last=source["source_row_id"]
                    normalized=evaluate(kind,source,policy=policy)
                    counts[normalized["decision"]]+=1
                    cur.execute("SELECT result_sha256 FROM STG_P0_QUALITY WHERE source_kind=%s AND source_row_id=%s",(kind,last))
                    prev=cur.fetchone()
                    if prev:
                        if prev[0]!=normalized["result_sha256"]:
                            raise RuntimeError("Existing staging content differs; manual versioned migration needed")
                    else:
                        cur.execute(insert,bind(normalized))
            if load_policy(policy_path)!=policy:
                raise RuntimeError("P0 quality policy changed during execution")
            conn.commit()
        n=sum(counts.values())
        if load_policy(policy_path)!=policy:
            raise RuntimeError("P0 quality policy changed during execution")
        with conn.cursor() as cur:
            cur.execute("UPDATE DQ_P0_RUN SET status='SUCCEEDED', processed_rows=%s, accept_rows=%s, warn_rows=%s, review_rows=%s, reject_rows=%s, finished_at=NOW(6) WHERE run_id=%s",
                (n,counts["ACCEPT"],counts["WARN"],counts["REVIEW"],counts["REJECT"],run_id))
        conn.commit()
        return {"run_id":run_id,"source":kind,"processed":n,"decisions":dict(counts)}
    except Exception as error:
        conn.rollback()
        with conn.cursor() as cur:
            cur.execute("UPDATE DQ_P0_RUN SET status='FAILED',error_category=%s,finished_at=NOW(6) WHERE run_id=%s",
                (type(error).__name__,run_id))
        conn.commit()
        raise
    finally: conn.close()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source",required=True,choices=sorted(TABLES))
    parser.add_argument("--batch-id",required=True)
    parser.add_argument("--chunk-size",type=int,default=500)
    parser.add_argument("--policy-file",type=Path,default=None)
    args=parser.parse_args()
    print(json.dumps(run(args.source,args.batch_id,args.chunk_size,policy_path=args.policy_file),ensure_ascii=False))

if __name__=="__main__": main()
