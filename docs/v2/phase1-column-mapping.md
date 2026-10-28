# Phase 1 — 기존 DB ↔ 신규 ERD 속성 매핑 (58/58)

> 기준: `main/sql/schema.sql`의 7개 테이블 58개 컬럼과 사용자 제공 `상권분석ERD(1).damx`의 대상 테이블/컬럼 명칭. **설계 후보 매핑**이며 데이터 변환 또는 DDL 적용 완료를 뜻하지 않습니다.
>
> 대상 ERD SHA-256: `0fd22beb5239b071b39035deb3adb1485cc4261a07283927d3bca75f4d3de1b0`. 개인 전달 원본 파일은 저장소에 포함하지 않습니다.

## 판정 기준

- **DIRECT**: 같은 의미의 기준정보 속성. 코드 체계 검증 필요.
- **LOOKUP**: business key → 차원 surrogate key 조회. 원본 키를 신규 FK에 직접 대입하지 않음.
- **CONVERT**: 데이터 형식·단위 변환; 원천 지표의 정의와 시점을 우선 검증.
- **MOVE**: 지표를 기간·차원을 포함하는 FACT로 분리. 기간 미확인 legacy 데이터는 해당 FACT에 임의 삽입하지 않음.
- **RECOMPUTE**: grain이 달라 직접 이동 불가. 분석용 집계로 재생성.
- **CHECK**: 이름 유사성만으로 대응 불가. 원천 데이터·코드북 검증 전 마이그레이션 보류.

