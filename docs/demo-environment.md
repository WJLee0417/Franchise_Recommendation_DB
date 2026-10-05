# Demo 실행 환경

## 목적

원천 데이터와 가공 데이터를 공개 저장소에 포함하지 않으면서도 데이터베이스 생성부터 유사 상권 탐색, 추천 후보 조회까지 실행 흐름을 재현하기 위한 환경입니다.

## 구성

```text
Docker Compose
→ MySQL 8.4
→ sql/schema.sql
→ sql/seed_demo.sql
→ 합성 Demo DB
→ Jupyter Notebook
→ 유사 상권 탐색
→ 프랜차이즈 후보 조회
```

`seed_demo.sql`의 값과 명칭은 모두 실행 재현을 위해 만든 합성 데이터입니다. 실제 상권, 실제 브랜드, 실제 매출·재무 정보를 의미하지 않습니다.

## 실행

```bash
docker compose up -d
docker compose ps
```

MySQL 컨테이너가 healthy 상태가 되면 Python 환경을 준비합니다.

```bash
python -m venv .venv
pip install -r requirements.txt
jupyter notebook notebooks/franchise_recommendation.ipynb
```

Notebook은 기본값으로 Demo DB에 접속하며 `상권_코드=9000`인 합성 Target Area와 나머지 상권을 비교합니다.

## Demo DB 초기화

MySQL 공식 이미지의 `docker-entrypoint-initdb.d` 스크립트는 데이터 볼륨이 처음 생성될 때만 실행됩니다. Seed를 수정한 뒤 처음부터 다시 만들려면 볼륨을 제거합니다.

```bash
docker compose down -v
docker compose up -d
```

## 실제 데이터 모드

기존 프로젝트 데이터로 실행할 때는 환경변수로 모드를 전환합니다.

```text
DATA_MODE=external
FRANCHISE_INPUT_DATA_DIR=<private-data-directory>
FRANCHISE_INPUT_FILE=원천동.xlsx
```

DB 접속 환경변수도 실제 환경에 맞게 재정의합니다. 원천 데이터와 credential은 Git에 커밋하지 않습니다.
