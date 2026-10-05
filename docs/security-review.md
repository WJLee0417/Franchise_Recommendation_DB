# 공개 저장소 보안 검토

## 검토 범위

원본 Notebook을 공개용으로 재구성하면서 코드 셀, 출력 셀, 로컬 경로와 DB 연결 설정을 확인했습니다.

## 공개본 조치

- DB host, user, password, database name을 환경변수로 분리
- 개인 PC 절대경로를 저장소 상대경로로 변경
- 기존 실행 출력 제거
- 원천·가공 데이터 및 DB dump 제외
- .env, credential, key 파일을 .gitignore에 추가
- .env.example에는 변수명과 placeholder만 유지

## 주의사항

원본 프로젝트에서 사용했던 DB credential이 현재도 유효하다면 공개본의 문자열 제거와 별개로 실제 계정 credential을 교체해야 합니다.

공개 저장소에는 실제 credential 값과 개인 식별 정보를 포함하지 않습니다.
