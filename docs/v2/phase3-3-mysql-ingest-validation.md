# Phase 3-3 — 원본 P0 데이터 MySQL 적재 통합 검증

## 검증 범위와 주의사항

- 사용자 업로드 ZIP 세 CSV의 전체 584,385행에 대해 실제 Python parser dry-run 완료. **MySQL 적재는 미실시**.
- 현재 로컬 환경에 MySQL 서버·Docker 엔진이 없으며 공개 네트워크 접속도 제한되어 원본 ZIP을 실제 MySQL로 적재할 수 없었다.
- GitHub Actions의 MySQL 8 통합 검증은 공개 가능한 **합성 데이터 9행**을 대상으로 수행하도록 구성했다. 원본 ZIP은 GitHub에 업로드하지 않았다.

## 실제 업로드 ZIP dry-run 증거

| 소스 | 원본 바이트 | SHA-256 | 처리행 | 실제 DB 적재 |
| --- | ---: | --- | ---: | --- |
| area | 175,854 | b6281497b242d25569dcf61cc8bd05e80d300101eea5079577e42d0d280bf137 | 1,650 | 미실시 |
| sales | 58,284,507 | ac2ba3a8f74ec3ccbcb0ca87ba0a9cdb7b1c4cbe21d1f17331d12fa644db786d | 125,692 | 미실시 |
| store | 46,086,868 | 8f6932112d355554a290b01ca67cd697474107fc6ad478a23b499a742cc98561 | 457,043 | 미실시 |
| **합계** | | | **584,385** | **미실시** |

동일 보관본의 ZIP 내부 기본데이터 중복 사본은 이중 수집하지 않는다.

## 실제 MySQL 통합 테스트

- `tests/integration_p0_csv_mysql.py`: synthetic CSV 각 소스 3행 생성. P0 SRC에 2행 INSERT → 다시 3행 입력 시 1행만 추가 → 3행 전체 재실행 시 0행 INSERT 및 3행 중복 건너뛰기.
- 원본 한글 상권명, 추정매출 문자열, 개업률 200/폐업률 4800, 원본 JSON 보존을 조회하여 확인.
- `DIM_AREA`, `DIM_INDUSTRY`, `FACT_AREA_SALES`, `FACT_AREA_STORE`는 수집기가 수정하지 않음을 별도 검사.
- CI: `.github/workflows/p0-csv-mysql-integration.yml` (MySQL 8.0 서비스, P0→rate migration→P1→P2 후 검사).

## 원본 데이터 실적재 검증 절차 (추후)

환경변수 `FRANCHISE_DW_HOST`, `FRANCHISE_DW_PORT`, `FRANCHISE_DW_NAME`, `FRANCHISE_DW_USER`, `FRANCHISE_DW_PASSWORD`를 설정하고, 원본 ZIP을 `data/local/`에 보관한다. API 키/DB 비밀번호를 Git에 올리지 않는다.

```bash
export PYTHONPATH=src
python -m franchise_dw.ingest_p0_csv --input data/local/archive.zip --list-zip-members
python -m franchise_dw.ingest_p0_csv --input data/local/archive.zip --source area --zip-member '실제 ZIP 내부 영역 CSV 경로'
python -m franchise_dw.ingest_p0_csv --input data/local/archive.zip --source sales --zip-member '실제 ZIP 내부 매출 CSV 경로'
python -m franchise_dw.ingest_p0_csv --input data/local/archive.zip --source store --zip-member '실제 ZIP 내부 점포 CSV 경로'
```

신규 비어있는 스키마에서 기대 적재 건수는 area=1,650 / sales=125,692 / store=457,043. 전체 입력을 다시 실행해 rows_inserted=0, rows_already_present가 원본 행 수와 일치하는지 확인할 것. 기존 데이터가 있다면 collection_batch_id로 필터해서 비교해야 한다.

## 완료 조건

- [x] 실제 보관본 전체 CSV 스트리밍/매핑 dry-run.
- [x] MySQL 8 합성 데이터 통합 테스트·재실행 검증 스크립트 작성.
- [ ] GitHub Actions 통합 테스트 성공 결과 확인.
- [ ] **실제 원본 ZIP 584,385행의 MySQL 저장 및 중복 재실행·집계 비교**.

원본의 모든 행이 실제 MySQL에 저장되기 전에는 Phase 3-3 실적재 완료라고 주장하지 않는다.
