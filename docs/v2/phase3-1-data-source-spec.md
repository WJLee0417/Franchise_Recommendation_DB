# Phase 3-1 — 공공데이터 조사 및 수집 계약 v0.1

> 조사일: 2026-10-28. **문서/메타데이터 확인**과 **실제 API 호출·샘플 필드 검증**을 구분한다. `config/data_sources.v1.json`을 데이터 소스 인벤토리의 기계 판독 원본으로 삼는다. 별도 서비스키 발급·API 응답 검증·실제 수집/적재는 아직 하지 않았다.

## 1. 적용 범위

- P0/P1/P2가 정의한 SRC 21개 전수에 대해 후보 데이터셋·URL·제공방식·갱신주기·natural key 후보·매핑 가능성/블로커를 기록했다.
- 현재 스키마 `SRC_*`의 수집 배치/원천 문서/레코드 경로 복합 UNIQUE는 **수집 이력 키**로 사용한다. 업무상 중복 관측을 방지하는 key는 별개이며 API 샘플로 검증해야 한다.
- 원천 기간은 포털 갱신일/공시 발행일/통계 기준기간/실제 관측기간을 각각 저장한다. 같은 값으로 가정하지 않는다.
- 인증 키는 환경변수/로컬 시크릿으로만. 원본 CSV/API 응답·인가된 저작물 재배포는 개별 이용조건 검토 후 결정한다.

## 2. 서울시 상권분석서비스(서울신용보증재단)

| 대상 SRC | 서비스 ID | 제공 방식(메타데이터 기준) | 갱신·범위 | natural key 후보 | 판정 |
| --- | --- | --- | --- | --- | --- |
| SRC_SEOUL_AREA | OA-15560 | SHP/ZIP, OpenAPI | 비정기, 공간 개편 | 상권코드 + 지리경계/버전 | 후보 확인 |
| SRC_SEOUL_SALES | OA-15572 | CSV/ZIP, OpenAPI | 분기, 2021년 이후 제한 | 기준년분기 + 상권코드 + 서비스업종코드 | 우선 검증 |
| SRC_SEOUL_STORE | OA-15577 | CSV/ZIP, OpenAPI | 포털 표기 연간 vs 데이터 분기 | 기준년분기 + 상권코드 + 서비스업종코드 | 우선 검증 |
| SRC_SEOUL_FACILITY | OA-15580 | OpenAPI, 파일 상세 확인 필요 | 연 1회 특성 / 분기코드 | 기준년분기 + 상권코드 | 후보 확인 |
| SRC_SEOUL_APARTMENT | OA-15566 | OpenAPI, 파일 상세 확인 필요 | 연간 | 기준년분기 + 상권코드 | 후보 확인 |
| SRC_SEOUL_FLOW_POP | OA-15568 | OpenAPI | 월/분기 표기 불일치 | 기준년분기 + 상권코드 | 검증 필요 |
| SRC_SEOUL_RESIDENT_POP | OA-15584 | OpenAPI | 연간 실측과 분기 반영 | 기준년분기 + 상권코드 | 후보 확인 |
| SRC_SEOUL_WORK_POP | OA-15569 | OpenAPI | 반기·연간 메타데이터 불일치 | 기준년분기 + 상권코드 | 검증 필요 |
| SRC_SEOUL_CONSUMPTION | OA-21278 | 과거 스냅샷 가능성 | 상권단위 신규 갱신 중단 | archive document + 기록키 | **자동수집 보류** |
| SRC_SEOUL_INCOME_ARCHIVE | OA-21278 과거 자료 | archive 확보시만 | 2020년 데이터 공급 중단 및 컬럼 폐지 | 문서·과거 분기 | **자동수집 보류** |

### 서울시의 중대한 변경점

**2026-07-03부터** 서울시 상권분석 데이터셋 43개에 대해 공개 범위가 2021년 이후 자료로 제한되었다. 2024년부터 공간 단위는 표준단위구역으로 변경됐으므로 **2023↔2024 상권 코드를 같은 지역경계로 자동 연결하지 않는다.** 추정매출액은 카드 기반 통계적 **추정값**이므로 실제 전표 매출로 표현하면 안 된다.

