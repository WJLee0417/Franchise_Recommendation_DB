# Phase 1 — 모델 재구성 검토 결과와 Phase 2 진입 기준

## 1. 검토 근거

- 현재 구현: `main/sql/schema.sql`, `docs/data-model.md`, `notebooks/franchise_recommendation.ipynb`, `docs/recommendation-design.md`.
- 목표 모델: 사용자가 제공한 `상권분석ERD(1).damx`의 물리 테이블/속성 인벤토리(원본 SHA-256: `0fd22beb5239b071b39035deb3adb1485cc4261a07283927d3bca75f4d3de1b0`).
- 상세 근거: [58개 레거시 컬럼 매핑](phase1-column-mapping.md), [49개 신규 테이블 인벤토리](phase1-target-inventory.md).
- **이 문서는 설계 검토 산출물**. 실제 데이터 이관, 49개 DDL 생성, 품질 검증, 결과 재현은 아직 하지 않았다.

## 2. 구모델 → 신규 모델 대응 (7개 테이블)

| 구모델 | 신규 목적지(요약) | 처리 방안 | 결정 |
| --- | --- | --- | --- |
| `상권_구분` | `DIM_AREA_TYPE` | 코드/명칭 유지, surrogate key 도입 | 유지·차원화 |
| `자치구` | `DIM_DISTRICT` | 코드 체계와 변경 이력 확인 | 유지·차원화 |
| `행정동` | `DIM_DONG` | 명칭이 아니라 코드로 연결 | 유지·차원화 |
| `서비스_업종` | `DIM_INDUSTRY` | 서울시 코드체계 기준·분류버전 관리. FTC 업종 crosswalk 별도 설계 | 유지·차원화 |
| `상권정보` | `DIM_AREA` + `FACT_AREA_FACILITY` / `APARTMENT` / `WORK_POP` / `RESIDENT_POP` / `FLOW_POP` / `INCOME` / `CONSUMPTION` + 점포 집계 | 상권 식별/공간 메타와 관측 지표를 분리. 상권 총점포 수는 업종별 집계와 구분 | 분리 |
| `점포` | `FACT_AREA_STORE` + `FACT_AREA_SALES` | 상권×업종×기간 grain 도입 | 분리 |
| `프랜차이즈` | `DIM_FRANCHISE` + `DIM_HEADQUARTER` + `DIM_DISCLOSURE_VERSION` + 브랜드/본부 FACT | 브랜드·본부·공개서 버전·기간·지역 단위로 분리 | 분리·검증 보류 |

구모델 `schema.sql`에는 7개 테이블에 총 58개 컬럼이 있다. 신규 .damx에는 49개 테이블/SRC 21·DIM 10·FACT 18, 총 621개 물리 컬럼을 식별했다. 컬럼 58개에 대한 매핑 후보를 전수 작성했으나 **컬럼 의미 일치나 1:1 무손실 마이그레이션 검증이 끝난 것은 아니다.**

## 3. 발견된 주요 문제 (우선순위 순)

| ID | 유형 | 현재 관찰/리스크 | 개선 제안 | 조치 단계 |
| --- | --- | --- | --- | --- |
| R01 | 기간 정보 | `점포`의 PK는 (서비스_업종_코드, 상권_코드)이며 기간을 구분하지 못함 | DIM_PERIOD와 기간 포함 grain 정의 | Phase 2 |
| R02 | 혼합 grain | `상권정보`에 위치·시설·인구·소득·소비·점포 총계가 함께 저장됨 | DIM_AREA와 주제별 FACT 분리 | Phase 2~3 |
| R03 | 공시 측정단위 | `프랜차이즈`에 본부 재무·브랜드 점포·비용·계약이 혼재 | 본부/브랜드/버전/기간/지역 식별 | Phase 2~3 |
| R04 | 서로 다른 업종체계 | 구모델 `프랜차이즈.업종코드`가 서비스 업종 FK로 직접 연결됨 | 코드 간 매핑 규칙·매핑률·미분류 이력 별도 관리 | Phase 2~4 |
| R05 | 데이터 lineage | 구모델에 배치ID·원천 행·수집 시점이 없음 | SRC 원문/수집배치/lineage 설계; 재현성 검증 | Phase 3~4 |
| R06 | 수치/결측 | 새 SRC 수치가 문자열이어서 형변환 시 손실 위험 | 단위, 문자인 결측/비공개, NULL 보존, 거절 레코드 추적 | Phase 3~4 |
| R07 | 기존 추천 | 현재 Notebook은 표준화 없이 유사도 계산, `fillna(0)` 적용. 기간 없음 | 구 로직 baseline 보존, 새 분석 그레인과 구분 | Phase 6 |
| R08 | 문서/실행 불일치 | `docs/recommendation-design.md`에는 통합 원데이터 43개 중 36개 특성이라고 설명하지만 현재 `schema.sql`의 `상권정보`에는 19개 컬럼(식별 7개 제외 12개)이 있음 | 원본 연구와 현재 데모 기준 분리 표기 | Phase 1 문서 및 Phase 6 |
| R09 | 비결정 키 | 구모델 `프랜차이즈.등록번호`의 정확한 등록 체계가 명시되지 않음 | FTC 공시번호/브랜드관리번호/법인·사업자번호 여부 확인 전 추론 금지 | Phase 2 |
| R10 | 차원 유효기간 | 목표 `DIM_AREA` 등에는 버전/유효기간이 있으나 FACT와 차원 버전 연결 규칙 미정 | 대상 시점으로 유효한 surrogate key를 찾는 정책 | Phase 2 |
| R11 | 좌표체계 | legacy 좌표 INT, 목표 좌표 DECIMAL 및 좌표계 코드 보유 | 원천 CRS와 EPSG:5181 변환 가정 확인 | Phase 2~4 |
| R12 | 원본/데모 데이터 | 공개 저장소에는 합성 demo seed만 있음 | 합성 데이터는 구조 테스트에만 사용. 실제 통계 결과/성능 주장 금지 | 전 단계 |

