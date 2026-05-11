
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
prj_dir <- "C:/SGIS/R/강원도 숙박업 변화 격자별 분석"


# 2. 강릉시 경계와 겹치는 격자 경계 만들기

# 2-1. 강릉시 시군구 경계
file_path <- paste(prj_dir, "경계", "bnd_sigungu_32030_2025_2Q.shp", sep="/")
bord_sigungu <- st_read(file_path, options="ENCODING=UTF-8")

# 2-2. 강릉시 행정동 경계
file_path <- paste(prj_dir, "경계", "bnd_dong_32030_2025_2Q.shp", sep="/")
bord_dong <- st_read(file_path, options="ENCODING=UTF-8")

# 2-3. 강릉시를 포함하는 1km 격자 경계(라사, 마사)
file_path <- paste(prj_dir, "경계", "grid_라사_1K.shp", sep="/")
bord_grid_1 <- st_read(file_path)
file_path <- paste(prj_dir, "경계", "grid_마사_1K.shp", sep="/")
bord_grid_2 <- st_read(file_path)

bord_grid <- rbind(bord_grid_1, bord_grid_2)

# 2-4. 강릉시 경계와 겹치는 격자 경계만 저장
bord_intersects <- 
  st_join(bord_grid, bord_sigungu, join=st_intersects, left=FALSE)      

# 강릉시와 겹치는 격자 경계를 지도에서 확인
map_intersects <- ggplot() + 
  geom_sf(data=bord_sigungu, color="black", fill=NA, linewidth=1.0) +
  geom_sf(data=bord_intersects, color="blue", fill=NA, linetype="dotted") + 
  theme_bw() + theme(axis.title = element_blank()) # 축 제목(x, y) 제거

map_intersects # 지도를 'Plots' 탭에서 확인


# 3. 숙박업 사업체 통계 선별하기

# 3-1. 2019년

file_path <- paste(prj_dir, "통계", "2019년_사업체중분류_라사_1K.csv", sep="/")
stat_1 <- read.csv(file=file_path, header=FALSE, fileEncoding="CP949")
file_path <- paste(prj_dir, "통계", "2019년_사업체중분류_마사_1K.csv", sep="/")
stat_2 <- read.csv(file=file_path, header=FALSE, fileEncoding="CP949")

stat <- rbind(stat_1, stat_2)

colnames(stat) <- c("BASE_YEAR", "GRID_CODE", "STAT_CODE", "STAT_VAL")
# 통계파일의 컬럼명 지정

head(stat) # 통계파일의 컬럼명과 데이터 확인

sort(unique(stat[ , "STAT_CODE"]))
# 통계코드 종류 확인

stat_2019 <- stat[stat$STAT_CODE=="cp2_bnu_55", ]
# 숙박업('cp2_bnu_55') 통계를 별도로 저장

# 3-2. 2023년
file_path <- paste(prj_dir, "통계", "2023년_사업체중분류_라사_1K.csv", sep="/")
stat_1 <- read.csv(file=file_path, header=FALSE, fileEncoding="CP949")
file_path <- paste(prj_dir, "통계", "2023년_사업체중분류_마사_1K.csv", sep="/")
stat_2 <- read.csv(file=file_path, header=FALSE, fileEncoding="CP949")

stat <- rbind(stat_1, stat_2)

colnames(stat) <- c("BASE_YEAR", "GRID_CODE", "STAT_CODE", "STAT_VAL")
# 통계파일의 컬럼명 지정

head(stat) # 통계파일의 컬럼명과 데이터 확인

sort(unique(stat[ , "STAT_CODE"]))
# 통계코드 종류 확인

stat_2023 <- stat[stat$STAT_CODE=="cp2_bnu_55", ]
# 숙박업('cp2_bnu_55') 통계를 별도로 저장

# 3.3. 2019년 - 2023년 결합

nrow(stat_2019) #1946
head(stat_2019)

nrow(stat_2023) #2273
head(stat_2023)

stat_comp <- rbind(stat_2019, stat_2023)
nrow(stat_comp)
head(stat_comp)

stat_comp_pv <- dcast(stat_comp, GRID_CODE ~ BASE_YEAR, max, fill=0, value.var="STAT_VAL")
nrow(stat_comp_pv) #2493
str(stat_comp_pv)

# 차이값(DIFF) 컬럼 만들기
stat_comp_pv$DIFF <- stat_comp_pv[, "2023"] - stat_comp_pv[, "2019"]


