# Phase 2-1 — P0 MySQL 8 DDL / 데이터 무결성 설계

## 산출물 및 분리 원칙
- DDL: [sql/v2/p0/001_schema.sql](../../sql/v2/p0/001_schema.sql)
- Smoke/negative 테스트: [sql/v2/p0/tests/001_integrity_smoke.sql](../../sql/v2/p0/tests/001_integrity_smoke.sql)
- 데이터베이스: `franchise_dw_p0`. 기존 `sql/schema.sql`, `franchise_demo`와 분리.
- 대상: 원본 ERD의 **P0 11개 물리 테이블, 135개 원본 모델 속성** (SRC 63, DIM 53, FACT 19). 구현 편의상 `DIM_AREA.current_area_code`, `DIM_INDUSTRY.current_industry_code` 두 STORED 생성 컬럼을 **추가**하여 현재 행 유일성을 DB에서 강제한다.
- 원천 ERD `상권분석ERD(1).damx`의 테이블/컬럼/자료형을 기준으로 하며, NULL/PK/UK/FK/CHECK는 설계 보강이다. 기본 데이터의 실제 의미·관측 시점이 입증되기 전 적재했다고 가정하지 않는다.

## 1. 테이블

| 층 | 테이블 | Grain / 식별 기준 |
| --- | --- | --- |
| SRC | `SRC_SEOUL_AREA` | 수집 배치×문서×원천 레코드 경로 |
| SRC | `SRC_SEOUL_SALES` | 수집 배치×문서×원천 레코드 경로 |
| SRC | `SRC_SEOUL_STORE` | 수집 배치×문서×원천 레코드 경로 |
| DIM | `DIM_AREA_TYPE` | 상권 유형 코드 |
| DIM | `DIM_DISTRICT` | 자치구 코드 |
| DIM | `DIM_DONG` | 행정동 코드 |
| DIM | `DIM_PERIOD` | 달력×기간 유형×기간 코드 |
| DIM | `DIM_AREA` | 상권코드×차원 버전번호 |
| DIM | `DIM_INDUSTRY` | 서비스 업종코드×분류 버전×유효 시작일 |
| FACT | `FACT_AREA_SALES` | 기준기간×상권 버전×업종 버전 |
| FACT | `FACT_AREA_STORE` | 기준기간×관측기간×상권 버전×업종 버전 |

### 2. 제약 정책

- **PK/UK**: 모든 DIM은 surrogate PK를 사용한다. `DIM_AREA(area_code, version_no)`, `DIM_INDUSTRY(service_industry_code, classification_version, effective_start_date)`는 자연 식별자를 별도로 유일화한다. 두 DIM의 `is_current='Y'` 행은 생성 컬럼과 UNIQUE를 통해 코드별 **최대 1건**만 허용한다. **최소 1건**이나 기간 구간 중복까지 보장하지 않는다.
- **FK**: 두 FACT가 DIM의 기간·상권·업종 버전 surrogate를 참조한다. `FACT_AREA_STORE.observation_period_key`도 `DIM_PERIOD`를 참조한다. 삭제·키변경은 RESTRICT. `DIM_AREA`에서 구분·자치구·행정동을 참조한다.
- **CHECK**: 유효 종료일은 종료일 미설정 또는 시작일 초과(종료일 **exclusive**); `is_current='Y'`는 종료일 NULL, 'N'은 종료일 필수. 금액·면적 음수 금지. 개폐업률은 퍼센트 표기 기준 `0~100`. `FACT_AREA_STORE` 점포 수는 UNSIGNED. `DIM_PERIOD` QUARTER는 분기 1~4, 비분기는 분기 NULL.
- **NULL**: 수집 단계에서 미공개·문자형 수치는 원문 문자열로 보존한다. FACT의 추정매출/기본 점포수는 적재 승인된 정상 수치에 한해 NOT NULL; 미확인 값은 NULL→0 대체하지 않고 적재 거부/격리한다. 기타 지표의 미공개값은 NULL 가능.
- **Lineage**: SRC의 배치ID·문서ID·경로는 유일해야 하며 raw_record_text는 NOT NULL. `lineage_group_id`는 DIM/FACT에서 필수 문자열이나 **SRC까지 추적하는 FK는 아직 없다**. Phase 3에서 배치/계보 실체 테이블과 적재 이력을 설계한다.
- **코드 체계**: 원천 코드는 `VARCHAR`를 유지해 선행 0을 보존한다. `utf8mb4_bin`을 사용해 코드값의 대소문자를 구별한다.
- **기간**: `DIM_PERIOD`의 quarter_no 유효범위와 시작≤종료는 DB에서 강제하지만, `2026Q1`에 해당하는 정확한 날짜, 연도 일치, 연속 기간/겹침 여부는 적재 코드에서 검증해야 한다.