**소비·소득은 중단/폐지 리스크**가 있어 P1 `FACT_AREA_INCOME`/`FACT_AREA_CONSUMPTION`을 현행 수치로 갱신한다고 전제할 수 없다. 데이터셋이 열리더라도 실제 컬럼과 갱신 시점이 존재하는지 확인할 때까지 **DISABLED**를 유지한다.

공식 공지: https://data.seoul.go.kr/together/notice/datasetNoticeView.do?bbsCd=10008&ditcCd=&pageIndex=1&seq=a2197dabd5a3a52edd6fe0d4eead6bd3

## 3. 공정거래위원회(공공데이터포털)

| 대상 SRC | 후보 서비스 | 제공형식 | 식별키 후보 | 상태/한계 |
| --- | --- | --- | --- | --- |
| SRC_FTC_DISCLOSURE | 15125467 브랜드 목록 | REST JSON/XML | 브랜드관리번호 + 가맹사업기준년도 | 원천 목록 확인. 정보공개서 버전 번호까지 제공되는지는 불확실 |
| SRC_FTC_FINANCE | 15165094 외식업 통합 | REST JSON/XML | 가맹본부관리번호 + 회계연도 + 회계범위 | 자산/부채 등 세부 컬럼 미확인 |
| SRC_FTC_STORE | 15165094 외식업 통합 | REST JSON/XML | 브랜드관리번호 + 년도 + 지역 | 지역별 수치/지역코드 미확인 |
| SRC_FTC_STORE_CHANGE | 15109824 업종별 변동 | REST JSON/XML | 년도 + 업종 | **업종 집계**라 브랜드 FACT에 직접 연결 금지 |
| SRC_FTC_AVG_SALES | 15165094 외식업 통합 | REST JSON/XML | 브랜드관리번호 + 연도 + 지역 | 정확한 평균 매출액/단위 필드 검증 필요 |
| SRC_FTC_CONTRACT | 15165094 외식업 통합 | REST JSON/XML | 브랜드관리번호 + 공시 기준년도 | 계약기간 일부 존재 설명, 공시 버전 키 미확인 |
| SRC_FTC_STARTUP_COST | 15125475 가맹 사업자 부담금 | REST JSON/XML | 브랜드관리번호 + 기준년도 | 해당 API 공식 제공 확인 |
| SRC_FTC_INTERIOR | 15165094 외식업 통합 후보 | REST JSON/XML | 브랜드관리번호 + 공시년도 + 규격 | 점포규격/단가 실제 제공 불확실 |
| SRC_FTC_AD_PROMOTION | 미확인 | - | 본부 + 기간 후보 | **출처 확정 전 수집 불가** |
| SRC_FTC_EMPLOYEE | 15165094 외식업 통합 후보 | REST JSON/XML | 본부 + 기간 후보 | 고용 데이터 설명은 있으나 임직원 구분 미확인 |
| SRC_FTC_LEGAL | 15125466 법적 사항 후보 | REST JSON/XML | 본부 + 공시년도 + 사건 후보 | 형벌선고만으로 시정조치/민사 포함 불가 |

공공데이터포털에서 API의 업데이트 주기를 **실시간**으로 표기해도, 회계 연도 및 공시 지표가 실시간 변하는 것은 아니다. 통계 기준연도·정보공개서 갱신일·수집 일시를 나눠 기록한다. 가입비/교육금액/부담금 단위는 실제 명세 응답에서 검증한다.

**주의:** 15165094는 **외식업종 한정 통합 데이터**이므로 이를 전체 프랜차이즈 업종 자료로 표시하지 않는다. 15165160은 원본 금액과 식별번호를 제공하지 않는 **합성 데이터**이므로 실제 금액/브랜드 분석을 위한 원천으로 채택하지 않았다.

## 4. 구체적 수집 계약