# 4. 경계와 통계 조인하기

# 4-1. 2019년

# 경계와 통계 데이터셋과 key 컬럼 지정
join_2019 <- merge(x=bord_intersects, y=stat_2019,
              by.x="GRID_CD", by.y="GRID_CODE", all.x=TRUE)
# all.x=TRUE: 통계값(y)이 매칭되지 않아도 경계(x)는 남기기

join_2019 # 조인 결과 확인

# 불필요한 컬럼 정리, 기준연도(BASE_YEAR) NULL값 채우기
join_2019 <- join_2019 %>% select(-BASE_DATE, -SIGUNGU_CD, -SIGUNGU_NM, -STAT_CODE)
join_2019$BASE_YEAR <- "2019"
join_2019[is.na(join_2019$STAT_VAL), "STAT_VAL"] <- 0
str(join_2019)
max(join_2019$STAT_VAL) # 2019년 최대값 116

# 4-2. 2023년

# 경계와 통계 데이터셋과 key 컬럼 지정
join_2023 <- merge(x=bord_intersects, y=stat_2023,
                   by.x="GRID_CD", by.y="GRID_CODE", all.x=TRUE)
# all.x=TRUE: 통계값(y)이 매칭되지 않아도 경계(x)는 남기기

join_2023 # 조인 결과 확인

# 불필요한 컬럼 정리, 기준연도(BASE_YEAR) NULL값 채우기
join_2023 <- join_2023 %>% select(-BASE_DATE, -SIGUNGU_CD, -SIGUNGU_NM, -STAT_CODE)
join_2023$BASE_YEAR <- "2023"
join_2023[is.na(join_2023$STAT_VAL), "STAT_VAL"] <- 0
str(join_2023)
max(join_2023$STAT_VAL) # 2023년 최대값 110

# 4-3. 차이값

# 경계와 통계 데이터셋과 key 컬럼 지정
join_comp <- merge(x=bord_intersects, y=stat_comp_pv,
                   by.x="GRID_CD", by.y="GRID_CODE", all.x=TRUE)
# all.x=TRUE: 통계값(y)이 매칭되지 않아도 경계(x)는 남기기

join_comp # 조인 결과 확인

# 불필요한 컬럼 정리, 기준연도(BASE_YEAR) NULL값 채우기
join_comp <- join_comp %>% select(-BASE_DATE, -SIGUNGU_CD, -SIGUNGU_NM)
join_comp[is.na(join_comp$DIFF), "DIFF"] <- 0
str(join_comp)
max(join_comp$DIFF) # 차이값 최대값 21
min(join_comp$DIFF) # 차이값 최소값 -15


# 5. 강원도 숙박업 사업체 단계구분도

# 5-1. 2019년

# 통계값의 구간 범위 컬럼 만들기
join_2019$BREAKS <- 
  cut(join_2019$STAT_VAL, breaks = c(1, 5, 20, 50, 100, 116),          # 수정
      labels = c("1~5","5~20","20~50","50~100","100~116")) # 수정

map_2019 <- ggplot() +
  # 1. 격자 경계
  geom_sf(data=join_2019, mapping=aes(fill=BREAKS), linetype="dotted") +
  scale_fill_manual(values=c("#FFFFB2","#FECC5C","#FD8D3C","#F03B20","#BD0026"),
                    na.value="white", na.translate=FALSE, name="격자별 숙박업(개)") +
  # 2. 행정동 경계와 이름
  geom_sf(data=bord_dong, color="blue", fill=NA, linewidth=0.1, alpha=0.5) + 
  geom_sf_text(data=bord_dong, mapping=aes(label=ADM_NM), alpha=0.7, size=3) +
  # 3. 시군구 경계와 이름
  geom_sf(data=bord_sigungu, color="black", fill=NA, linewidth=0.2) +
  # 4 제목과 테마 지정
  ggtitle("2019년 강릉시 숙박업") +
  theme_bw() + # 축 제목, 축 텍스트 등 제거
  theme(axis.title=element_blank(), axis.text=element_blank(), axis.ticks=element_blank(), 
        panel.grid=element_blank())

map_2019  # 전체 맵을 'Plots' 탭에서 확인

# 5-2. 2023년

# 통계값의 구간 범위 컬럼 만들기
join_2023$BREAKS <- 
  cut(join_2023$STAT_VAL, breaks = c(1, 5, 20, 50, 100, 116),          # 수정
      labels = c("1~5","5~20","20~50","50~100","100~116")) # 수정

