# Phase 3-4-3 — 원본 584,385행 품질 판정 전수 검증 (2026-10-29)

## 결과와 검증 환경

**본 턴에서 원본 ZIP 전체를 실제로 2회 처리하여 판정·원본 해시·변환 결과 해시를 전수 비교했다.** 단, 현재 실행 환경에 MySQL 서버/Docker가 없어 **SQLite 오프라인 검증 저장소**에 적재하여 검증했다. **사용자 로컬 MySQL의 `STG_P0_QUALITY`에 584,385행을 실제 적재했다는 주장은 하지 않는다.**

- 실제 원본: `2023_Franchise_Recommendation_DB(6).zip`의 `/1/` 영역/매출/점포 CSV 3개, CP949. 파일마다 기존 감사 SHA-256 검사 통과.
- 원본의 각 CSV 행을 이전 PR #4에 구현한 `evaluate` 함수의 규칙과 **동일한 분기·정수·Decimal·문자열·원본 JSON 판정 로직**으로 재현했다.
- 저장 검증: 로컬 SQLite에 584,385개 정제 결과를 저장, 원본 2차 스트리밍 재평가에서 **584,385개 행 모두 판정·원본 SHA-256·변환 SHA-256 동일** 확인.
- SQLite 재실행 시 신규 저장 0건. 이는 **오프라인 검증**으로 MySQL의 재실행 테스트를 대신하지 않는다.
- JSON 증거: 채팅 실행 환경 생성 `p0_phase3_4_3_offline_quality_report.json`. **실제 데이터 행·상권명·원본 ZIP·SQLite DB 파일은 GitHub에 업로드하지 않음.**

## 판정 분포 — 원본 전체 행에 대한 실측

| SRC | ACCEPT | WARN | REVIEW | REJECT | 전체 |
|---|---:|---:|---:|---:|---:|
| AREA | 0 | 0 | 1,650 | 0 | 1,650 |
| SALES | 51,974 | 73,714 | 4 | 0 | 125,692 |
| STORE | 383,390 | 49,873 | 23,780 | 0 | 457,043 |
| **합계** | **435,364** | **123,587** | **25,434** | **0** | **584,385** |

**해석 주의:** 이 수치는 **현재 `transform_p0_quality.evaluate` 구현 범위의 판정**이다. `config/p0_quality_rules.v1.json`의 모든 규칙을 구현했다고 단정할 수 없다. 특히 업종/지역 키의 소스 간 검증, 업무키 중복 방지 및 점포↔매출 미연계 확인은 별도 교차 분석 결과만 존재하며 현재 행 단위 판정에 포함되지 않았다. 향후 규칙을 추가하면 판정 분포가 달라진다.

## 경고 및 검토 이슈 (중복 집계: 동일 행에 여러 코드 가능)

| 소스 | 이슈 코드 | 탐지 행 |
|---|---|---:|
| AREA | P0-DQ-009_AREA_VALID_TIME_MISSING | 1,650 |
| SALES | P0-DQ-007_SEX_DIFF | 73,536 |
| SALES | P0-DQ-007_AGE_DIFF | 73,650 |
| SALES | P0-DQ-008_TIME_NEGATIVE | 2 |
| SALES | P0-DQ-008_TIME_MISMATCH | 4 |
| STORE | P0-DQ-004_SIMILAR_GT_STORE | 70,337 |
| STORE | P0-DQ-005_FRANCHISE_GT_STORE | 20,323 |
| STORE | P0-DQ-006_OPEN_ZERO_WITH_EVENTS | 193 |
| STORE | P0-DQ-006_CLOSE_ZERO_WITH_EVENTS | 3,140 |
| STORE | P0-DQ-006_ZERO_STORES_WITH_EVENTS | 4,597 |
| STORE | P0-DQ-006_EVENTS_GT_STORE | 4,892 |
| STORE | P0-DQ-003_CLOSE_GT_100 | 124 |
| STORE | P0-DQ-003_OPEN_GT_100 | 5 |

- AREA 1,650행은 유효기간 근거가 없으므로 모두 REVIEW. 이것이 데이터 형식 오류나 소스 수집 실패를 의미하지는 않는다.
- SALES 4행은 **세부 시간대 매출 건수** REVIEW이며 총매출을 REJECT하지 않는다. 성별·연령별 합계 불일치는 WARN으로 보존.
- STORE 100 초과 비율은 원본 값을 유지. `similar_count_gt_store`는 WARN, `franchise_count_gt_store` 등은 REVIEW. 이슈 건수 합은 행 수와 다르다.
- 원본 소스 자체에 결측 필드·잘못된 분기·형변환 실패가 없어 **REJECT 0건**.

## MySQL 원본 전체 실행을 위한 재현 스크립트

`scripts/verify_p0_quality_mysql.py` 신규 추가:

1. 원본 3개 `collection_batch_id` 및 `source_document_id=sha256:...`의 SRC 원본 행 수/레코드 경로 유일성 확인.
2. 기존 PR #4의 `run()`으로 각 배치 전체 SRC → STG 변환.
3. 실제 MySQL SRC의 모든 행에서 `evaluate()`를 다시 호출하여 STG에 기록된 **판정·이슈 목록·정규화 기간·코드·정규화된 숫자·원본/결과 해시** 전수 비교.
4. `STG_P0_QUALITY` 재실행 후 **변환 결과 해시 + `written_at` 포함 fingerprint 동일** 확인.
5. 사전·사후 28개 DIM/FACT 행 수 비교 (원본 모델 미변경).
6. 위 행별 판정 수치와 총 584,385행 정확히 일치하는 경우에만 `all_checks_pass=true` 기록.

**MySQL 실행 환경에 `005_p0_quality_staging.sql`이 이미 적용되어 있어야 한다.** 비밀정보/개인 ZIP은 로컬에 유지한다.

```bash
export PYTHONPATH=src
# FRANCHISE_DW_HOST, FRANCHISE_DW_PORT, FRANCHISE_DW_NAME,
# FRANCHISE_DW_USER, FRANCHISE_DW_PASSWORD 는 로컬 환경변수로 설정
python scripts/verify_p0_quality_mysql.py --report data/local/p0_quality_mysql_full.json
```

코드 작성과 오프라인 원본 검증은 수행했으나 **실제 원본 데이터에 대한 MySQL STG 실행 결과는 아직 확인되지 않았다**. GitHub Actions 합성 SRC→STG 통합 검증은 PR #4의 별도 CI 통과 기록 참조.

## 완료 판정

- [x] 원본 파일 해시 검증 및 584,385행 오프라인 변환
- [x] ACCEPT/WARN/REVIEW/REJECT 판정 분포 전수 집계
- [x] 오류 코드별 중복 포함 건수 검증
- [x] 2차 전체 스트리밍을 통한 행별 판정·해시 비교
- [x] SQLite 동일 결과 저장/재실행 신규 INSERT 0건
- [x] 전체 MySQL STG 실행 및 재실행/전수 비교 자동화 스크립트 작성
- [ ] **실제 MySQL 서버에 원본 SRC 584,385행 → STG 584,385행 변환 실행·전수 재검증**
- [ ] 모든 `p0_quality_rules.v1.json` 규칙을 교차 소스까지 구현해 판정 일관성 최종 승인

**현재 판단: Phase 3-4-3 오프라인 품질 판정 검증 완료, 실제 MySQL 정제 실행은 미완료.**
