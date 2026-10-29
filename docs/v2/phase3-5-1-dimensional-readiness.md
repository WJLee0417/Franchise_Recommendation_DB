# Phase 3-5-1 — DIM·FACT 적재 선행조건 및 정합성 게이트 (2026-10-29)

## 범위 및 의사결정

**결론: `HOLD_FACT_LOADING`.** Phase 3-4-4에서 584,385행을 MySQL SRC→STG에 정제한 사실은 확인됐지만, **검증된 상권 경계 버전과 시간 효력, 서울 업종 분류 버전 및 점포 지표의 관측기간이 없어 P0 FACT는 아직 적재할 수 없다.** `STG_P0_QUALITY.dim_area_eligible/fact_eligible`은 계속 0으로 유지해야 한다.

이번 단계의 산출물은 **읽기 전용 정합성 검사 + 적재 허용 게이트 정의**다. 실제 DB에 DIM/FACT INSERT, 원천 수정, 임의 기준일 생성은 포함하지 않는다.

- 실행 대상: `franchise_dw_p0`, 이전 원본 배치 AREA 1,650 / SALES 125,692 / STORE 457,043, 총 **584,385**.
- 기계 판독 게이트: `config/phase35_load_gates.v1.json` (12개; READY_TO_DESIGN 1, CONDITIONAL 5, BLOCKED 6).
- MySQL 읽기 전용 예비검증: `scripts/preflight_p0_dim_fact.py`. 실제 로컬 MySQL 컨테이너에 이 스크립트를 **아직 실행하지 않았음**. 기존 Phase 3-4-4 전수 적재 보고서와 스키마 DDL을 검토했다.

## 1. 기존 MySQL 데이터모델과 실제 소스의 연결

| 대상 DIM/FACT | 현재 물리 Grain / PK | P0 원천 근거 | 사전 판단 |
|---|---|---|---|
| `DIM_AREA_TYPE` | area_type_code UNIQUE | AREA의 상권구분코드 | 조건부: 공식 코드북/버전 확인 |
| `DIM_DISTRICT` | district_code UNIQUE | AREA의 자치구코드 | 조건부: 기준시점의 자치구 코드 확인 |
| `DIM_DONG` | dong_code UNIQUE | AREA의 행정동코드 | 조건부: 행정구역 변경 검증 |
| `DIM_PERIOD` | (calendar_code, period_type_code, period_code) UNIQUE | SALES/STORE 분기 20221..20232 | **설계 가능**: 2022Q1~2023Q2 기간 매핑, 종료일 표현 및 달력코드 명확히 |
| `DIM_AREA` | (area_code, version_no), current는 code별 1건 | AREA는 area_code 1,650개, **유효시작일·경계 버전 부재** | **BLOCKED** |
| `DIM_INDUSTRY` | (service_industry_code, classification_version, effective_start_date) | SALES 63종, STORE 100종 | **BLOCKED**: 공식 업종버전/효력 시작일 부재 |
| `FACT_AREA_SALES` | (period_key, area_key, industry_key) | 원본 (분기, 상권, 업종) 125,692행, 중복 0 | **BLOCKED**: 두 SCD 차원의 적법한 버전 선택 불가 |
| `FACT_AREA_STORE` | (period_key, area_key, industry_key, observation_period_key) | 457,043행, (분기, 상권, 업종) 중복 0 | **BLOCKED**: 공간/업종 이력과 **관측기간** 미확인 |

**추가 모델 정합성 이슈**

1. `DIM_PERIOD.period_end_date`가 DATE NOT NULL이고 CHECK는 시작일 이하 여부만 검증한다. `DIM_AREA.effective_end_date`는 exclusive로 설계됐으므로, 분기 종료일 포함/제외 기준을 명시적으로 일치시켜야 한다. 권고: 보고기간 DATE는 분기 **마지막 날 inclusive**, SCD 효력 구간은 [start,end)로 하되 비교 함수에서 분기 end+1일로 구간 완전 포함을 검증.
2. `FACT_AREA_STORE.observation_period_key`는 **NOT NULL**, 원본 STORE CSV에는 `기준_년분기_코드`만 존재. 두 키가 동일하다고 자동 설정해서는 안 된다. 공식 지표의 스냅샷/분모·기간 의미 확인 후 매핑.
3. `FACT_AREA_STORE`의 **기초 DDL**은 `0..100` 비율 CHECK로 생성되지만 실제 DB에는 `004_store_rate_nonnegative.sql`을 적용하여 **비음수** 제한으로 변경돼 있다. 새 DW 설치 시 같은 마이그레이션 적용 필수. >100 발생: 개업 5, 폐업 124, 합집합 128행.
4. `DIM_AREA`와 `DIM_INDUSTRY`의 `is_current` 유일 제약은 현행 버전 최대 한 건만 강제한다. **과거 효력구간 중복/분기 중간 변경 또는 '현재' 버전의 실제 존재**를 보증하지 않는다. [start,end) overlap 검증 필수.
5. `lineage_group_id`는 필수 문자열이지만 실제 SRC/ STG 원본을 참조하는 **FK나 매핑 원장 없이** 임의 UUID로 채워서는 완전한 계보 추적이 되지 않는다. source_row_id + batch + rule_version + target PK 연결 정책 확정 후 적재.
6. SALES는 공식적으로 **분기 추정매출액 KRW**이며 일/월 평균으로 환산하지 않는다. STORE/SALES의 원본 business key 는 같아도, **STORE에서만 보이는 331,351개 key**는 매출 미관측이다. 분석 LEFT JOIN과 NULL 유지. 전부 0원으로 만들거나 INNER JOIN으로 소실 금지.
7. AREA 파일은 좌표·면적은 갖지만 **polygon geometry와 기준연도가 없다**. 소스 코드가 존재한다고 historical quarter 전체를 해당 polygon 버전에 귀속시킬 수 없다.
8. 서울/FTC 산업코드는 분류체계가 다르므로 `DIM_FRANCHISE.industry_key`를 서울 코드와 문자열 유사도로 연결하지 않는다.