## 4. Phase 1 설계 결정(구현 미착수)

1. **main 유지**: `sql/schema.sql`, 기존 demo/notebook은 보존하고 `feature/data-warehouse-v2`에서 검토·개발한다.
2. **전면 49개 테이블 생성 지양**: 상권×업종×기간 분석 흐름에 필요한 P0 **11개 테이블**부터 vertical slice로 구축.
3. **원천 텍스트/분석 숫자 분리**: `SRC_*`에 원천 문자열과 수집 메타데이터 보존 후 `DIM/FACT`에 검증된 값 적재.
4. **legacy → new 일괄 INSERT 금지**: 기존 7개 테이블의 관측 기간·단위·버전 부족을 실제 신규 원천 데이터로 보완할 때만 적재.
5. **서울시/FTC 업종 차이 명시**: 코드 표준화는 별도 명시적 mapping policy를 만들고 `DIM_INDUSTRY` 직접 FK가 서로 다른 분류 체계의 동등성을 보장한다고 주장하지 않음.
6. **사실성 유지**: 기존 대학 팀 프로젝트 기여와 이번 개인 재구성의 신규 구현·검증 결과를 포트폴리오에 구분한다.

## 5. Phase 2A 완료 조건 (합의 전 초안)

- [ ] P0 11개 테이블에 대한 실행 가능한 MySQL 8 DDL 및 제약조건 정리.
- [ ] 각 FACT의 natural key / source grain / UNIQUE / NULL·0 처리 기준 명시.
- [ ] 기간/관측기간 불일치 처리, 동일 원천 재적재 idempotency 정책 명시.
- [ ] 최소 합성 seed와 적재·조회 SQL, 오류/예외 케이스 테스트 구성.
- [ ] 상권×업종×기간 점포 수/추정매출 SELECT 검증.
- [ ] main의 기존 demo 경로에 회귀 없음 확인.
- [ ] Phase 2B의 FTC 통합 전 업종코드 crosswalk 설계 검토.

## 6. 아직 미결정인 설계 쟁점

- `DIM_AREA`의 유효기간 및 버전 업데이트 정책: 기존 row overwrite 금지 여부, 기준 시점과 겹치는 버전 처리.
- `FACT_AREA_STORE`의 관측 기간(`observation_period_key`)을 자연키에 포함할지. 원천 분기와 관측 기간이 다를 때 중복 허용 범위.
- `DIM_INDUSTRY`의 소스 체계 분리/분류 버전과 프랜차이즈간 N:M 매핑 정책.
- 배치 메타데이터/데이터 lineage와 source document version의 전역 UNIQUE 범위.
- `DIM_REGION`와 서울 자치구·행정동 포함 관계 및 가맹본부 지표의 지역 집계 수준.
- 신규 ERD .damx의 물리 FK/PK 인덱스·복합키 상세 및 NULL 제약을 MySQL DDL로 만들기 전 재확인.

**판정**: Phase 1의 **비교·전수 매핑·우선순위 결정 문서화는 완료**. 위 미결정 사항은 Phase 2 설계 검증 체크포인트로 이관하며, 실제 이관·테스트가 완료된 것으로 간주하지 않는다.