| 기존 테이블 | 기존 컬럼 | 신규 목적지(후보) | 판정 | 변환/검증 조건 |
| --- | --- | --- | --- | --- |
| `상권_구분` | `상권_구분_코드` | `DIM_AREA_TYPE.area_type_code` | LOOKUP | business key; DIM_AREA.area_type_key 연결 |
| `상권_구분` | `상권_구분명` | `DIM_AREA_TYPE.area_type_name` | DIRECT | 코드-명칭 대응 검증 |
| `자치구` | `자치구_코드` | `DIM_DISTRICT.district_code` | LOOKUP | INT → VARCHAR; 앞자리 0 등 원천 코드 보존 확인 |
| `자치구` | `자치구명` | `DIM_DISTRICT.district_name` | DIRECT | 행정구역 버전 확인 |
| `행정동` | `행정동_코드` | `DIM_DONG.dong_code` | LOOKUP | INT → VARCHAR; 코드 체계와 행정구역 개편 확인 |
| `행정동` | `행정동명` | `DIM_DONG.dong_name` | DIRECT | 동명 중복 가능; 이름으로 JOIN 금지 |
| `서비스_업종` | `서비스_업종_코드` | `DIM_INDUSTRY.service_industry_code` | LOOKUP | 서울시 업종 코드 체계 기준; 분류 버전 필요 |
| `서비스_업종` | `서비스_업종명` | `DIM_INDUSTRY.service_industry_name` | DIRECT | 이름을 키로 사용하지 않음 |
| `상권정보` | `상권_구분_코드` | `DIM_AREA.area_type_key` | LOOKUP | DIM_AREA_TYPE.area_type_code를 통해 surrogate key 조회 |
| `상권정보` | `상권_코드` | `DIM_AREA.area_code` | LOOKUP | INT → VARCHAR; 상권 버전/유효기간 함께 식별 |
| `상권정보` | `상권_코드_명` | `DIM_AREA.area_name` | DIRECT | 명칭 변경 이력 검토 |
| `상권정보` | `엑스좌표_값` | `DIM_AREA.x_coordinate` | CONVERT | INT → DECIMAL; EPSG 좌표계 검증 |
| `상권정보` | `와이좌표_값` | `DIM_AREA.y_coordinate` | CONVERT | INT → DECIMAL; EPSG 좌표계 검증 |
| `상권정보` | `자치구_코드` | `DIM_AREA.district_key` | LOOKUP | DIM_DISTRICT.district_code를 기준으로 조회 |
| `상권정보` | `행정동_코드` | `DIM_AREA.dong_key` | LOOKUP | DIM_DONG.dong_code를 기준으로 조회 |
| `상권정보` | `영역_면적` | `DIM_AREA.area_size` | CONVERT | FLOAT → DECIMAL; 단위 검증 |
| `상권정보` | `집객시설_수` | `FACT_AREA_FACILITY.attracting_facility_count` | MOVE | 기간/관측기간 없는 legacy snapshot; 임의 시점 생성 금지 |
| `상권정보` | `아파트_단지_수` | `FACT_AREA_APARTMENT.apartment_complex_count` | MOVE | 기간/관측기간 복원 필요 |
| `상권정보` | `남성_직장_인구_수` | `FACT_AREA_WORK_POP.male_work_population` | MOVE | 성별 인구 단위/관측기간 확인 |
| `상권정보` | `여성_직장_인구_수` | `FACT_AREA_WORK_POP.female_work_population` | MOVE | 남녀 합계와 total_work_population 검증 |
| `상권정보` | `총_상주인구_수` | `FACT_AREA_RESIDENT_POP.total_resident_population` | MOVE | 기준 기간 복원 필요 |
| `상권정보` | `남성_유동인구_수` | `FACT_AREA_FLOW_POP.male_flow_population` | MOVE | 원천 지표 정의 및 관측기간 확인 |
| `상권정보` | `여성_유동인구_수` | `FACT_AREA_FLOW_POP.female_flow_population` | MOVE | 남녀 합계와 total_flow_population 검증 |
| `상권정보` | `월_평균_소득_금액` | `FACT_AREA_INCOME.monthly_average_income` | CONVERT | INT → DECIMAL; 금액 단위/기준기간 확인 |
| `상권정보` | `소득_구간_코드` | `FACT_AREA_INCOME.income_bracket_code` | CONVERT | INT → VARCHAR; 코드 표준 확인 |
| `상권정보` | `지출_총금액` | `FACT_AREA_CONSUMPTION.total_expenditure_amount` | CONVERT | INT → DECIMAL; 기간 및 화폐 단위 확인 |
| `상권정보` | `점포_수` | `FACT_AREA_STORE.store_count (집계값)` | RECOMPUTE | 상권 총계 vs 신규 상권×업종×기간 grain 불일치; 업종별 FACT 합산 또는 별도 집계 VIEW |
| `점포` | `서비스_업종_코드` | `FACT_AREA_SALES.industry_key / FACT_AREA_STORE.industry_key` | LOOKUP | DIM_INDUSTRY의 서울시 업종코드로 변환 |
| `점포` | `상권_코드` | `FACT_AREA_SALES.area_key / FACT_AREA_STORE.area_key` | LOOKUP | DIM_AREA 버전 및 시점 일치 확인 |
| `점포` | `매출` | `FACT_AREA_SALES.estimated_sales_amount` | CHECK | legacy 매출의 서울시 추정매출 정의와 기간/단위 확인 |
| `점포` | `점포_수` | `FACT_AREA_STORE.store_count` | MOVE | 상권×업종×기간 grain으로 확장; 중복/누락 검사 |
| `프랜차이즈` | `상호명` | `DIM_FRANCHISE.brand_name (또는 DIM_HEADQUARTER.company_name)` | CHECK | 상호명 의미가 브랜드/가맹본부 중 무엇인지 원천 확인 |
| `프랜차이즈` | `등록번호` | `DIM_DISCLOSURE_VERSION.disclosure_no (후보)` | CHECK | 브랜드키·정보공개서번호·사업자등록번호 여부 확인 전 연결 금지 |
| `프랜차이즈` | `자산` | `FACT_HQ_FINANCE.assets` | MOVE | 가맹본부별 결산년도·연결/별도 회계범위 필요 |
| `프랜차이즈` | `부채` | `FACT_HQ_FINANCE.liabilities` | MOVE | 재무 기준년도 및 단위 확인 |
| `프랜차이즈` | `자본` | `FACT_HQ_FINANCE.capital` | MOVE | 재무 기준년도 및 단위 확인 |
| `프랜차이즈` | `매출액` | `FACT_HQ_FINANCE.revenue` | MOVE | 브랜드가 아닌 가맹본부 재무인지 검증 |
| `프랜차이즈` | `영업이익` | `FACT_HQ_FINANCE.operating_income` | MOVE | 가맹본부 단위와 기간 확인 |
| `프랜차이즈` | `당기순이익` | `FACT_HQ_FINANCE.net_income` | MOVE | 가맹본부 단위와 기간 확인 |
| `프랜차이즈` | `가맹점수` | `FACT_FRANCHISE_STORE.franchise_store_count` | MOVE | 지역 및 기준 연도 필요 |
| `프랜차이즈` | `직영점수` | `FACT_FRANCHISE_STORE.direct_store_count` | MOVE | 지역 및 기준 연도 필요 |
| `프랜차이즈` | `신규개점` | `FACT_FRANCHISE_CHANGE.new_store_count` | MOVE | 집계 기간 및 명칭 정의 확인 |
| `프랜차이즈` | `계약종료` | `FACT_FRANCHISE_CHANGE.contract_expired_count` | MOVE | 만료 vs 해지 분류 검증 |
| `프랜차이즈` | `계약해지` | `FACT_FRANCHISE_CHANGE.contract_terminated_count` | MOVE | 만료 vs 해지 분류 검증 |
| `프랜차이즈` | `평균매출액` | `FACT_FRANCHISE_AVG_SALES.average_sales_amount` | MOVE | 지역/기준 연도 필요; 상권 추정매출과 혼합 금지 |
| `프랜차이즈` | `면적당_평균_매출액` | `FACT_FRANCHISE_AVG_SALES.sales_amount_per_area` | MOVE | 면적 단위 확인 |
| `프랜차이즈` | `광고비` | `FACT_AD_PROMOTION.advertising_amount` | MOVE | 가맹본부 및 사업 연도 필요 |
| `프랜차이즈` | `판촉비` | `FACT_AD_PROMOTION.promotion_amount` | MOVE | 가맹본부 및 사업 연도 필요 |
| `프랜차이즈` | `가입비` | `FACT_FRANCHISE_STARTUP_COST.joining_fee` | MOVE | 정보공개서 버전 기준 |
| `프랜차이즈` | `교육비` | `FACT_FRANCHISE_STARTUP_COST.training_fee` | MOVE | 정보공개서 버전 기준 |
| `프랜차이즈` | `보증금` | `FACT_FRANCHISE_STARTUP_COST.security_deposit` | MOVE | 정보공개서 버전 기준 |
| `프랜차이즈` | `기타비용` | `FACT_FRANCHISE_STARTUP_COST.other_cost` | MOVE | 정보공개서 버전 기준 |
| `프랜차이즈` | `단위면적당_인테리어비용` | `FACT_FRANCHISE_INTERIOR.interior_cost_per_area` | MOVE | 시공 규격 specification_code/면적 단위 확인 |
| `프랜차이즈` | `인테리어_비용` | `FACT_FRANCHISE_INTERIOR.interior_total_cost` | MOVE | 기준 점포 면적/규격 확인 |
| `프랜차이즈` | `최초_계약기간` | `DIM_DISCLOSURE_VERSION.initial_contract_period` | CONVERT | 계약 단위 initial_contract_unit_code가 없으므로 확인 필요 |
| `프랜차이즈` | `연장_계약기간` | `DIM_DISCLOSURE_VERSION.renewal_contract_period` | CONVERT | 계약 단위 renewal_contract_unit_code 확인 필요 |
| `프랜차이즈` | `업종코드` | `DIM_FRANCHISE.industry_key (매핑 후)` | CHECK | FTC 업종과 서울시 서비스 업종은 코드 체계가 달라 별도 crosswalk 필수 |
| `프랜차이즈` | `영업명` | `DIM_FRANCHISE.brand_name (후보)` | CHECK | sample_queries.sql에서는 브랜드명처럼 사용; 상호명과 차이 확인 |

