# Phase 3-2 — Seoul P0 historical CSV / ZIP ingestion (SRC only)

## 구현 범위
- 코드: `src/franchise_dw/ingest_p0_csv.py`; Python 3.10+, PyMySQL (기존 requirements.txt 수록).
- 서울 보관본 3종(영역 11컬럼, 추정매출 55컬럼, 점포 14컬럼)의 CP949 CSV, ZIP 내부 CSV를 **디스크 압축 해제 없이** 순차 스트리밍.
- 대상 DB는 `franchise_dw_p0`; 쓰기 대상은 `SRC_SEOUL_AREA`, `SRC_SEOUL_SALES`, `SRC_SEOUL_STORE`뿐이다. **DIM/FACT는 적재하지 않는다.**
- 컬럼 매핑은 실제 보관본 헤더로 검증한 allowlist; 매출 세부 47개 추가 컬럼 포함 전체 원본 셀을 `raw_record_text` JSON 문자열에 보존한다. 숫자는 원문 문자열 유지; 선행 0, 높은 개폐업률 그대로 유지.
- 배치 ID는 source table + ZIP 내부 CSV/일반 CSV **원본 바이트 SHA-256**을 기반으로 결정론적으로 생성. 다른 ZIP 위치에 같은 원본 내용이 있으면 동일 document/batch 인식. `source_record_path`는 CSV 레코드 번호(헤더 1, 첫 데이터 2).
- 중복 발생 시 `ON DUPLICATE KEY UPDATE source_row_id=source_row_id` 방식으로 멱등 재실행; 동일 배치·원천·레코드의 내용을 덮어쓰지 않는다. **원천 변경 후 SHA가 달라지면 신규 수집 버전으로 append**되므로 업무 키 정합/중복은 Phase 3-3~4에서 다룬다.
- `--limit`은 시험용 레코드 수 제한, `--dry-run`은 DB 접속 없이 파싱/헤더/행 검사. `--batch-size` 단위로 commit되므로 실패 전 commit된 chunk는 남으며 동일 파일 재실행으로 재개 가능하다.
- 출처 URL, 버전은 확증이 있을 때만 CLI로 받는다. AREA에는 기간이 없으며 해당 필드를 임의로 생성하지 않는다.
- **주의:** ZIP 안에 같은 CSV가 중복되어 있어 `--zip-member` 명시적 경로 선택을 강제한다. 모든 CSV는 UTF-8을 가정하지 않고 CP949를 사용한다.

## 실행 예시

```bash
export PYTHONPATH=src
python -m franchise_dw.ingest_p0_csv --input './data/local/archived.zip' --list-zip-members

python -m franchise_dw.ingest_p0_csv \
  --input './data/local/archived.zip' \
  --zip-member '2023_Franchise_Recommendation_DB/1/서울시 상권분석서비스(영역-상권).csv' \
  --source area --dry-run

# DB 쓰기는 아래 환경변수 사용; 커밋·터미널 로그에 비밀번호 입력 금지
export FRANCHISE_DW_HOST=127.0.0.1
export FRANCHISE_DW_PORT=3306
export FRANCHISE_DW_NAME=franchise_dw_p0
export FRANCHISE_DW_USER=franchise
export FRANCHISE_DW_PASSWORD='<local secret>'

python -m franchise_dw.ingest_p0_csv \
  --input './data/local/archived.zip' \
  --zip-member '2023_Franchise_Recommendation_DB/1/서울시 상권분석서비스(점포-상권).csv' \
  --source store --batch-size 500
```

## 실제 2023 ZIP dry-run 검증 (DB 미접속)

| 소스 | 헤더 수 | 행 수 | 파싱 |
| --- | ---: | ---: | --- |
| AREA | 11 | 1,650 | PASS |
| SALES | 55 | 125,692 | PASS |
| STORE | 14 | 457,043 | PASS |
| **계** | | **584,385** | **PASS** |

- 동일 사용자 ZIP으로 로컬에서 전체 파싱 완료. **DB INSERT 실측은 아직 수행하지 않았다**.
- GitHub CI: `.github/workflows/p0-csv-ingest.yml`은 synthetic unit fixture만 사용하므로 원본 CSV는 저장소에 없다.
- 필수 헤더 누락, 잘못된 행 길이, 잘못된 인코딩은 임의 보정 없이 중단한다.
- SRC 수집만이 완료 범위이며 실제 CSV 업로드·배치 처리 지연·물리 DB 적재 검증은 Phase 3-3에서 진행한다.

## 알려진 후속 사항
- 전체 raw_record_text는 셀값 JSON으로 표현되므로 원본 CSV quoting/바이트 단위 재생산은 보장하지 않는다. 대신 입력파일 SHA-256으로 문서 동일성을 검증한다.
- AREA SCD 유효시작일/geometry 버전 미확인 → DIM_AREA 적재 보류.
- STORE 비음수 금액/비율 CHECK 변경 마이그레이션은 별도 `sql/v2/migrations/004_store_rate_nonnegative.sql`로 적용 (SRC에는 비율 CHECK 자체가 없음).
- 무결성 검사/레코드별 격리·checksum·가시성 추적/FTL 비교는 Phase 3-3/4.
- PyMySQL connect credentials는 `FRANCHISE_DW_*` 환경변수 사용. Demo compose DB는 별도로 생성되고 있으므로 **DW 스키마와 권한을 별도 준비해야 한다.**