## 3. 정합성 검증과 남은 보완점

| 규칙 | DB 강제 | 후속 ETL/테스트 검증 |
| --- | --- | --- |
| 동일 원천 배치/문서/경로 중복 | UNIQUE | 서로 다른 배치의 동일 문서/내용 재적재 정책 |
| 차원 비즈니스키·버전 중복 | UNIQUE | 버전 시점 구간 중첩·SCD Type2 원자적 전환 |
| Fact 중복 관측값 | 복합 PK | 다른 버전 surrogate가 같은 자연 상권/업종을 가리키는 중복 |
| Fact → DIM 참조 | FK | 측정일이 차원 유효기간 내인지 |
| 수치 음수·비율 0~100 | CHECK / UNSIGNED | `NULL`, 소수/퍼센트, 단위, 공개자료의 정의 |
| 분기 키·기간 시작/끝 | CHECK 일부 | 기간코드/년/분기/달력의 일관성 |
| 실측/관측 기간 | FK/NOT NULL | 발표/관측 시차, FACT_AREA_SALES와 JOIN 시 비교 기간 조건 |
| 상권 자치구/행정동 | FK 각자 | 실제 행정 구역 포함관계·개편 이력 |
| 업종 코드·분류 | DIM 내 유일성 일부 | 서울시↔FTC 코드 매핑(Phase 2B) |
| lineage | 빈 문자열 방지 | 원천 문서/행까지 계보 추적, 완전성 |

### 4. 설계 선택 및 제약

1. **관측 기간 PK 확장**: `FACT_AREA_STORE`는 기존 ERD의 `observation_period_key`를 포함한 4중 복합 PK를 쓴다. *기준기간만 다르지만 관측기간이 같은 값*의 중복은 허용되며 ETL에서 의미적 중복 검사 필요. 매출과 점포 결합 시 보고기간만 같다는 이유로 동일 통계라고 단정하지 않는다.
2. **가용 성능**: `SRC_*` UNIQUE 키의 최대 인덱스 바이트는 `50+200+500=750` UTF-8 4바이트 문자 기준 **3,000바이트**로 InnoDB DYNAMIC/16KB page의 3,072바이트 한도 안쪽이다. 다른 `innodb_page_size`/row format에서는 조정 필요.
3. **현재 버전 동시성**: generated current-code unique는 동시에 두 'Y' 행을 넣지 못하게 하지만 기존 행 종료 후 새 행 삽입은 별도 트랜잭션과 lock 정책이 필요.
4. **DDL 비파괴성**: `CREATE DATABASE IF NOT EXISTS` 후 `CREATE TABLE`은 `IF NOT EXISTS`가 없어서 기존 테이블이 존재할 경우 실패하도록 의도했다. 마이그레이션 도구로의 전환은 추후 진행.
5. **원천 스키마 검증**: SRC의 단위·원문 텍스트를 보존하지만 `VARCHAR(2048)` URL은 인덱싱하지 않음. 원천 실제 최대 길이는 Phase 3에서 확인.

## 5. 로컬 테스트 실행

MySQL 8.0.16+ 서버가 접근 가능한 환경에서:

```bash
mysql -h 127.0.0.1 -u root -p < sql/v2/p0/001_schema.sql
mysql -h 127.0.0.1 -u root -p < sql/v2/p0/tests/001_integrity_smoke.sql
```

테스트 스크립트는 INSERT 성공, 분석 JOIN, 수집 원천 중복 UNIQUE, 상권 current 버전 UNIQUE, FACT 복합 PK, FK, 금액 CHECK, 개업률 CHECK, 관측기간 NOT NULL에 대해 성공/실패를 확인한다. **테스트 데이터는 ROLLBACK**하며 procedure는 DROP한다. 다른 데이터가 들어 있는 운영 DB에서 실행하지 말 것.

**검증 상태:** SQL 파일 작성 및 정적 점검까지만 진행. 현재 작업 환경에 MySQL 서버/컨테이너 실행기가 없어 실제 MySQL DDL/스모크테스트 실행은 수행하지 않았다. 로컬 또는 CI MySQL 8 실행 증거 전에는 '실행 검증 완료'로 표기하지 않는다.

## 6. Phase 2-2로 넘길 항목
- Docker/MySQL CI에서 DDL 및 테스트 실행 검증 + 제약 오류코드별 assertion.
- 날짜/버전 유효성, 단위·원천 포맷 확인, 레거시와 P0의 비교용 fixture.
- 실제 수집 정책과 idempotent 적재(upsert vs 변경이력 append).
- DIM/FACT lineage 키의 참조 무결성 및 ETL reject/quarantine 설계.
