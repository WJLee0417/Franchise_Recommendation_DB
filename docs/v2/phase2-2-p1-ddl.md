# Phase 2-2 — P1 SRC/DIM/FACT 확장 DDL과 무결성 정책

## 범위

Phase 1에서 P1으로 분류한 **27개 테이블**을 `sql/v2/p1/002_schema.sql`에 구현했다. **P0의 11개 테이블이 선행되어야 하며**, 완성 시 P0+P1 합계 38개 테이블이다.

| 계층 | P1 수 | 테이블 | 역할 |
|---|---:|---|---|
| SRC | 12 | `SRC_SEOUL_FACILITY`, `SRC_SEOUL_APARTMENT`, `SRC_SEOUL_FLOW_POP`, `SRC_SEOUL_RESIDENT_POP`, `SRC_SEOUL_WORK_POP`, `SRC_SEOUL_CONSUMPTION`, `SRC_SEOUL_INCOME_ARCHIVE`, `SRC_FTC_DISCLOSURE`, `SRC_FTC_FINANCE`, `SRC_FTC_STORE`, `SRC_FTC_STORE_CHANGE`, `SRC_FTC_AVG_SALES` | 상권 추가 지표·FTC 공시 원문 보존 |
| DIM | 4 | `DIM_HEADQUARTER`, `DIM_FRANCHISE`, `DIM_REGION`, `DIM_DISCLOSURE_VERSION` | 가맹본부·브랜드·지역·공시버전 |
| FACT | 11 | `FACT_AREA_FACILITY`, `FACT_AREA_APARTMENT`, `FACT_AREA_RESIDENT_POP`, `FACT_AREA_FLOW_POP`, `FACT_AREA_WORK_POP`, `FACT_AREA_INCOME`, `FACT_AREA_CONSUMPTION`, `FACT_FRANCHISE_STORE`, `FACT_FRANCHISE_CHANGE`, `FACT_FRANCHISE_AVG_SALES`, `FACT_HQ_FINANCE` | 기간별·지역별 통계/재무 지표 |

모델 기반은 사용자가 제공한 `상권분석ERD(1).damx`의 실제 물리 테이블명·컬럼명·자료형이다. PK/FK/UNIQUE/CHECK, nullable 기준과 현재버전 UNIQUE 강제용 생성 컬럼은 구현 단계에서 보강했다. 원본의 27개 테이블과 27개 정확한 컬럼 구성은 README가 아니라 해당 .damx와 대조할 것.

## 업무 규칙

