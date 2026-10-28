# P0/P1 MySQL 실행 검증 기록 (2026-10-28)

## 확인된 GitHub Actions 실행

- Workflow: `.github/workflows/warehouse-ddl.yml`
- 검증 실행 Run ID: **40671737286** (GitHub Actions, 성공)
- 검증 대상 커밋: `fc16add36719b2a440663cd7b3d1cc00f92dbe6e`
- 서버: **MySQL 8.0.46**, `mysql:8.0` 서비스 컨테이너
- P0 DDL: **성공**, P0 smoke: **PASS**
- P1 DDL: **성공**, P1 smoke: **PASS**
- 최종 `information_schema.tables` 집계: **BASE TABLE 38개**, 요구치 38개와 일치

로그의 실제 출력:

```text
PASS: P0 11-table inserts, joins, uniqueness, FK, CHECK and required observation period
PASS P1: FK, UNIQUE, CHECK, finance negatives and SRC lineage
table count: 38
```

이 결과는 **P0/P1 38개 테이블의 새 DB 생성·합성 fixture INSERT/JOIN·제약 위반 테스트**를 실행했다는 증거이지, 실제 공공 데이터 적재나 원본 .damx의 621개 속성 완전 동등성 증거가 아니다.

## 추가 검증 강화

이후 P0/P1 smoke에서 일반적인 `SQLEXCEPTION`을 모두 성공으로 오인할 수 있는 위험을 줄이려고 **MySQL 오류번호를 정확히 검사**하도록 테스트를 변경했다.

| 오류번호 | 예상 사유 |
| --- | --- |
| 1062 | PK/UNIQUE 중복 |
| 1452 | FK 위반 |
| 3819 | CHECK 위반 |
| 1048 | NOT NULL 위반 |

- P0: 부정 테스트 7개를 위 오류번호로 판정.
- P1: 부정 테스트 6개를 위 오류번호로 판정.
- **강화 이후 재실행도 PASS**: GitHub Actions Run ID **40672102788**, 커밋 `6b0326186ccf8b6215c0b3a9c0c4a718de604a7c`; P0/P1 DDL·스모크·38개 테이블 검사가 모두 성공.

## 한계 및 추가 확인 사항

1. 성공한 워크플로는 합성 seed 및 테스트 DB를 사용했으며 현실의 서울시·공정위 통계 레코드나 코드북을 검증하지 않았다.
2. 스모크 테스트는 트랜잭션 내 데이터에 대해 PASS 후 ROLLBACK한다. 모든 테이블의 컬럼 타입·원본 ERD 속성 일대일 동등성까지 확인하지는 않았다.
3. 이력 차원 SCD2 기간 중복, FACT 날짜와 차원 유효기간, 기관 간 분류 매핑, 관측기간 정합성 및 lineage 전 구간 추적은 추가 ETL 검증이 필요하다.
4. 서버 초기화/타임존 경고는 테스트 실패는 아니지만 실제 수집 스케줄/기준시점 구현 전 설정을 확정해야 한다.
5. `main`의 기존 데모는 SQL 파일을 변경하지 않았으나 별도 런타임 회귀 테스트는 수행되지 않았다.

## 작업 완료 판정 기준

- [x] P0 DDL 실행 및 스모크 검사 최초 성공
- [x] P1 DDL 실행 및 스모크 검사 최초 성공
- [x] P0+P1 정확히 38개 테이블 생성 확인
- [x] 더 엄격한 오류번호 검사 작성
- [x] 엄격한 검사로 재실행한 Actions 통과 확인 (Run 40672102788)
- [ ] 데이터 품질/시간 유효구간 검증 (Phase 3~4)
