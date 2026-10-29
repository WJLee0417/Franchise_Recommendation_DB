# Phase 3-5 공식 자료 보강 — 점포 모델 수정안과 과거 공간·업종·관측기간 근거

## 최종 판정 (2026-10-29)

- **점포 수 지표:** 공식 API의 `STOR_CO=일반`, `FRC_STOR_CO=프랜차이즈`, `SIMILR_INDUTY_STOR_CO=전체`를 확인했다. 과거 원본 457,043행에서 **전체=일반+프랜차이즈**가 100% 성립했다. 과거 한글 컬럼명과 현행 API 명칭의 차이는 출처/버전 문서에 남긴다.
- **공간 경계:** 공식 사이트에서 OA-15560의 ZIP 다운로드 목록, **파일 수정일 2023-10-23**, EPSG:5181을 확인했다. 하지만 파일 실물·폴리곤 버전의 유효기간·2022~2023 분기별 1,650개 영역코드와 일치하는지 **확인하지 못했다**. ZIP 목록의 수정일을 공간 효력일로 간주하지 않는다.
- **업종 코드북:** 서울 공식 100대 생활밀접업종 분류 PDF에서 **한국표준산업분류 10차 세세분류** 기반 분류를 확인했다. 2022~2023 보관본 100개 업종의 시계열·명칭 안정성은 별도로 확인했지만, 공식 PDF의 2022~2023 적용 시작일과 서울 분류 고유의 출시 버전은 여전히 확인되지 않았다.
- **관측기간:** 공식 서비스는 **분기별** 지표 제공과 **약 2개월 후 발표**를 안내한다. 점포 수(당기 운영 점포+폐업 점포), 개·폐업률의 계산 설명도 확인했으나, 원본 분기의 별도 `observation_period_key`를 결정할 수 있는 특정 관측 기준일과 과거 버전의 세부 분모·반올림 규정은 확보하지 못했다. 보고분기를 관측분기로 임의 대입하지 않는다.

## FACT_AREA_STORE 모델 수정안 (심사·별도 이관 전용)

현재 모델 `store_count`와 `similar_industry_store_count`는 **SRC와 같은 컬럼명을 복사했지만 분석 의미가 혼동**되므로 다음으로 명확히 바꾸는 안을 권고한다.

| 물리 컬럼 기존 | 제안 컬럼 | 매핑할 원본 | 의미 |
|---|---|---|---|
| `FACT_AREA_STORE.store_count` | `ordinary_store_count` | `SRC_SEOUL_STORE.store_count` | 일반점포 수 |
| `FACT_AREA_STORE.similar_industry_store_count` | `total_store_count` | `SRC_SEOUL_STORE.similar_industry_store_count` | 전체 점포 수 |
| `FACT_AREA_STORE.franchise_store_count` | 유지 | `SRC_SEOUL_STORE.franchise_store_count` | 프랜차이즈 점포 수 |

**제안 SQL:** `sql/v2/proposals/006_fact_store_metric_semantics.sql`. 실제 운영 DDL에는 미적용; `FACT_AREA_STORE` 기존 0행 환경에서만 별도 검토 후 시험. 물리적으로 분리된 값이 확인되는 경우에만 `total=ordinary+franchise` CHECK를 적용한다. 데이터가 존재할 때에는 비파괴 이관/데이터 계약/다운스트림 인터페이스 검증이 먼저 필요하다.

앞선 '기존 FACT.store_count = 전체 점포수'라는 암묵적인 이름 해석을 고치는 안과 달리, **이 제안은 FACT.store_count를 ordinary_store_count로 명시적으로 바꾸고 전체는 별도 total_store_count로 표현**한다. 이미 생성된 FACT는 0행이었으므로 기존 값 변환 문제는 없지만, 스키마 소비자는 신규 계약으로 변경해야 한다.

## 원본 전수 재검증 — 공식 비율 공식을 그대로 재계산해서는 안 됨