1. **SRC는 원문 중심**: 원천 숫자가 누락되거나 `N/A` 등 비수치면 그대로 `VARCHAR`/원문 JSON 문자열로 보존. 배치·문서·레코드 경로 UNIQUE로 같은 배치 중복 적재 차단. 다른 수집 배치의 동일 내용은 원천 이력을 유지한다.
2. **가맹본부 vs 브랜드 구별**: `DIM_HEADQUARTER.headquarter_management_no`와 `DIM_FRANCHISE.brand_management_no`는 서로 다른 비즈니스 키. `DIM_FRANCHISE.headquarter_key` FK 필수. 등록번호·공시번호를 관리번호로 가정하지 말 것.
3. **FTC ↔ 서울시 업종 매핑 보류**: `DIM_FRANCHISE.industry_key`는 **NULL 허용**. 두 기관 업종 코드가 동등하지 않으므로 검증된 분류 매핑 후에만 연결. NULL을 임의 기본 업종으로 치환 금지.
4. **지역 비교**: `DIM_REGION` 자연키는 `region_system_code, region_code, region_version`; 현재 지역 버전은 `region_system_code, region_code`별 최대 한 건. 지역명만으로 행정동/자치구를 연결하면 안 됨.
5. **공시 버전**: `DIM_DISCLOSURE_VERSION(disclosure_no, disclosure_version_code)` 유일. 계약기간 숫자와 단위코드는 함께 존재하거나 함께 NULL. 조건종료일은 exclusive. `content_hash`는 선택 사항이며 유효한 64자 HEX로 제한.
6. **FACT grain**: 상권 기본 지표는 (기준기간, 상권 버전), 시설·아파트·상주·유동·직장인구는 추가 (관측기간), 브랜드 점포/평균매출은 (브랜드 버전, 기간, 지역 버전), 점포 변동은 (브랜드 버전, 기간), 본부 재무는 (본부 버전, 기간, 회계범위).
7. **재무 음수의 의미**: 영업이익·당기순이익·자본에는 음수 허용, 자산·부채·매출액에는 0 이상만 허용. 공시 지표의 회계단위/결측 처리/연결·별도 분류는 ETL에서 확인.
8. **수치 검증**: 비음수인 유동인구, 매출, 지출, 소득 등에 CHECK. 성별·연령 합과 총계가 언제나 일치한다고 단정하지 않고, 집계 수준/반올림/비공개 때문에 품질 규칙에서 별도 진단. `NULL`은 0이 아님.
9. **SCD Type2 제한**: 생성 컬럼과 UNIQUE로 현재 행 **중복**만 차단. 시간구간 중첩, 동일 비즈니스의 historical overlap, FACT 기간과 차원 유효구간 일치는 **DDL만으로 완전 보장하지 않음**. Phase 3/4 트랜잭션 및 검증 정책 필요.
10. **Lineage 제한**: DIM/FACT의 `lineage_group_id`는 비어있을 수 없지만 아직 lineage-parent 테이블 FK가 없다. 원천 행까지 연결하는 PK/FK 및 데이터 수집 job 관리는 Phase 3 예정.

## 검증 스크립트

```bash
mysql -h 127.0.0.1 -uroot -p < sql/v2/p0/001_schema.sql
mysql -h 127.0.0.1 -uroot -p < sql/v2/p0/tests/001_integrity_smoke.sql
mysql -h 127.0.0.1 -uroot -p < sql/v2/p1/002_schema.sql
mysql -h 127.0.0.1 -uroot -p < sql/v2/p1/tests/002_integrity_smoke.sql
```

`.github/workflows/warehouse-ddl.yml`이 MySQL 8.0 기반 서비스에서 P0/P1 스키마, 스모크 테스트, 테이블 수 38개를 확인하도록 추가되었다. 현재 모델 내부에서 **정적 목록 검토**는 했지만 **GitHub Actions 성공 또는 실제 DB 실행 결과는 아직 확인되지 않았다**.

### 스모크 테스트가 확인하도록 작성된 조건

- 정상 데이터: FTC 공시 SRC → 본부/브랜드/지역 DIM → 점포/재무 FACT 결합, 상권 지표 및 음수 이익 처리.
- 실패 데이터: 본부 current 이중 버전, 존재하지 않는 HQ FK, 계약 숫자/단위 불일치, 브랜드 FACT 중복, 음수 평균매출, SRC 배치별 중복.
- 테스트는 트랜잭션에서 롤백하고 저장 프로시저를 DROP하나 **기존 프로시저 이름과 중복되면 실패**. 테스트 전용 DB에서만 실행.

## 다음 검증 단계

- **실행 검증**: Actions 결과 확인, MySQL 버전 및 오류 위치 수정, P0/P1 순서 의존성과 데이터베이스 38개 생성 확인.
- **P1 데이터 정합성**: 공시번호·관리번호의 실제 연결 근거, FTC 업종 crosswalk, 지역 표준화, 단위/기간 매핑 정책 확정.
- **그레인/이력 검증**: 기간 중복, 버전 유효구간 겹침, source lineage 및 중복 수집 정책에 대한 데이터 품질 테스트.
- **P2와 분리**: P2 11개 테이블(계약 원천·창업비용·인테리어·광고/판촉·임직원·법적 사건)은 이번 변경에 포함하지 않음.
