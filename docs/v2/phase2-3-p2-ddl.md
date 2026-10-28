# Phase 2-3: P2 11개 테이블 구현 및 검증

## 범위
- 원본: `상권분석ERD(1).damx` SHA256 `0fd22beb5239b071b39035deb3adb1485cc4261a07283927d3bca75f4d3de1b0`.
- 신규 DDL: `sql/v2/p2/003_schema.sql` (P0/P1 이후 실행).
- 신규 테스트: `sql/v2/p2/tests/003_integrity_smoke.sql`.
- 추가 11개 테이블: SRC 6개, FACT 5개; P0 11 + P1 27 + P2 11 = **49개**.
- 기존 main/demo 및 P0/P1 DDL은 변경하지 않음.

## 물리 모델

| 계층 | 신규 테이블 | 핵심 데이터 | 업무 Grain |
|---|---|---|---|
| SRC | SRC_FTC_CONTRACT | 최초/갱신 계약기간 원문 | 배치·문서·원천 레코드 위치 |
| SRC | SRC_FTC_STARTUP_COST | 가입비·교육비·보증금 등 원문 | 배치·문서·원천 레코드 위치 |
| SRC | SRC_FTC_INTERIOR | 점포 면적·인테리어비 원문 | 배치·문서·원천 레코드 위치 |
| SRC | SRC_FTC_AD_PROMOTION | 광고·판촉비 원문 | 배치·문서·원천 레코드 위치 |
| SRC | SRC_FTC_EMPLOYEE | 임직원 수 원문 | 배치·문서·원천 레코드 위치 |
| SRC | SRC_FTC_LEGAL | 시정조치·민사·형사 관련 원문 | 배치·문서·원천 레코드 위치 |
| FACT | FACT_FRANCHISE_STARTUP_COST | 공개서 버전별 창업비용 | disclosure_version_key + franchise_key |
| FACT | FACT_FRANCHISE_INTERIOR | 점포 규격별 인테리어 비용 | disclosure_version_key + specification_code + franchise_key |
| FACT | FACT_AD_PROMOTION | 본부 광고·판촉비 | headquarter_key + period_key |
| FACT | FACT_HQ_EMPLOYEE | 본부 임직원 수 | headquarter_key + period_key |
| FACT | FACT_HQ_LEGAL | 본부 법적 사건 수 | headquarter_key + period_key |

## 제약조건·설계 선택

- **원본 보존**: SRC 6개의 숫자/코드 값은 VARCHAR로 보존한다. 비공개값·비정상값을 0으로 바꾸지 않는다. 수집 중복은 (collection_batch_id, source_document_id, source_record_path) UNIQUE로 차단.
- **공개서·브랜드 관계**: P1 `DIM_DISCLOSURE_VERSION`에 (disclosure_version_key,franchise_key) 복합 UNIQUE를 추가하여, 두 P2 FACT가 두 키를 함께 참조하게 한다. 이는 존재하지만 다른 브랜드 소유인 공개서로 비용을 기록하는 오류를 막는다.
- **창업비**: 0원과 미공개 NULL 구분. 비음수 CHECK; 필수 지표라고 무조건 NOT NULL 지정하지 않음. 에스크로 금액·가맹금의 회계적 범주는 Phase 3에서 코드북 확인.
- **인테리어**: 규격은 공백 금지, 면적은 양수(또는 NULL), 비용은 비음수(또는 NULL). 규격코드는 원천에 자동 제공된다고 가정하지 않고 매핑 정책 마련 필요.
- **본부 FACT**: 회계·공시 기준기간 × 본부 SCD 버전으로 식별. 음수 임직원 수 및 사건 수는 UNSIGNED로 금지. 지표가 비공개인 경우 NULL.
- **유효기간/단위**: 공시서 기준연도, 단위(원/천원/백만원, m²/평), 회계범위, 본부/브랜드 식별의 실질 정합성은 DB FK만으로 보장할 수 없음. 수집 파이프라인에서 검증.
- **이력/lineage**: 모든 FACT에 필수 lineage_group_id. 아직 실제 원천 행을 참조하는 lineage FK는 없으므로 E2E 추적이 구현되었다고 주장하지 않음.
- **실행**: P2는 P1의 공개서 복합키에 인덱스를 추가하는 ALTER를 포함하며, P1 단독 실행 이후 적용할 수 있다.

## 테스트 절차

```bash
mysql -h 127.0.0.1 -uroot -p < sql/v2/p0/001_schema.sql
mysql -h 127.0.0.1 -uroot -p < sql/v2/p0/tests/001_integrity_smoke.sql
mysql -h 127.0.0.1 -uroot -p < sql/v2/p1/002_schema.sql
mysql -h 127.0.0.1 -uroot -p < sql/v2/p1/tests/002_integrity_smoke.sql
mysql -h 127.0.0.1 -uroot -p < sql/v2/p2/003_schema.sql
mysql -h 127.0.0.1 -uroot -p < sql/v2/p2/tests/003_integrity_smoke.sql
```

CI: `.github/workflows/warehouse-ddl.yml`가 MySQL 8 환경에서 순서대로 실행하고 49개 물리 테이블을 확인한다.

P2 smoke: 6개 SRC, 5개 FACT에 synthetic row 삽입, 공개서-브랜드 JOIN, 본부 인원·법적 FACT JOIN, 잘못된 브랜드 FK(1452), 공백 규격 CHECK(3819), 인테리어 PK 중복(1062), 음수 창업비 CHECK(3819), 본부 FACT 중복(1062), SRC 중복(1062) 검사 후 ROLLBACK.

## 완료 기준 및 남은 검증

- [x] P2 11개 엔터티의 물리 컬럼과 주요 타입을 DAMX 문자열 덤프와 대조
- [x] P2 신규 DDL / 6개 오류번호 구별하는 부정 테스트 작성
- [x] GitHub Actions 49개 테이블 검증 단계 구성
- [ ] Actions의 MySQL DDL / smoke 실제 성공 확인
- [ ] 실제 FTC 공시 데이터 코드북 및 기간·단위 확인
- [ ] DIM/FACT 원천 lineage·SCD 기간 구간 겹침·분류체계 매핑 검증

**주의:** 본 단계의 SQL 실행 가능성, 원본 데이터 적재 가능성 및 공시 지표 의미의 완전한 검증은 서로 다른 성취 조건이다.
