# Franchise Recommendation DB

서울시 상권 데이터와 프랜차이즈 정보를 관계형 데이터베이스로 연결하고, 입력 지역과 유사한 상권을 찾은 뒤 업종 성과와 프랜차이즈 지표를 결합해 후보를 추천하는 데이터 분석 프로젝트입니다.

## 1. 프로젝트 개요

| 항목 | 내용 |
| --- | --- |
| 프로젝트 | Franchise Recommendation DB |
| 기간 | 2023 |
| 형태 | 대학 데이터베이스 팀 프로젝트 |
| 핵심 주제 | 상권 데이터 모델링 및 유사 상권 기반 프랜차이즈 추천 |
| 주요 데이터 | 서울시 상권분석서비스, 공정거래위원회 가맹사업정보 |
| 실행 환경 | Jupyter Notebook / Python / MySQL |

```text
공공·프랜차이즈 데이터 수집
→ 데이터 정제 및 업종 코드 정합화
→ 관계형 데이터베이스 설계·정규화
→ MySQL 테이블 구축 및 SQL 조회
→ 입력 지역 특성 벡터 구성
→ 코사인 유사도로 유사 상권 탐색
→ 업종 매출과 프랜차이즈 지표 결합
→ 추천 점수 계산 및 후보 출력
→ Folium 지도 시각화
```

## 2. 기획 의도

창업 후보지를 판단할 때 상권 특성과 프랜차이즈 정보를 따로 확인하면 지역·업종·브랜드 사이의 관계를 한 번에 비교하기 어렵습니다. 여러 출처의 데이터를 관계형 구조로 통합하고, 특정 지역과 비슷한 상권의 업종 성과를 이용해 프랜차이즈 후보를 좁히는 흐름을 구현했습니다.

- 상권, 점포, 업종, 프랜차이즈 정보를 공통 코드로 연결
- 함수 종속을 검토하고 반복 속성을 분리해 정규화
- SQL JOIN으로 지역·업종·프랜차이즈 데이터를 함께 조회
- 입력 지역과 기존 상권을 동일한 특성 공간에서 비교
- 코사인 유사도로 유사 상권을 탐색
- 매출·수익성·개점·해지·초기비용을 반영한 규칙 기반 점수로 후보 정렬

## 3. 주요 기능

### 데이터베이스 설계
- 상권, 행정동, 자치구, 상권 구분, 서비스 업종, 점포, 프랜차이즈 엔터티 설계
- PK/FK 기반 관계 정의
- 정규화 및 MySQL DDL 작성

### 상권·업종 데이터 조회
- 조건 검색, LIKE, NULL, 정렬, GROUP BY 집계
- 행정동·자치구·상권 간 JOIN
- 상권별 업종 매출 및 점포 수 조회

### 유사 상권 탐색
- 식별자·좌표를 제외한 수치형 특성 사용
- 결측치 보정
- 코사인 유사도 기준 상위 상권 탐색

### 프랜차이즈 추천
- 유사 상권 업종 매출과 프랜차이즈 정보 결합
- 당기순이익, 신규개점, 계약해지, 인테리어비, 교육비, 보증금, 기타비용 반영
- 휴리스틱 추천 점수 기준 정렬

### 지도 시각화
- EPSG:5181 좌표를 WGS84로 변환
- Folium 기반 유사 상권 위치 시각화

## 4. 기술 스택

| 영역 | 기술 |
| --- | --- |
| Language | Python, SQL |
| Database | MySQL |
| Data Analysis | Pandas, NumPy |
| Similarity | scikit-learn cosine_similarity |
| Visualization | Folium, Matplotlib |
| Geospatial | pyproj |
| DB Connection | PyMySQL |
| Notebook | Jupyter Notebook |

## 5. 시스템 아키텍처

```mermaid
flowchart LR
    SEOUL["서울시 상권 데이터"]
    FTC["프랜차이즈 데이터"]
    PREP["전처리 / 업종 코드 정합화"]
    MYSQL[("MySQL")]
    INPUT["입력 지역 데이터"]
    PY["Python / Pandas"]
    SIM["Cosine Similarity"]
    SQL["SQL JOIN / 추천 점수"]
    MAP["Folium 지도"]
    RESULT["추천 후보"]

    SEOUL --> PREP
    FTC --> PREP
    PREP --> MYSQL
    INPUT --> PY
    MYSQL --> PY
    PY --> SIM
    SIM --> SQL
    MYSQL --> SQL
    SIM --> MAP
    SQL --> RESULT
```

## 6. 추천 로직

추천은 **유사 상권 탐색**과 **프랜차이즈 후보 정렬** 두 단계로 구성됩니다.

### 1단계: 유사 상권 탐색
상권 통합 데이터에서 상권 코드·명칭·좌표·행정구역 코드 등 식별 목적 컬럼을 제외한 특성을 사용합니다.

```text
입력 지역 벡터
→ 결측치 보정
→ DB 상권 특성과 코사인 유사도 계산
→ 유사도가 높은 상권 선택
```

