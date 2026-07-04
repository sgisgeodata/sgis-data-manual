
# 1. 분석 패키지 설치 및 사용준비(ggplot2 버전)

# install.packages("dplyr")   # 한번 설치하고 주석처리(#) 하기
# install.packages("sf")      # 한번 설치하고 주석처리(#) 하기
# install.packages("ggplot2") # 한번 설치하고 주석처리(#) 하기
# install.packages("reshape2") # 한번 설치하고 주석처리(#) 하기

library(dplyr)        # 데이터 처리: mutate() 등
library(sf)           # 공간 데이터 처리: st_read() 등
library(ggplot2)      # ggplot2 시각화: ggplot() 등
library(reshape2)     # 피벗테이블 만들기 # dcast()

# 프로젝트 폴더 지정
prj_dir <- "C:/SGIS/R/Proportion of Elderly Population in Jeju by Grid"


# 2. 제주시 경계와 겹치는 격자 경계 만들기

# 제주시 시도 경계
file_path <- paste(prj_dir, "bnd_sido_39_2025_2Q.shp", sep="/")
bord_sido <- st_read(file_path) # 경계 읽어들이기, geometry 컬럼에 공간정보 포함

# 테스트 시작(제주시 시도 경계)
map <- ggplot() +
  geom_sf(data=bord_sido, color="black", fill=NA, linewidth=1.0) +
  theme_bw() + theme(axis.title = element_blank())

map
# 테스트 끝


# 제주시 시군구 경계
file_path <- paste(prj_dir, "bnd_sigungu_39_2025_2Q.shp", sep="/")
bord_sigungu <- st_read(file_path)

# 테스트 시작(제주시 시군구 경계)
map <- ggplot() +
  geom_sf(data=bord_sigungu, color="black", fill=NA, linewidth=1.0) +
  theme_bw() + theme(axis.title = element_blank())

map
# 테스트 끝


# 제주시 행정동 경계
file_path <- paste(prj_dir, "bnd_dong_39_2025_2Q.shp", sep="/")
bord_dong <- st_read(file_path)

# 테스트 시작(제주시 행정동 경계)
map <- ggplot() +
  geom_sf(data=bord_dong, color="black", fill=NA, linewidth=1.0) +
  theme_bw() + theme(axis.title = element_blank())

map
# 테스트 끝


# 제주시 경계와 겹치는 격자 경계 합치기('Nana', 'Nada', 'Dana', 'Dada')
file_path <- paste(prj_dir, "grid_Nana_1K.shp", sep="/")
bord_grid_nana <- st_read(file_path)
file_path <- paste(prj_dir, "grid_Nada_1K.shp", sep="/")
bord_grid_nada <- st_read(file_path)
file_path <- paste(prj_dir, "grid_Dana_1K.shp", sep="/")
bord_grid_dana <- st_read(file_path)
file_path <- paste(prj_dir, "grid_Dada_1K.shp", sep="/")
bord_grid_dada <- st_read(file_path)

bord_grid_jeju <- rbind(bord_grid_nana, bord_grid_nada, bord_grid_dana, bord_grid_dada)


# 테스트 시작(제주시 시도 경계와 격자 4개)
map <- ggplot() +
  geom_sf(data=bord_grid_jeju, color="black", fill=NA, linewidth=1.0) +
  geom_sf(data=bord_sido, color="red", fill=NA, linewidth=1.0) +
  theme_bw() + theme(axis.title = element_blank())

map
# 테스트 끝


# 제주시 경계와 겹치는 격자 경계만 저장
bord_intersects <- 
  st_join(bord_grid_jeju, bord_sido, join=st_intersects, left=FALSE)


# 테스트 시작(제주시 경계와 겹치는 격자 경계)
map <- ggplot() +
  geom_sf(data=bord_intersects, color="black", fill=NA, linewidth=1.0) +
  geom_sf(data=bord_sido, color="red", fill=NA, linewidth=1.0) +
  theme_bw() + theme(axis.title = element_blank())

map
# 테스트 끝(제주시 경계와 겹치는 격자 경계)


# 3. 고령인구 통계, 비율 계산하기

file_path <- paste(prj_dir, "Population_Nana_1K_2024.csv", sep="/")
stat_nana <- read.csv(file=file_path, header=FALSE, fileEncoding="CP949")

file_path <- paste(prj_dir, "Population_Nada_1K_2024.csv", sep="/")
stat_nada <- read.csv(file=file_path, header=FALSE, fileEncoding="CP949")

file_path <- paste(prj_dir, "Population_Dana_1K_2024.csv", sep="/")
stat_dana <- read.csv(file=file_path, header=FALSE, fileEncoding="CP949")

file_path <- paste(prj_dir, "Population_Dada_1K_2024.csv", sep="/")
stat_dada <- read.csv(file=file_path, header=FALSE, fileEncoding="CP949")
# 한글을 포함한 통계 파일의 인코딩을 'CP949'로 지정

stat <- rbind(stat_nana, stat_nada, stat_dana, stat_dada)

# 통계파일의 컬럼명 지정
colnames(stat) <- c("BASE_YEAR", "GRID_CODE", "STAT_CODE", "STAT_VAL")

