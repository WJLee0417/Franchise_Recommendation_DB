# Phase 1 — 신규 ERD 테이블 인벤토리 (49개 / 621컬럼)

> 소스: 사용자 제공 `상권분석ERD(1).damx` (SHA-256 `0fd22beb5239b071b39035deb3adb1485cc4261a07283927d3bca75f4d3de1b0`). DAMX 바이너리에서 식별되는 **물리 테이블명과 물리 컬럼명**으로 인벤토리 작성. 구조/이름 확인일 뿐 MySQL DDL 실행, FK/PK/NULL 검증 완료를 의미하지 않음.

| 영역 | 테이블 | 식별 컬럼 수 |
| --- | ---: | ---: |
| SRC (원천 데이터) | 21 | 367 |
| DIM (분석 차원) | 10 | 98 |
| FACT (관측값/지표) | 18 | 156 |
| **합계** | **49** | **621** |

## 우선순위 규칙

- **P0 (Phase 2A)**: 상권·업종의 기간별 매출/점포 분석을 재현할 최소 수직 슬라이스. **11개 테이블**.
- **P1 (Phase 2B/3~5)**: 시계열 상권 추가 지표와 FTC 데이터 연계. 분류 매핑·지역/기간 문제를 먼저 해결해야 함.
- **P2 (후속)**: 원천 확보와 공시 항목의 의미 검증 후 확장.

**P0 흐름:** `SRC_SEOUL_AREA` + `SRC_SEOUL_SALES` + `SRC_SEOUL_STORE` → `DIM_AREA_TYPE` / `DIM_DISTRICT` / `DIM_DONG` / `DIM_AREA` / `DIM_INDUSTRY` / `DIM_PERIOD` → `FACT_AREA_SALES` / `FACT_AREA_STORE`. P0는 *설계 구현 우선순위*이며 원천 데이터 수집·적재 완료를 의미하지 않음.

## 전체 목록

| 구분 | 물리 테이블 | 컬럼 수 | 우선순위 | 의미 및 검증 메모 |
| --- | --- | ---: | --- | --- |
| DIM | `DIM_AREA` | 17 | P0 | 상권 SCD 후보; area_code/version_no/유효기간/좌표 |
| DIM | `DIM_AREA_TYPE` | 5 | P0 | 상권 구분 기준정보 |
| DIM | `DIM_DISTRICT` | 5 | P0 | 자치구 기준정보 |
| DIM | `DIM_DONG` | 5 | P0 | 행정동 기준정보 |
| DIM | `DIM_INDUSTRY` | 9 | P0 | 서울시 업종 분류; FTC 매핑은 별도 과제 |
| DIM | `DIM_PERIOD` | 12 | P0 | 분기/연도/관측기간 기준정보 |
| DIM | `DIM_FRANCHISE` | 11 | P1 | 브랜드 SCD; 본부·업종과 연결 |
| DIM | `DIM_HEADQUARTER` | 9 | P1 | 가맹본부 SCD |
| DIM | `DIM_DISCLOSURE_VERSION` | 14 | P1 | 정보공개서 버전/계약조건 |
| DIM | `DIM_REGION` | 11 | P1 | FTC 지역 코드; 원천 지역명 표준화 필요 |
| FACT | `FACT_AREA_SALES` | 6 | P0 | 상권×업종×기간 추정매출 |
| FACT | `FACT_AREA_STORE` | 13 | P0 | 상권×업종×기간 점포·개폐업 지표 |
| FACT | `FACT_AREA_FACILITY` | 6 | P1 | 상권 시설 수/관측기간 |
| FACT | `FACT_AREA_APARTMENT` | 6 | P1 | 상권 아파트 단지 수/관측기간 |
| FACT | `FACT_AREA_FLOW_POP` | 14 | P1 | 상권 유동인구 연령·성별 지표 |
| FACT | `FACT_AREA_RESIDENT_POP` | 6 | P1 | 상권 상주인구 |
| FACT | `FACT_AREA_WORK_POP` | 26 | P1 | 상권 직장인구 |
| FACT | `FACT_AREA_INCOME` | 6 | P1 | 상권 평균소득 |
| FACT | `FACT_AREA_CONSUMPTION` | 5 | P1 | 상권 총지출 |
| FACT | `FACT_FRANCHISE_STORE` | 7 | P1 | 브랜드×지역×기간 점포 |
| FACT | `FACT_FRANCHISE_CHANGE` | 7 | P1 | 브랜드×기간 신규/만료/해지 |
| FACT | `FACT_FRANCHISE_AVG_SALES` | 7 | P1 | 브랜드×지역×기간 평균매출 |
| FACT | `FACT_HQ_FINANCE` | 11 | P1 | 가맹본부×기간×회계범위 재무 |
| FACT | `FACT_FRANCHISE_STARTUP_COST` | 9 | P2 | 정보공개서 버전별 창업비 |
| FACT | `FACT_FRANCHISE_INTERIOR` | 8 | P2 | 표준 점포규격별 인테리어 |
| FACT | `FACT_AD_PROMOTION` | 6 | P2 | 가맹본부 광고/판촉비 |
| FACT | `FACT_HQ_EMPLOYEE` | 6 | P2 | 가맹본부 임직원 |
| FACT | `FACT_HQ_LEGAL` | 7 | P2 | 가맹본부 법적 사항 |
| SRC | `SRC_SEOUL_AREA` | 21 | P0 | 서울시 상권코드/좌표/행정구역 원본 |
| SRC | `SRC_SEOUL_SALES` | 18 | P0 | 서울시 상권×업종×기간 추정매출 원본 |
| SRC | `SRC_SEOUL_STORE` | 24 | P0 | 서울시 상권×업종×기간 점포/개폐업 원본 |
| SRC | `SRC_SEOUL_FACILITY` | 16 | P1 | 서울시 집객시설 원본 |
| SRC | `SRC_SEOUL_APARTMENT` | 16 | P1 | 서울시 아파트 단지 원본 |
| SRC | `SRC_SEOUL_FLOW_POP` | 24 | P1 | 서울시 유동인구 원본 |
| SRC | `SRC_SEOUL_RESIDENT_POP` | 16 | P1 | 서울시 상주인구 원본 |
| SRC | `SRC_SEOUL_WORK_POP` | 36 | P1 | 서울시 직장인구 원본 |
| SRC | `SRC_SEOUL_CONSUMPTION` | 16 | P1 | 서울시 소비 원본 |
| SRC | `SRC_SEOUL_INCOME_ARCHIVE` | 17 | P1 | 서울시 과거 소득 원본; 현재 가용성 검증 |
| SRC | `SRC_FTC_DISCLOSURE` | 15 | P1 | FTC 정보공개서 기본 원본 |
| SRC | `SRC_FTC_FINANCE` | 18 | P1 | FTC 재무 원본 |
| SRC | `SRC_FTC_STORE` | 15 | P1 | FTC 가맹/직영 점포 원본 |
| SRC | `SRC_FTC_STORE_CHANGE` | 15 | P1 | FTC 신규/계약종료/해지 원본 |
| SRC | `SRC_FTC_AVG_SALES` | 15 | P1 | FTC 가맹점 평균매출 원본 |
| SRC | `SRC_FTC_CONTRACT` | 13 | P2 | FTC 최초·연장 계약조건 원본 |
| SRC | `SRC_FTC_STARTUP_COST` | 16 | P2 | FTC 가맹금/보증금 원본 |
| SRC | `SRC_FTC_INTERIOR` | 14 | P2 | FTC 인테리어 원본 |
| SRC | `SRC_FTC_AD_PROMOTION` | 14 | P2 | FTC 광고/판촉 원본 |
| SRC | `SRC_FTC_EMPLOYEE` | 14 | P2 | FTC 임직원 원본 |
| SRC | `SRC_FTC_LEGAL` | 14 | P2 | FTC 법적 사항 원본 |

