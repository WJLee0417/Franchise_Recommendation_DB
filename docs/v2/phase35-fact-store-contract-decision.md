# Phase 3-5 — 점포 FACT 의미 계약 확정 (모델 계약만)

## 결정

원본 457,043행의 `유사_업종_점포_수 = 점포_수 + 프랜차이즈_점포_수` 불변식과 서울 공식 점포 필드 정의를 기준으로, FACT에서 일반·전체·가맹점 수를 명확하게 구분한다.

| 신규 FACT 컬럼 | 원본 SRC 필드 | 통계 의미 |
|---|---|---|
| ordinary_store_count | store_count | 일반 점포 수 |
| total_store_count | similar_industry_store_count | 전체 점포 수 |
| franchise_store_count | franchise_store_count | 프랜차이즈 점포 수 |

이 결정은 **FACT 물리 스키마의 의미 계약만 승인**한다. 2022–2023 원본의 일자·상권 경계·분류 버전은 승인하지 않는다. SRC 및 기존 STG v0.1 품질 판정은 변경하지 않는다. 과거 한글 컬럼과 현행 API 영문 코드의 관계는 전수 데이터 항등식과 공식 공개 정의를 바탕으로 한 매핑으로, 과거 버전별 공식 코드북을 확보한 것은 아니다.

## 적용 파일
- 계약: `config/phase35_fact_store_contract.v1.json`
- 검토/적용 마이그레이션: `sql/v2/migrations/006_fact_area_store_semantic_names.sql`
- 계약 CI: `tests/test_fact_store_semantics_contract.py`와 워크플로.

**Migration 006은 원본 FACT_AREA_STORE가 0행인 경우에만 동작**한다. 또한 비음수 개·폐업률의 004 마이그레이션 적용을 검사한다. 이미 값이 존재하는 운영 테이블에 무심코 rename하거나 기존 STORE 데이터·품질 판정을 업데이트하지 않는다. 실물 MySQL 8에서의 마이그레이션 통합시험은 후속 검증이 필요하다.

> 안전한 단계 구분: (A) FACT 의미 계약 확정 → (B) 별도 승인 후 스키마 006 적용/CI → (C) 공식 역사적 시간 및 분류/공간 근거 확보 → (D) 실제 DIM/FACT 데이터 적재. 단계 A는 완료, B/C/D는 미완료.

## 데이터 무결성 및 예외

- `total_store_count = ordinary_store_count + franchise_store_count`는 이 보관본의 모든 457,043행에 대해 참이다. 비율 >100 수치도 원문 그대로 보존하며, 개·폐업률의 계산 산식이 과거와 완전히 일치한다는 뜻은 아니다.
- 판매 데이터가 없는 STORE 331,351개의 매출은 0이 아니라 **미관측(NULL)** 으로 본다.
- 보고 기간 `period_key`와 관측 기간 `observation_period_key`는 별도 공식 근거 전 **동일 처리 금지**.
- `DIM_AREA`, `DIM_INDUSTRY`의 SCD 유효기간을 추정해 임의 날짜를 생성하지 않는다.
- 기존 v0.1 품질 규칙 004/005가 일반/전체/가맹점을 서로 잘못 비교한 결과는 v0.2의 별도 승인/재계산 시에만 수정한다.

## 분리된 역사적 증빙 작업

별도 Draft PR의 범위: 2022/23 OA-15560 과거 공간 파일과 코드 및 [start,end) 근거, 서울 100개 업종 코드를 정의한 공식 버전/효력일, OA-15577 점포 관측 및 개·폐업률 기준시점·분모 설명을 확보하고 원본과 검증한다. 증빙 미확보 시 BLOCKED 상태를 유지하고 FACT 데이터를 넣지 않는다.