head(stat) # 통계파일의 컬럼명과 데이터 확인

# 통계코드 종류 확인(5세연령 인구, 연령그룹 인구, 총인구 등)
sort(unique(stat[ , "STAT_CODE"]))


# 고령인구(in_age_014 ~ in_age_021), 총인구(to_in_001) 통계만 별도로 저장
stat <- stat[stat$STAT_CODE %in% c("in_age_014"     #	65세이상~69세이하
                                 , "in_age_015"     #	70세이상~74세이하
                                 , "in_age_016"     #	75세이상~79세이하
                                 , "in_age_017"     #	80세이상~84세이하
                                 , "in_age_018"     #	85세이상~89세이하
                                 , "in_age_019"     #	90세이상~94세이하
                                 , "in_age_020"     #	95세이상~99세이하
                                 , "in_age_021"     #	100세이상
                                 , "to_in_001"), ]  #	총인구

# 피벗테이블 만들기(통계속성을 옆으로 펼친 형태)
stat_pt <- dcast(stat, BASE_YEAR + GRID_CODE ~ STAT_CODE, max, fill=0, value.var="STAT_VAL")

# 고령인구 변수(in_aging) 만들기
stat_pt$in_aging <- stat_pt$in_age_014 + stat_pt$in_age_015 + stat_pt$in_age_016 + stat_pt$in_age_017
                  + stat_pt$in_age_018 + stat_pt$in_age_019 + stat_pt$in_age_020 + stat_pt$in_age_021

# 고령인구 비율 변수(ratio_65p) 만들기
stat_pt$ratio_65p <- round(stat_pt$in_aging / stat_pt$to_in_001, 2)

head(stat_pt)


# 4. 경계와 통계 조인하기

# 경계와 통계 데이터셋과 key 컬럼 지정
join <- merge(x=bord_intersects, y=stat_pt,
              by.x="GRID_CD", by.y="GRID_CODE", all.x=TRUE)
# all.x=TRUE: 통계값(y)이 매칭되지 않아도 경계(x)는 남기기

join # 조인 결과 확인

# 불필요한 컬럼 정리, 기준연도(BASE_YEAR) NULL값 채우기
join <- join %>% select(-BASE_DATE, -SIDO_CD, -SIDO_NM)
join$BASE_YEAR <- "2024"

# 총인구(to_in_001)이 NA이거나 20 이하이면 고령인구 비율을 0으로 계산
join[is.na(join$to_in_001) | join$to_in_001 <= 20, "ratio_65p"] <- 0


# 5. 고령인구 비율 단계구분도

# 통계값의 구간 범위 컬럼 만들기
# 고령인구 비율 7%~14% 고령화사회, 14%~20% 고령사회, 20% 이상 초고령사회
join$BREAKS <- 
  cut(join$ratio_65p, breaks = c(0.01, 0.07, 0.14, 0.20, 0.91),   # 자료의 최대값(0.91) 확인
      labels = c("0.01~0.07","0.07~0.14","0.14~0.20","0.20~0.91"))

map_all <- ggplot() +
  # 1. 고령인구 비율 단계구분
  geom_sf(data=join, mapping=aes(fill=BREAKS), linetype = "dotted") +
  scale_fill_manual(values=c("#FFFFB2","#FECC5C","#FD8D3C", "#F03820"),
                    na.value="white", na.translate=FALSE, name="Proportion of Elderly Population") +
  # 2. 제주시 시도 경계
  geom_sf(data=bord_sido, color="black", fill=NA, linewidth=0.7) + 
  # 3. 제주시 시군구 경계와 이름
  geom_sf(data=bord_sigungu, color="black", fill=NA, linewidth=0.5) +
  # 4. 제주시 행정동 경계
  geom_sf(data=bord_dong, color="black", fill=NA, linewidth=0.3) +
  geom_sf_text(data=bord_sigungu, mapping=aes(label=SIGUNGU_NM), alpha=0.7, size=5) +
  # 5. 제목과 테마 지정
  ggtitle("2024 Proportion of Elderly Population in Jeju by Grid") +
  theme_bw() + # 축 제목, 축 텍스트 등 제거
  theme(axis.title=element_blank(), axis.text=element_blank(), axis.ticks=element_blank())

map_all  # 전체 맵을 'Plots' 탭에서 확인


# 6. 지도 그림과 경계파일 저장하기

# 지도를 그림파일로 저장
file_path <- paste(prj_dir, "2024 Proportion of Elderly Population in Jeju by Grid.png", sep="/")
ggsave(map_all, filename=file_path)
# 너비, 높이는 인치 단위로 지정 가능

# 경계를 SHP 파일로 저장(전체 격자, 상위순위 격자)
file_path <- paste(prj_dir, "2024 Proportion of Elderly Population in Jeju by Grid.shp", sep="/")
st_write(join, dsn=file_path, append=FALSE, layer_options="ENCODING=UTF-8")
# 한글을 포함한 파일을 저장할 때 적절한 인코딩 지정('UTF-8' 또는 'CP949' 등)

