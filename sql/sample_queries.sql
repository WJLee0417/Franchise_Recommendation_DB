-- 기본 조회
SELECT *
FROM 상권정보;

-- 조건 + 산술식
SELECT 상권_코드_명,
       집객시설_수 + 아파트_단지_수 AS 시설_합계
FROM 상권정보
WHERE 자치구_코드 = 11170;

-- LIKE 검색
SELECT 상권_코드_명, 자치구_코드
FROM 상권정보
WHERE 상권_코드_명 LIKE '강%';

-- NULL 검색
SELECT 상권_코드_명
FROM 상권정보
WHERE 행정동_코드 IS NOT NULL;

-- 정렬
SELECT 상권_코드_명, 영역_면적
FROM 상권정보
ORDER BY 영역_면적 DESC;

-- 자치구별 점포 수 집계
SELECT 자치구_코드,
       SUM(점포_수) AS 총_점포_수
FROM 상권정보
GROUP BY 자치구_코드;

-- 자치구와 상권 JOIN
SELECT d.자치구명,
       a.상권_코드_명
FROM 자치구 d
JOIN 상권정보 a
  ON a.자치구_코드 = d.자치구_코드
WHERE d.자치구명 LIKE '_구';

-- 행정동과 상권 JOIN
SELECT dong.행정동명,
       a.상권_코드_명
FROM 행정동 dong
JOIN 상권정보 a
  ON a.행정동_코드 = dong.행정동_코드
WHERE dong.행정동명 LIKE '___동';

-- 특정 프랜차이즈 업종의 상권별 매출 조회
SELECT f.영업명,
       a.상권_코드_명,
       s.매출
FROM 프랜차이즈 f
JOIN 점포 s
  ON f.업종코드 = s.서비스_업종_코드
JOIN 상권정보 a
  ON a.상권_코드 = s.상권_코드
WHERE f.영업명 = '설빙'
ORDER BY s.매출 DESC;

-- 골목상권 조회
SELECT a.상권_코드_명
FROM 상권정보 a
JOIN 상권_구분 t
  ON a.상권_구분_코드 = t.상권_구분_코드
WHERE t.상권_구분명 = '골목상권';
