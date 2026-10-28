# Phase 3-4-2 — P0 SRC 숫자·분기·코드 정규화 및 판정 스테이징

## 범위 및 상태

P0 SRC 3개 테이블(`SRC_SEOUL_AREA`, `SRC_SEOUL_SALES`, `SRC_SEOUL_STORE`) 원본은 **읽기 전용**. `sql/v2/migrations/005_p0_quality_staging.sql`로 기존 물리 DB의 **49개 분석 테이블과 별도**인 운용 테이블 `DQ_P0_RUN` 및 `STG_P0_QUALITY`, 격리 조회 뷰 `V_P0_QUALITY_QUARANTINE`을 추가한다.

코드: `src/franchise_dw/transform_p0_quality.py`. 문서 작성 시점의 검증은 합성 단위 테스트와 MySQL DDL CI이며, 사용자의 로컬 원본 SRC 584,385행을 실제 변환하여 스테이징에 저장한 결과는 아직 **확인하지 않았다**.

## 정규화 정책

| 입력 | 정규화 | 판정 |
|---|---|---|
| `기준_년분기_코드` | `20221` → `2022Q1`; 유효 범위 1900~2099, 분기 1~4 | 유효하지 않으면 REJECT |
| 원본 코드 | 문자열 그대로 보존, 앞자리 0 유지, 빈 코드만 거절 | 코드 누락 REJECT |
| 점포·매출·건수 | Decimal 기반 검증 후 정수화; 0 보존 | 필수값 비숫자/음수/소수 REJECT |
| 면적·좌표·개폐업률 | Decimal 검사, 문자열로 정규화 | 비숫자/음수 REJECT (좌표 부호는 공식 CRS 확인 필요) |
| 100% 초과 개업률·폐업률 | 원 수치 유지, 상한 제한 없음 | WARN |
| 유사업종 수>점포 수 | 변경하지 않음 | WARN |
| 가맹점 수>점포 수, 개폐업 사건>스냅샷 수 | 변경하지 않음 | REVIEW |
| 시간대 매출건수 음수·합계 불일치 | 원본 상세 필드 보존 | REVIEW |
| 성별·연령별 매출 구성 차이 | 원본 전체 매출 유지 | WARN |
| AREA 유효기간·경계 버전 | **만들지 않음** | REVIEW, DIM·FACT gate=0 |

판정 우선순위: `REJECT > REVIEW > WARN > ACCEPT`. 모든 판정에는 규칙 코드와 결정론적 변환 결과 해시를 남긴다. 정상적인 매출 상세 자료의 기본 거절은 금지하며, 매출 일부 상세 필드 누락은 REVIEW로 분리한다.

**중요:** `ACCEPT`라고 하더라도 **DIM·FACT 적재 가능을 뜻하지 않는다**. 상권 경계 버전이 검증되지 않아 스테이징의 `dim_area_eligible`와 `fact_eligible`는 모두 0이고 DB CHECK로도 이를 강제한다.

## 스키마·재실행

- `DQ_P0_RUN`: 실행 ID·원천 배치·규칙 버전·실행 상태·판정별 건수·시간·오류 유형.
- `STG_P0_QUALITY`: 원천 테이블/PK·배치/문서/행 위치·원문 SHA-256·정제 수치 JSON·분기·코드·판정·규칙 목록·변환 결과 SHA-256.
- `V_P0_QUALITY_QUARANTINE`: REVIEW/REJECT의 원천 연결 정보와 판정 코드를 조회.
- 최초 적재는 source_row_id 오름차순 **키셋 페이지네이션**, 기본 500개 단위 커밋. 재실행 시 같은 원본과 같은 규칙이면 동일 `result_sha256`로 건너뛰며 내용이 다르면 조용히 덮어쓰지 않고 오류. 기존 SRC 원본은 수정하지 않음.
- `STG_P0_QUALITY`는 원본 PK를 논리적으로 연결하지만 SRC의 3개 테이블에 대한 다형성 FK는 존재하지 않는다. 분기·상권코드의 자연키 간 교차 레코드 일관성은 Phase 3-4 후속 고도화/Phase 4에서 점검한다.
- 규칙 구현은 핵심 정합성 조건에 한정. 기존 `config/p0_quality_rules.v1.json`의 모든 교차파일 키 중복·매출 결측 연계 규칙이 자동 실행되었다고 주장하지 않는다.

## 실행 방법

별도 테스트 MySQL 8에 기존 P0→004→P1→P2가 적용되어 있어야 한다.

```bash
# DDL 한 번만 실행. 이미 적용했다면 재실행하지 말 것.
mysql -h 127.0.0.1 -uroot -p < sql/v2/migrations/005_p0_quality_staging.sql

export PYTHONPATH=src
# 기존 FRANCHISE_DW_HOST/PORT/NAME/USER/PASSWORD 환경변수 설정
python -m franchise_dw.transform_p0_quality \
  --source area --batch-id p0-4dd5c697615606676fc0235b9c43
python -m franchise_dw.transform_p0_quality \
  --source sales --batch-id p0-e0c1f62afc9bd322c42e525e5345
python -m franchise_dw.transform_p0_quality \
  --source store --batch-id p0-271600360236b23608faf2ae6fdf
```

검증 SQL:

```sql
USE franchise_dw_p0;
SELECT source_kind, decision, COUNT(*) AS cnt
FROM STG_P0_QUALITY
GROUP BY source_kind, decision;
SELECT source_kind, COUNT(*) AS stored
FROM STG_P0_QUALITY GROUP BY source_kind;
SELECT source_kind, issue_codes, COUNT(*)
FROM V_P0_QUALITY_QUARANTINE
GROUP BY source_kind, issue_codes;
```

예상 전체 정제 대상은 `1,650 + 125,692 + 457,043 = 584,385`행. **판정별 실측 건수는 실행 결과에서만 확정**한다.

## 테스트 및 후속 게이트

- 합성 단위 테스트: 기간 정규화·금액 보존·음수/소수 거절·100 초과 유지·REVIEW 우선순위·유효기간 게이트·결과 해시 결정성.
- GitHub Actions: 합성 단위 테스트 + 독립 MySQL 8에서 기존 49개와 새 운용 테이블 2개의 DDL 생성 확인.
- 남은 작업: **실제 원본 584,385행 스테이징 변환 실행**, ACCEPT/WARN/REVIEW/REJECT 건수 검증, 교차 원천 중복·키 관계 검증, RULE-SPEC/실제 코드 일치 점검, 실행 결과의 품질 플래그 증빙 보관.
- 원본 ZIP, 원본 DB 덤프, DB 암호는 GitHub에 업로드하지 않는다.
