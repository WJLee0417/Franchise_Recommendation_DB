"""Synthetic MySQL loader rollback and recovery; use an isolated disposable server.

Requires an isolated server with the test-only root password provided in
SNAPSHOT_TEST_PASSWORD. SNAPSHOT_TEST_PORT defaults to 13317. Creates a dedicated
test schema, never drops it and refuses to reuse an existing schema.
"""
import os
from pathlib import Path

import pymysql
from franchise_dw import load_snapshot_dimensions as loader
from franchise_dw.snapshot_dimensions import make_evidence
from verify_snapshot_dimensions_mysql import fingerprints

SCHEMA = 'phase354_snapshot_synthetic_v3'


class InterruptCursor:
    def __init__(self, cursor):
        self.cursor = cursor
        self.area_inserts = 0
    def __enter__(self):
        self.cursor.__enter__()
        return self
    def __exit__(self, *args):
        return self.cursor.__exit__(*args)
    def execute(self, sql, args=None):
        value = self.cursor.execute(sql, args)
        if sql.startswith('INSERT INTO SNAP_AREA'):
            self.area_inserts += 1
            if self.area_inserts == 10:
                raise RuntimeError('synthetic interruption after ten area inserts')
        return value
    def __getattr__(self, key):
        return getattr(self.cursor, key)


class InterruptConnection:
    def __init__(self, conn): self.conn = conn
    def cursor(self): return InterruptCursor(self.conn.cursor())


def counts(conn):
    with conn.cursor() as cur:
        result = []
        for table in ('SNAP_SOURCE_DOCUMENT','SNAP_PERIOD','SNAP_AREA','SNAP_INDUSTRY','SNAP_INDUSTRY_SOURCE'):
            cur.execute('SELECT COUNT(*) FROM '+table)
            result.append(cur.fetchone()[0])
        return result


def main():
    conn = pymysql.connect(host='127.0.0.1',port=int(os.environ.get('SNAPSHOT_TEST_PORT','13317')),user='root',password=os.environ['SNAPSHOT_TEST_PASSWORD'],charset='utf8mb4',autocommit=False)
    with conn.cursor() as cur:
        cur.execute('SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name=%s',(SCHEMA,))
        if cur.fetchone()[0]: raise RuntimeError('Synthetic schema exists; refusing to overwrite it')
        cur.execute('CREATE DATABASE `'+SCHEMA+'` CHARACTER SET utf8mb4 COLLATE utf8mb4_bin')
        cur.execute('USE `'+SCHEMA+'`')
        cur.execute('CREATE TABLE SRC_SEOUL_AREA (source_row_id BIGINT UNSIGNED PRIMARY KEY,collection_batch_id VARCHAR(50),source_document_id VARCHAR(200),source_record_path VARCHAR(200),area_code VARCHAR(50),area_name VARCHAR(200),area_type_code VARCHAR(50),area_type_name VARCHAR(100),district_code VARCHAR(50),district_name VARCHAR(100),dong_code VARCHAR(50),dong_name VARCHAR(100),x_coordinate VARCHAR(50),y_coordinate VARCHAR(50),area_size VARCHAR(50)) ENGINE=InnoDB')
        for name in ('SALES','STORE'):
            cur.execute('CREATE TABLE SRC_SEOUL_'+name+' (collection_batch_id VARCHAR(50),source_document_id VARCHAR(200),source_record_path VARCHAR(200),base_year_quarter VARCHAR(10),service_industry_code VARCHAR(50),service_industry_name VARCHAR(200)) ENGINE=InnoDB')
        cur.execute('CREATE TABLE STG_P0_QUALITY (source_kind VARCHAR(20),source_batch_id VARCHAR(50),source_document_id VARCHAR(200)) ENGINE=InnoDB')
        ddl=Path('sql/v2/migrations/007_snapshot_dimensions.sql').read_text(encoding='utf-8').replace('USE franchise_dw_p0;', 'USE `'+SCHEMA+'`;')
        for statement in ddl.split(';'):
            if statement.strip(): cur.execute(statement)
    evidence=make_evidence()
    for e,n in zip(evidence,(1650,63,100)): e['expected_rows']=n
    with conn.cursor() as cur:
        for e in evidence:
            kind=e['source_kind']; n=e['expected_rows']; batch=e['batch']; doc=e['source_document_id']
            cur.executemany('INSERT INTO STG_P0_QUALITY VALUES (%s,%s,%s)',[(kind,batch,doc)]*n)
            if kind=='area':
                cur.executemany('INSERT INTO SRC_SEOUL_AREA VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)',[(i,batch,doc,str(i),str(i),'Area','A','Type','D','District','H','Dong','1.25','2.5','3.75') for i in range(1,n+1)])
            else:
                cur.executemany('INSERT INTO SRC_SEOUL_'+kind.upper()+' VALUES (%s,%s,%s,%s,%s,%s)',[(batch,doc,str(i),('20221','20222','20223','20224','20231','20232')[i%6],f'I{i:03}',f'Industry {i:03}') for i in range(n)])
    conn.commit()
    old=loader.make_evidence
    loader.make_evidence=lambda:evidence
    try:
        try:
            loader.run(InterruptConnection(conn))
            raise AssertionError('interruption did not occur')
        except RuntimeError as exc:
            assert 'synthetic interruption' in str(exc)
            conn.rollback()
        assert counts(conn)==[0,0,0,0,0], 'partial rows survived rollback'
        with conn.cursor() as cur:
            cur.execute("UPDATE SRC_SEOUL_AREA SET area_code='1' WHERE source_row_id=2")
        try:
            loader.run(conn)
            raise AssertionError('duplicate area was not rejected')
        except ValueError as exc:
            assert 'area grain drift' in str(exc)
            conn.rollback()
        assert counts(conn)==[0,0,0,0,0]
        with conn.cursor() as cur:
            cur.execute("UPDATE SRC_SEOUL_STORE SET service_industry_name='conflict' WHERE service_industry_code='I000'")
        try:
            loader.run(conn)
            raise AssertionError('industry conflict was not rejected')
        except ValueError as exc:
            assert 'industry code/name conflict' in str(exc)
            conn.rollback()
        assert counts(conn)==[0,0,0,0,0]
        result=loader.run(conn)
        conn.commit()
        assert not result['replayed'] and counts(conn)==[3,6,1650,100,163]
        before=fingerprints(conn)
        with conn.cursor() as cur:
            cur.execute("UPDATE SNAP_AREA SET area_name='modified' WHERE area_code='1'")
        assert fingerprints(conn)!=before, 'fingerprints failed to detect content-only drift'
        conn.rollback()
        with conn.cursor() as cur:
            try:
                cur.execute("INSERT INTO SNAP_INDUSTRY_SOURCE VALUES (%s,%s,%s,%s)",('0'*64,'NO_SUCH_CODE',1,loader.SCOPE))
                raise AssertionError('FK violation was not rejected')
            except pymysql.err.IntegrityError:
                conn.rollback()
        assert counts(conn)==[3,6,1650,100,163]
        assert loader.run(conn)['replayed']
        conn.rollback()
        assert fingerprints(conn)==before, 'failure/replay changed existing snapshot content'
        print('PASS synthetic: interruption, duplicate area, conflicting industry and FK rolled back; recovery and full-row fingerprints preserved')
    finally:
        loader.make_evidence=old
        conn.close()


if __name__=='__main__': main()