map_2023 <- ggplot() +
  # 1. 격자 경계
  geom_sf(data=join_2023, mapping=aes(fill=BREAKS), linetype = "dotted") +
  scale_fill_manual(values=c("#FFFFB2","#FECC5C","#FD8D3C","#F03B20","#BD0026"),
                    na.value="white", na.translate=FALSE, name="격자별 숙박업(개)") +
  # 2. 행정동 경계와 이름
  geom_sf(data=bord_dong, color="blue", fill=NA, linewidth=0.1, alpha=0.5) + 
  geom_sf_text(data=bord_dong, mapping=aes(label=ADM_NM), alpha=0.7, size=3) +
  # 3. 시군구 경계와 이름
  geom_sf(data=bord_sigungu, color="black", fill=NA, linewidth=0.2) +
  # 4. 제목과 테마 지정
  ggtitle("2023년 강릉시 숙박업") +
  theme_bw() + # 축 제목, 축 텍스트 등 제거
  theme(axis.title=element_blank(), axis.text=element_blank(), axis.ticks=element_blank(), 
        panel.grid=element_blank())

map_2023  # 전체 맵을 'Plots' 탭에서 확인

# 5-3. 2019년~2023년 변화

# 통계값의 구간 범위 컬럼 만들기
join_comp$BREAKS <- 
  cut(join_comp$DIFF, breaks = c(-15, -10, -1, 1, 10, 15, 21),          # 수정
      labels = c("-15~-10", "-10~-1","-1~1","1~10", "10~15","15~21")) # 수정

map_comp <- ggplot() +
  # 1. 격자 경계(전체 순위)
  geom_sf(data=join_comp, mapping=aes(fill=BREAKS), linetype = "dotted") +
  scale_fill_manual(values=c("#6BAED6","#BDD7E7","#FFFFFF","#FECC5C","#FD8D3C","#BD0026"),
                    na.value="white", na.translate=FALSE, name="격자별 숙박업 변화(개)") +
  # 2. 행정동 경계와 이름
  geom_sf(data=bord_dong, color="blue", fill=NA, linewidth=0.1, alpha=0.5) + 
  geom_sf_text(data=bord_dong, mapping=aes(label=ADM_NM), alpha=0.7, size=3) +
  # 3. 시군구 경계와 이름
  geom_sf(data=bord_sigungu, color="black", fill=NA, linewidth=0.2) +
  # 4. 제목과 테마 지정
  ggtitle("2019년~2023년 강릉시 숙박업 변화") +
  theme_bw() + # 축 제목, 축 텍스트 등 제거
  theme(axis.title=element_blank(), axis.text=element_blank(), axis.ticks=element_blank(), 
        panel.grid=element_blank())

map_comp  # 전체 맵을 'Plots' 탭에서 확인


# 6. 지도 그림과 경계파일 저장하기

# 6-1. 지도를 그림파일로 저장
file_path <- paste(prj_dir, "2019년 강릉시 숙박업 격자별 단계구분도.png", sep="/")
ggsave(map_2019, filename=file_path)
# 너비, 높이는 인치 단위로 지정 가능
file_path <- paste(prj_dir, "2023년 강릉시 숙박업 격자별 단계구분도.png", sep="/")
ggsave(map_2023, filename=file_path)
file_path <- paste(prj_dir, "2019년~2023년 강릉시 숙박업 변화 단계구분도.png", sep="/")
ggsave(map_comp, filename=file_path)


# 6.2. 경계를 SHP 파일로 저장
file_path <- paste(prj_dir, "2019년 강릉시 숙박업 격자별 단계구분도.shp", sep="/")
st_write(join_2019, dsn=file_path, append=FALSE, layer_options="ENCODING=UTF-8")
# 한글을 포함한 파일을 저장할 때 적절한 인코딩 지정('UTF-8' 또는 'CP949' 등)
file_path <- paste(prj_dir, "2023년 강릉시 숙박업 격자별 단계구분도.shp", sep="/")
st_write(join_2023, dsn=file_path, append=FALSE, layer_options="ENCODING=UTF-8")
file_path <- paste(prj_dir, "2019년~2023년 강릉시 숙박업 변화 단계구분도.shp", sep="/")
st_write(join_comp, dsn=file_path, append=FALSE, layer_options="ENCODING=UTF-8")

