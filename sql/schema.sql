CREATE TABLE `상권_구분` (
  `상권_구분_코드` char(1) NOT NULL,
  `상권_구분명` varchar(20),
  PRIMARY KEY (`상권_구분_코드`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `자치구` (
  `자치구_코드` int NOT NULL,
  `자치구명` varchar(20),
  PRIMARY KEY (`자치구_코드`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `행정동` (
  `행정동_코드` int NOT NULL,
  `행정동명` varchar(20),
  PRIMARY KEY (`행정동_코드`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `서비스_업종` (
  `서비스_업종_코드` varchar(50) NOT NULL,
  `서비스_업종명` varchar(50),
  PRIMARY KEY (`서비스_업종_코드`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `상권정보` (
  `상권_구분_코드` char(1),
  `상권_코드` int NOT NULL,
  `상권_코드_명` varchar(255),
  `엑스좌표_값` int,
  `와이좌표_값` int,
  `자치구_코드` int,
  `행정동_코드` int,
  `영역_면적` float,
  `집객시설_수` int,
  `아파트_단지_수` int,
  `남성_직장_인구_수` int,
  `여성_직장_인구_수` int,
  `총_상주인구_수` int,
  `남성_유동인구_수` int,
  `여성_유동인구_수` int,
  `월_평균_소득_금액` int,
  `소득_구간_코드` int,
  `지출_총금액` int,
  `점포_수` int,
  PRIMARY KEY (`상권_코드`),
  CONSTRAINT `fk_상권정보_상권구분` FOREIGN KEY (`상권_구분_코드`) REFERENCES `상권_구분` (`상권_구분_코드`),
  CONSTRAINT `fk_상권정보_자치구` FOREIGN KEY (`자치구_코드`) REFERENCES `자치구` (`자치구_코드`),
  CONSTRAINT `fk_상권정보_행정동` FOREIGN KEY (`행정동_코드`) REFERENCES `행정동` (`행정동_코드`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `점포` (
  `서비스_업종_코드` varchar(50) NOT NULL,
  `상권_코드` int NOT NULL,
  `매출` bigint,
  `점포_수` int,
  PRIMARY KEY (`서비스_업종_코드`, `상권_코드`),
  CONSTRAINT `fk_점포_상권정보` FOREIGN KEY (`상권_코드`) REFERENCES `상권정보` (`상권_코드`),
  CONSTRAINT `fk_점포_서비스업종` FOREIGN KEY (`서비스_업종_코드`) REFERENCES `서비스_업종` (`서비스_업종_코드`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `프랜차이즈` (
  `상호명` varchar(100) NOT NULL,
  `등록번호` bigint NOT NULL,
  `자산` bigint,
  `부채` bigint,
  `자본` bigint,
  `매출액` bigint,
  `영업이익` bigint,
  `당기순이익` bigint,
  `가맹점수` int,
  `직영점수` int,
  `신규개점` int,
  `계약종료` int,
  `계약해지` int,
  `평균매출액` bigint,
  `면적당_평균_매출액` bigint,
  `광고비` bigint,
  `판촉비` bigint,
  `가입비` bigint,
  `교육비` bigint,
  `보증금` bigint,
  `기타비용` bigint,
  `단위면적당_인테리어비용` bigint,
  `인테리어_비용` bigint,
  `최초_계약기간` int,
  `연장_계약기간` int,
  `업종코드` varchar(50),
  `영업명` varchar(100),
  PRIMARY KEY (`등록번호`),
  CONSTRAINT `fk_프랜차이즈_서비스업종` FOREIGN KEY (`업종코드`) REFERENCES `서비스_업종` (`서비스_업종_코드`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