## 구모델과 구조적으로 다른 지점

1. 구모델의 상권-업종 집계 `점포`는 한 테이블에 `매출`과 `점포_수`가 있었지만, 신규에서는 `FACT_AREA_SALES`/ `FACT_AREA_STORE`로 분리되며 **양쪽 기간/차원키가 일치해야** JOIN 가능.
2. 구모델 `상권정보`에서 인구·소득·소비·시설 지표가 각각 FACT로 분리되어 **지표별 발표 기준기간/관측기간**이 생길 수 있음. 무조건 같은 분기의 값으로 간주하지 않음.
3. `DIM_AREA`, `DIM_FRANCHISE`, `DIM_HEADQUARTER`는 `version_no`/유효기간 등을 가진 **이력형 차원 후보**. 스냅샷 기존 키와 직접 JOIN 금지.
4. `DIM_INDUSTRY`는 `service_industry_code`만 있으므로 **FTC 분류 → 서울시 업종** 매핑 이력을 담기 위한 구조가 별도로 필요할 수 있음. 신규 ERD에 crosswalk 전용 테이블은 식별되지 않았음.
5. `DIM_REGION`과 `DIM_DISTRICT`·`DIM_DONG`은 공통 지역을 나타내지만 코드 체계/포함관계가 명시적인지 재검토 필요. `SRC_FTC_STORE.source_region_name`만으로 고유 지역 식별이 불가능할 수 있음.
6. `SRC_*`의 수치 필드 상당수는 **VARCHAR 원문 보존형**임. 단위·NULL·비공개값·문자열 숫자 변환을 별도 품질 규칙으로 관리해야 함.

## 아직 확인하지 않은 사항

원본 데이터 적재 가능 여부, 파일 배포 라이선스, 엔터티의 PK/FK·UNIQUE·CHECK·인덱스, 시계열 natural key, 실제 기간/측정 단위, 정규화 제약, 각 도메인 값의 뜻은 별도 점검 대상. `schema.sql`을 새 49개 테이블로 교체하기 전 Phase 2의 **작은 DDL + 데이터 적재 + 테스트**부터 수행할 것.