실제 CP949 원본 457,043행을 전수 검사했다. 전체=일반+프랜차이즈는 457,043행 **전부 일치**했다. 그러나 개·폐업률은 간단히 `round(개/폐업점포수 ÷ 원본 전체점포수 ×100)`으로 재계산하면 모두 일치하지 않는다.

- `원본 전체점포수 >0` **453,944행** 중, 일반적인 half-up 반올림 기준으로 **개업률 불일치 272**, **폐업률 불일치 353**.
- 나머지 **전체점포수 0인 3,099행**은 폐업점포 수가 양수인 사례가 3,099행 존재했다.
- 따라서 공식 비율의 계산 분모가 무조건 해당 분기의 현재 `total_store_count`와 같다고 확정하거나 원본 개·폐업률을 재계산·대체해서는 안 된다.
- 결과 요약은 로컬 `phase35_official_metric_reconciliation.json`으로 생성했다. 개인 원천행은 저장소에 올리지 않았다.

## 공식 근거 및 실제 확보 수준

`config/phase35_official_evidence.v1.json`은 다음을 구분한다.

1. 서울 공식 **점포-상권** 데이터셋: https://data.seoul.go.kr/dataList/OA-15577/S/1/datasetView.do
2. 서울 공식 **영역-상권** 데이터셋: https://data.seoul.go.kr/dataList/OA-15560/S/1/datasetView.do
3. 서울 공식 **상권분석서비스 제공정보 PDF**(점포 정의/개폐업률 설명): https://golmok.seoul.go.kr/images/seoul_info.pdf
4. 서울 공식 **100대 생활밀접업종 코드북 PDF**: https://golmok.seoul.go.kr/images/100_v3.pdf
5. 서울 공식 **상권분석서비스 소개 및 분기별 갱신**: https://golmok.seoul.go.kr/introduce.do
6. 과거 공간 스냅샷 **목록만 확인된** 자료: https://www.data.go.kr/data/15076394/fileData.do

**파일 자체 미확보 항목:** 2022~2023 분기별 영역 SCD 유효일·폴리곤, 과거 서울 업종 코드북 공식 발효일·릴리스 번호, 점포 관측기간 및 역사적 분모 상세 명세.

## 품질 규칙과 적재 게이트

기존 STG v0.1 데이터는 절대 수정하지 않는다. 규칙 004(전체 > 일반 WARN), 005(프랜차이즈 > 일반 REVIEW)는 수정 필요성이 높은 것으로 판정. 새 정책/증빙/승인 후에만 별도 `v0.2` 적재 결과를 생성한다. 앞서 계산한 판정 시뮬레이션은 생산 데이터가 아니다.

- **G02**: 영역 버전/유효기간 — BLOCKED
- **G03**: 업종 공식 버전/발효일 — BLOCKED
- **G06**: 점포 관측기간 — BLOCKED
- **G11**: SCD 구간 중복/기간 연결 — BLOCKED
- **G13**: FACT 컬럼 의미 계약/DDL — BLOCKED (수정 제안 준비됨)

## 후속 검증의 명확한 인수조건

- OA-15560의 과거 SHP를 실제 내려받고 ZIP 안의 CRS·파일 날짜·상권코드 집합을 검사하여 **원본 1,650개 area_code**와 연결; 별도 근거로 [start,end) 유효기간을 승인.
- 공식 100개 업종의 특정 릴리스와 적용 기간을 확보해 **원본 100개 코드 및 이름과 일치** 확인.
- 2022~2023 당시 **점포 측정/분모 기준시점**을 확인하고 `observation_period_key`의 보존·변경·제거 중 하나를 공식 근거로 결정.
- FACT 컬럼 명명/지표 정의를 별도 PR로 승인하고 MySQL 8 DDL·마이그레이션 CI 검증.

**현재 DIM/FACT 적재는 보류.** 이번 단계는 근거 수집 및 수정안 기록까지이며, 실제 공간 파일 획득/업종 버전·기간 최종 승인까지 모두 달성한 단계가 아니다.
