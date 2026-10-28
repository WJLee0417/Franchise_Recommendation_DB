# Phase 3-3: 원본 584,385행 적재 재검증 결과 (2026-10-28)

## 결과의 엄격한 구분

**현재 환경에 MySQL 서버·Docker 엔진이 없고 외부 패키지/네트워크 설치도 실패했으므로 원본 MySQL 적재는 완료하지 못했다.** 실제 원본 ZIP을 로컬 **SQLite 검증 전용 스테이징**에 모두 INSERT해 원본 데이터 저장/재실행/변조 검사를 수행했다. SQLite 검증은 MySQL 검증과 동등하지 않다.

| 대상 | 최초 저장행 | 동일 파일 재실행 신규 저장 | 저장된 원문·한글·금액·비율 검증 |
|---|---:|---:|---|
| SRC_SEOUL_AREA | 1,650 | **0** | 1,650행, 매핑 11필드 전부 일치 |
| SRC_SEOUL_SALES | 125,692 | **0** | 125,692행, 매핑 8필드+상세 원문 JSON 전부 일치 |
| SRC_SEOUL_STORE | 457,043 | **0** | 457,043행, 매핑 14필드 전부 일치 |
| **계** | **584,385** | **0** | **전수 584,385행 검증 완료 (SQLite)** |

- 실제 ZIP의 `/1/` 세 CSV 파일 사용. 중복 증빙 폴더 파일은 제외.
- 원본 레코드를 그대로 JSON에 담아 `raw_record_text`에 보존하고, DB 조회 데이터와 CSV 스트림을 1:1 비교.
- Python 입력 CSV 행 순서 및 `source_record_path`, 해시 기반 `source_document_id`, `collection_batch_id`, 한글 상권명, 상권 코드, 기준분기와 원본 JSON 전체가 **각 행 일치**.
- 전수 SQL 검사로 각 SRC의 모든 매핑 컬럼이 `json_extract(raw_record_text, '$.원본필드')`와 일치하는 것도 추가 검증.
- 점포의 개업률 >100 = 5행, 폐업률 >100 = 124행, 두 지표 중 하나 >100 = 128행을 저장 후 재확인.
- 재실행 2회차는 매 파일 모두 새로 INSERT된 행이 0. **단, SQLite의 `INSERT OR IGNORE`는 MySQL의 `ON DUPLICATE KEY UPDATE`와 구현이 다르다.** 해당 MySQL 기능은 합성 fixture GitHub Actions Run 40676989072에서 이미 검증했다.
- SQLite 스테이징 파일은 개인 데이터가 포함되어 **GitHub에 업로드하지 않음**. 결과 요약본은 사용자에게 별도 전달.

## 원본 데이터의 실제 MySQL 검증에 남은 작업

이번에 추가한 `scripts/verify_original_p0_mysql.py`는 사용자 개인 MySQL 8 DB에서 다음 작업을 **자동 실행하도록 준비한 코드**다. 현재는 스크립트 작성만 완료했으며 이 스크립트의 원본 대상 MySQL 실행 결과는 없다.

1. 원본 3개 CSV의 SHA-256과 예상 행 수 검사
2. SRC 3개 테이블에 원본 전량 INSERT
3. 동일 CSV 재실행: `rows_inserted=0`, 기존 원본 행 전량 중복 처리
4. MySQL의 실제 저장 행을 원본 CSV와 순서대로 스트리밍 전수 대조: raw_record_text, 매핑 필드, 한글명, 원본 금액·비율
5. 100 초과 비율 5/124/128 검사 및 결과 JSON 보존

```bash
export PYTHONPATH=src
# FRANCHISE_DW_HOST, FRANCHISE_DW_PORT, FRANCHISE_DW_NAME,
# FRANCHISE_DW_USER, FRANCHISE_DW_PASSWORD 설정 후
python scripts/verify_original_p0_mysql.py \
  --input data/local/2023_Franchise_Recommendation_DB.zip \
  --report data/local/p0_original_mysql_result.json
```

검증 대상 MySQL은 반드시 **별도 비프로덕션 스키마** `franchise_dw_p0`이 준비되어 있어야 한다. 기존 테이블 재생성은 하지 않는다. GitHub에 원본 ZIP/DB 비밀번호를 업로드하지 않는다.

## 완료 판정

- [x] 원본 ZIP의 실제 584,385행을 SQLite 스테이징에 저장하고 총 건수 일치 검증
- [x] 동일 파일 재실행 신규 저장 0건 검증
- [x] 한글·원문 JSON·매핑 컬럼 전수 일치 확인
- [x] MySQL 8 합성 9행 통합 테스트 기존 성공 기록
- [x] 전량 원본 MySQL 검증 스크립트 준비
- [ ] **원본 ZIP을 실제 MySQL 8에 적재해 동일한 전수 검증 성공**

SQLite 스테이징 성공을 MySQL 원본 적재 성공으로 해석하지 않는다.