## 2. 선행조건 12개 판정

| ID | 대상 | 판정 | 해제 조건 |
|---|---|---|---|
| G01 | 기간 차원 | **READY_TO_DESIGN** | 기간코드-달력·시작/종료 날짜·inclusive/exclusive 의미 승인 |
| G02 | 상권 공간 버전 | **BLOCKED** | 2022~23 공간 데이터 SHP 및 배포 메타데이터로 실제 경계 유효기간 매핑 |
| G03 | 업종 버전 | **BLOCKED** | 2022~23 서울 서비스업종 100코드의 공식 분류 버전/효력 시점 |
| G04 | 구분/자치구/동 차원 | **CONDITIONAL** | 코드-명칭 1:1과 기준시점 코드북 검증 |
| G05 | 매출 FACT | **BLOCKED** | G02·G03와 SCD2 기간별 1:1 조인 검증 |
| G06 | 점포 관측기간 | **BLOCKED** | 보고분기≠관측기간 가능성 확인·필드 정의/코드북 확보 |
| G07 | 점포 수치 제약 | **CONDITIONAL** | 실제 DB CHECK 및 정밀도·비음수 현황 검증 |
| G08 | 매출·점포 결합 | **CONDITIONAL** | STORE-only 331,351개는 결측 처리·분석 계약 확인 |
| G09 | 품질 경고 적용 | **CONDITIONAL** | 14개 정책 미구현/부분구현 및 항목별 수용 행 정책 |
| G10 | SRC→DIM/FACT lineage | **CONDITIONAL** | 데이터 계보 매핑·정합성·멱등성 설계 |
| G11 | SCD Type2 기간 중복 | **BLOCKED** | 구간 비중첩, 분기 전체 포함, 키 cardinality 검증 |
| G12 | FTC↔서울 분류/지역 | **BLOCKED** | 출처별 코드 연결 근거·지역 매핑 |

**판정 구분:** READY_TO_DESIGN은 DDL/매핑 설계 가능을 의미하고 데이터 적재 승인이 아니다. CONDITIONAL과 BLOCKED가 남아 있는 대상은 실제 적재를 진행하지 않는다.

## 3. 읽기 전용 사전 검사

스크립트는 `SRC_SEOUL_*` 세 배치의 건수·업무키 중복·STG 건수와 품질판정, SOURCE 간 상권코드/업종/분기 조인, STORE only 매출 건수, 대상 STG 적재차단 플래그, 적용된 비율 CHECK 정의를 확인한다.

```bash
export PYTHONPATH=src
# FRANCHISE_DW_* 로컬 접속 환경변수 사용
python scripts/preflight_p0_dim_fact.py --output data/local/phase35_preflight.json
```

자동 판정은 설령 technical_preflight_pass=true이어도 **`can_load_dim_fact=false`를 고정**한다. 실제 로컬 DB 접속/검증 전에는 보고서의 실측 수치라고 주장하지 않는다.

## 4. 실행 이전 구체적인 과제 우선순위

1. **최우선 — 공간 버전 공식 증빙:** 서울시 영역-상권 역사적 SHP와 기준일자/유효기간을 수집해 1,650개 area_code를 기간별 경계 버전에 연결하는 표를 확보한다. 배포일을 곧바로 유효시작일로 가정하지 않는다.
2. **동시에 — 업종 코드북 버전:** 원본 100개 서비스업종코드의 공식 명칭·분류버전·적용 시작/종료일 확보. 분류 버전을 임의 `2023` 같은 이름으로 생성하지 않는다.
3. **STORE 관측기간 산식:** 공식 지표 설명으로 `observation_period_key` 매핑을 확정하거나, 측정과 보고의 분리가 필요 없다는 것을 검증 후 DDL grain 변경 여부를 평가한다.
4. **SCD2 설계:** 분기 전체를 단일 version에 배정하는 규칙, 부분 기간 경계 변화 시 거절/분할, 업무키→surrogate mapping cardinality 보장.
5. **lineage + 재처리:** SRC/STG source_record_path까지 내려가는 관계형 매핑과 감사지표 설계; 같은 source document와 rule version 재실행의 멱등성, 변경 시 버전된 재처리 정의.
6. **후속 단계 분리:** 권한·비밀정보·실제 고유값까지 검증한 뒤에야 적재 계획/마이그레이션을 실행한다. 이번 Phase 3-5-1에는 하지 않음.

## 5. 완료 판단

- [x] P0 8개 DIM/FACT 대상 테이블의 실제 DDL, 자연키·PK·FK 및 필요 컬럼 분석
- [x] 원본 CSV/ STG 전체 품질 리포트 및 참조 누락·사실관계 정리
- [x] 자동 적재 차단 게이트 JSON 작성
- [x] 읽기 전용 MySQL 실제 스키마 사전 검증 스크립트 작성
- [ ] 사용자 로컬 MySQL에서 사전 검증 스크립트 실행 및 집계 증빙
- [ ] 공식 공간 경계 버전·업종 코드북·관측기간 매핑 확보
- [ ] 승인 가능한 SCD/lineage/결측처리 설계

**결론:** Phase 3-5-1의 **설계 선행조건 분석은 완료**, 실제 MySQL 데이터 모델 정합성의 최종 PASS 및 DIM/FACT 적재 승인은 **보류**한다. 원본 49개 DIM/FACT 구조는 유지하며 아무 데이터도 생성하지 않았다.