| 항목 | 확정 정책 |
| --- | --- |
| Collector ID | `source_table` + `dataset_id` 또는 `api_id`; 임의로 테이블명만으로 API 호출하지 않음 |
| 데이터 포맷 | 서울 CSV/ZIP·SHP 또는 OpenAPI, FTC REST JSON/XML; 응답 타입 검사 후 파싱 |
| 배치 ID | 실행 시 고유 ID. 소스 문서/URL, 요청 파라미터, HTTP 상태, 취득시각, 파일 hash를 별도 manifest에 기록 |
| 레코드 경로 | 파일명 + 물리 행번호 / API page + item 위치(안정성이 보장되는 경우 natural key); 동일 배치 재시도는 UNIQUE로 중복 차단 |
| 기간 | `base_year_quarter`, `business_year`, `fiscal_year`, `publication_date`, `observed_period`, `collected_at`을 혼동하지 않음 |
| 적재 방식 | SRC 단계 원본 문자열·원문을 보존; 변환 실패는 별도 quarantine/reject 로깅 후 DIM/FACT 적재 차단 |
| 코드 매핑 | 서울 서비스 업종 코드 ↔ FTC 업종 분류는 별도 매핑표와 버전/매핑근거/매핑예외 관리 |
| 범위 변경 | 2024년 상권 경계 변경 전후 동일 `area_code`라도 버전·기간별 유효성 확인 |
| 갱신 스케줄 | **보류**: 자동 배치 시간은 실제 endpoint/sample의 유효 기간·게시 지연 확인 전 결정하지 않음 |
| 인증 | 서울 OpenAPI 인증키 및 공공데이터포털 서비스키. 공용 레포나 로그에 비밀값 출력 금지 |
| 데이터 배포 | 서울 공공누리 1유형 출처표시 등 개별 데이터셋 라이선스 확인, 외부 배포 시 원천별 이용조건 준수 |
| 실수 방지 | 모든 source 초기 상태 `DISABLED_UNTIL_SAMPLE_VALIDATION`, 검증되지 않은 매핑으로 FACT 적재 금지 |

### 요구되는 원천 샘플 증빙 (Phase 3-2 진입 Gate)

1. **서울 P0 세 종류**의 실제 응답/CSV 1건 이상에서 파일 인코딩·헤더·null 표현·기준분기·상권코드·업종코드·단위 및 영역의 geometry 버전 추출.
2. **FTC 브랜드/창업 부담금**의 실제 REST 응답에서 API auth·페이지네이션·기준년도·브랜드관리번호·가맹본부관리번호가 어떻게 나타나는지 확인.
3. `SRC_FTC_DISCLOSURE.disclosure_no`가 실제 *공개서번호*로 존재하는지, 아니면 브랜드관리번호로만 확인되는지 검증. 다르면 `DIM_DISCLOSURE_VERSION` 매핑은 비활성화.
4. FTC 통합 API의 외식업 한정 커버리지, 본부·브랜드·지역별 row grain, 숫자 단위/지역코드 제공 여부 검증.
5. 중단된 서울 소득·소비나 미확인 FTC 광고·판촉비는 **수집 대상을 확정된 것으로 표기하지 않음**.

## 5. 출처 (공식)

- 서울 추정매출: https://data.seoul.go.kr/dataList/OA-15572/S/1/datasetView.do
- 서울 점포: https://data.seoul.go.kr/dataList/OA-15577/S/1/datasetView.do
- 서울 상권 영역: https://data.seoul.go.kr/dataList/OA-15560/S/1/datasetView.do
- 서울 공개기간 변경 공지: https://data.seoul.go.kr/together/notice/datasetNoticeView.do?bbsCd=10008&ditcCd=&pageIndex=1&seq=a2197dabd5a3a52edd6fe0d4eead6bd3
- 공정위 브랜드 목록: https://www.data.go.kr/data/15125467/openapi.do
- 공정위 가맹점 사업자 부담금: https://www.data.go.kr/data/15125475/openapi.do
- 공정위 외식업종 통합정보: https://www.data.go.kr/data/15165094/openapi.do
- 공정위 업종별 변동: https://www.data.go.kr/data/15109824/openapi.do
- 공정위 합성데이터(정식 재무 원천에서 제외): https://www.data.go.kr/data/15165160/fileData.do

모든 링크는 **출처 메타데이터 페이지**다. API 호출 endpoint와 실제 필드명/서비스키는 자동으로 생성하지 않으며, 다음 단계에서 오픈API 명세서와 실제 응답으로 확인한다.