## 미매핑/신규 도입 속성

이 표는 **구모델 58개 컬럼의 목적지**를 다룹니다. 신규 ERD의 `SRC_*` 메타데이터(`collection_batch_id`, `source_document_id`, `source_row_id`, `source_url`, `raw_record_text`, `collected_at` 등), `DIM_PERIOD`의 기간키, 각 `*_key`, `lineage_group_id`, `loaded_at`, 차원 유효기간과 버전 번호는 구모델에 없으므로 실제 원천 수집/파이프라인에서 **새로 생성 또는 검증**해야 합니다. NULL/기본값으로 슬쩍 채우거나 출처·시간을 임의로 만드는 방식은 금지합니다.

### 검증할 업무키(Phase 2 진입 전)

1. **상권**: `area_code` + 기준 시점과 `version_no/effective_start_date`; 신규 `area_key`만으로 동일 상권 의미가 유지되는지 확인.
2. **상권·업종 FACT**: `period_key × area_key × industry_key` (원천 관측기간이 다르면 `observation_period_key` 정책도 명시).
3. **가맹본부·브랜드**: `headquarter_management_no` / `brand_management_no`와 구모델 `등록번호`의 의미부터 확인.
4. **FTC 매핑**: `SRC_FTC_DISCLOSURE.source_industry_code`를 `DIM_INDUSTRY.service_industry_code`에 그대로 JOIN하지 않음. 코드 체계간 매핑 테이블/매핑규칙 및 1:N·미매핑 처리를 먼저 설계.
5. **시간·단위**: legacy snapshot에는 기간·지역·공개서 버전이 없는 지표가 있어 `FACT_*`에 무조건 이관 불가. 유형별 실제 원천으로 재적재하고 legacy 값은 비교 대상으로만 사용.

## 범위

원천 행 단위 보존, 신규 ERD의 관계·PK/FK·인덱스·컬럼 Nullability·DDL 실행 가능성은 **Phase 2 검증 대상**. Phase 1에서는 원본 데이터가 없는 한 일치가 입증되지 않은 대응을 `CHECK`/조건부 매핑으로 표시합니다.