현재 구현은 원본 프로젝트 로직을 보존해 별도의 표준화 없이 수치 특성에 코사인 유사도를 적용합니다.

### 2단계: 프랜차이즈 후보 정렬

| 구분 | 반영 지표 |
| --- | --- |
| 긍정 요소 | 유사 상권 업종 매출, 당기순이익, 신규개점 |
| 비용·위험 요소 | 계약해지, 단위면적당 인테리어비, 교육비, 보증금, 기타비용 |

이 점수는 학습 모델의 예측값이 아니라 프로젝트 당시 정의한 규칙 기반 비교 점수입니다.

상세 내용은 [추천 설계](docs/recommendation-design.md)에 정리되어 있습니다.

## 7. 데이터 수집 및 전처리

- 서울 열린데이터광장: 상권, 매출, 점포, 인구, 소득·소비, 집객시설 등
- 공정거래위원회 가맹사업정보제공시스템: 프랜차이즈 재무·가맹·비용 지표
- 입력 지역 사례 데이터: 프로젝트 당시 별도 입력 파일 구성

원천 데이터와 가공 데이터는 재배포 범위를 별도로 확인해야 하므로 저장소에는 포함하지 않습니다.

## 8. 데이터 구조

```mermaid
erDiagram
    COMMERCIAL_AREA_TYPE ||--o{ COMMERCIAL_AREA : classifies
    DISTRICT ||--o{ COMMERCIAL_AREA : contains
    ADMIN_DONG ||--o{ COMMERCIAL_AREA : contains
    COMMERCIAL_AREA ||--o{ STORE : has
    SERVICE_CATEGORY ||--o{ STORE : categorizes
    SERVICE_CATEGORY ||--o{ FRANCHISE : categorizes
```

| 테이블 | 역할 |
| --- | --- |
| 상권_구분 | 상권 분류 코드 |
| 자치구 | 자치구 코드·명 |
| 행정동 | 행정동 코드·명 |
| 상권정보 | 위치와 인구·소득·시설·점포 특성 |
| 서비스_업종 | 업종 코드·명 |
| 점포 | 상권-업종 단위 매출과 점포 수 |
| 프랜차이즈 | 브랜드 재무·가맹·비용 지표 |

전체 스키마는 [sql/schema.sql](sql/schema.sql), 설계 배경은 [데이터 모델](docs/data-model.md)에서 확인할 수 있습니다.

## 9. 프로젝트 구조

```text
Franchise_Recommendation_DB/
├─ notebooks/
│  └─ franchise_recommendation.ipynb
├─ sql/
│  ├─ schema.sql
│  └─ sample_queries.sql
├─ data/
│  └─ README.md
├─ docs/
│  ├─ data-model.md
│  ├─ recommendation-design.md
│  └─ security-review.md
├─ .env.example
├─ .gitignore
├─ requirements.txt
└─ README.md
```

## 10. 실행 방법

### 1. Python 환경
```bash
python -m venv .venv
pip install -r requirements.txt
```

### 2. 환경변수
`.env.example`을 참고해 DB 접속 정보를 로컬 환경변수로 설정합니다.

```text
FRANCHISE_DB_HOST
FRANCHISE_DB_PORT
FRANCHISE_DB_USER
FRANCHISE_DB_PASSWORD
FRANCHISE_DB_NAME
```

### 3. 데이터 준비
기본 입력 예시는 다음 경로를 사용합니다.

```text
data/원천동.xlsx
```

### 4. DB 스키마
```bash
mysql -u <user> -p <database> < sql/schema.sql
```

### 5. Notebook
```bash
jupyter notebook notebooks/franchise_recommendation.ipynb
```

## 11. 검증

- Notebook JSON 구조 및 Python 코드 구문 확인
- DB credential을 환경변수로 분리
- 개인 PC 절대경로 제거
- 출력 셀의 민감정보 제거
- DDL의 FK 생성 순서를 참조 테이블 우선으로 정리
- 유사 상권 탐색 → 지도 → 추천 SQL 순으로 실행 흐름 정리

원천 데이터와 DB 환경이 필요하므로 저장소 자체에는 end-to-end 실행 결과를 포함하지 않습니다.

## 12. 현재 범위와 한계

- 원천·가공 데이터는 저장소에 포함하지 않습니다.
- 유사도 계산 전 특성 표준화를 수행하지 않습니다.
- 결측치를 0으로 처리합니다.
- 추천 가중치는 학습값이 아닌 규칙 기반 값입니다.
- 창업 성공 확률이나 투자수익을 예측하는 모델이 아닙니다.
- 외부 GeoJSON에 의존하는 지도 시각화는 오프라인에서 동작하지 않을 수 있습니다.

## 13. 관련 문서

- [데이터 모델](docs/data-model.md)
- [추천 설계](docs/recommendation-design.md)
- [공개본 보안 검토](docs/security-review.md)
- [입력 데이터 안내](data/README.md)
- [MySQL 스키마](sql/schema.sql)
- [SQL 예제](sql/sample_queries.sql)
