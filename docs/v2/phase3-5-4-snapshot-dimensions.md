# Phase 3-5-4 — 원본 스냅샷 기반 차원 모델 구축

## 원칙

기존 49개 `SRC/DIM/FACT`와 `STG_P0_QUALITY`의 품질 판정은 **변경하지 않는다**. 외부 공식 SHP·업종 효력일·관측 기준일이 없어도 *원본 파일 버전*과 *분기 통계 보고코드*를 사용해 분석 준비 단계까지 진행한다.

**주의**: 원본 문서 snapshot은 상권 지형의 SCD2 버전이나 상권코드의 역사가 아니다. `SNAP_AREA`는 해당 ZIP의 영역 목록이며 2022Q1~2023Q2 매 분기에 법적으로 유효한 경계라는 뜻이 아니다.

## 구조

| 테이블 | 그레인 | 소스 | 예정 행수 |
|---|---|---|---:|
| `SNAP_SOURCE_DOCUMENT` | (source_kind,원본문서 해시) | 세 원본 ZIP 내부 CSV | 3 |
| `SNAP_PERIOD` | 보고분기 `YYYYQq` | 매출/점포 20221~20232 | 6 |
| `SNAP_AREA` | (원본 AREA 스냅샷,상권코드) | AREA | 1,650 |
| `SNAP_INDUSTRY` | (미확정 분류 스코프,업종코드) | STORE 100종 | 100 |
| `SNAP_INDUSTRY_SOURCE` | (원본문서,업종코드) | SALES 63 + STORE 100 | 163 |

코드는 항상 VARCHAR 문자열로 저장해 선행 0을 보존하고, AREA 좌표·면적은 원본 숫자를 Decimal으로 정규화한다. `SNAP_PERIOD`의 시작/끝은 **그레고리력 분기 달력 구간**이며, 상권 경계·업종 분류체계의 실제 유효기간이 아니다. 끝일은 exclusive로 저장한다.

## 실행 파일

- `sql/v2/migrations/007_snapshot_dimensions.sql`: 기존 모델을 건드리지 않는 다섯 스냅샷 차원 테이블.
- `src/franchise_dw/snapshot_dimensions.py`: 원본 SHA-256 기반 결정적 snapshot_id, 분기 달력 검증.
- `src/franchise_dw/load_snapshot_dimensions.py`: **MySQL 원본 SRC와 품질 STG 584,385행 일치 여부를 선행 검증**하고 5개 테이블에 차원 데이터를 원자적 트랜잭션으로 넣는다. 동일 스냅샷 재실행은 전수 건수 검증 후 skip, 중간 오류 시 rollback.
- `tests/test_snapshot_dimensions.py`, CI: 단위·DDL 검사.

## 실행 순서 (로컬 또는 Codex MySQL, 여기서는 미실행)

```bash
mysql -h 127.0.0.1 -P 13316 -u <USER> -p < sql/v2/migrations/007_snapshot_dimensions.sql
export PYTHONPATH=src
# FRANCHISE_DW_HOST/PORT/NAME/USER/PASSWORD는 환경변수로 관리
python -m franchise_dw.load_snapshot_dimensions --dry-run
python -m franchise_dw.load_snapshot_dimensions
python -m franchise_dw.load_snapshot_dimensions
```

- `--dry-run`: 삽입 결과를 검증하되 rollback한다.
- 실제 실행 전 테이블 존재 여부를 확인해 007을 두 번 적용하지 않는다.
- 데이터 적재는 원본 문서·배치 해시의 SRC/STG 행 수, 원본 3종 업무 구조/업종 이름 일관성을 먼저 검증한다.
- 예상 성공 결과는 SOURCE 3 / PERIOD 6 / AREA 1,650 / INDUSTRY 100 / INDUSTRY_SOURCE 163.
- 기존 FACT 데이터는 **절대 INSERT하지 않는다**. 새로운 스냅샷 FACT는 Phase 3-5-5에서 별도로 설계·승인한다.
- 실제 로컬 MySQL 584,385행을 이 스크립트로 적재했다는 증거는 아직 없다. CI는 독립 MySQL에서 DDL 생성만 검증한다.

## 안전한 해석

- `SNAP_AREA`의 AREA 코드는 원본 AREA 파일 기준으로만 식별된다. 분기별 상권 경계가 동일했다고 단언하지 않는다.
- `SNAP_INDUSTRY`는 원본에서 확인한 업종 코드/명칭의 **출처 한정 코드목록**이며 공식 분류 버전 발효일을 대체하지 않는다.
- 이 단계에서 만들 수 있는 시각화·집계는 **원본 분기 기준 기술통계**다. 분기 간 지역경계 비교·진정한 시계열 성장률은 별도 제약 고지가 필요하다.
- STORE의 전체/일반/프랜차이즈 점포 수 의미는 별도의 Draft PR #7에서 정의됐고 기존 SRC 컬럼명은 그대로 유지된다. 이 브랜치에서는 FACT 수정 006과 연동하지 않는다.
- 공식 공간·분류·관측기간 근거는 별도 Draft PR #8에서 지속 조사한다.

## 인수조건

- [x] 스냅샷 별도 테이블 5개 DDL 작성
- [x] 원본 해시·행 수·키·분기·코드 기반 검증형 적재 코드 작성
- [x] 안전한 동일 데이터 재실행·롤백 설계
- [ ] CI 단위/DDL 성공
- [ ] **실제 원본 584,385행** MySQL에서 로더 dry-run·적재·재실행 검증
- [ ] Phase 3-5-5 스냅샷 FACT 계약 정의

PR은 Draft, `main` 수정 없음.
