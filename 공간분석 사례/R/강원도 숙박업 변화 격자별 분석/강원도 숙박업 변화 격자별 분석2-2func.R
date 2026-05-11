
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

sigungu_code <- "32030"
sigungu_name <- "강릉시"
grid_codes <- c("라사", "마사")
base_years <- c("2019", "2023")
stat_cd <- "cp2_bnu_55"
col_names <- c("BASE_YEAR", "GRID_CODE", "STAT_CODE", "STAT_VAL")

breaks <- c() # 단계구분도 범위
labels <- c() # 단계구분도 라벨
colors <- c() # 단계구분도 색상

# 2. 시군구 경계와 겹치는 격자 경계 만들기

# 2-1. 시군구 경계
get_bord_sigungu <- function(prj_dir, sigungu_code) {
  l_file_path <- paste0(prj_dir, "/", "경계", "/", "bnd_sigungu_", sigungu_code, "_2025_2Q.shp")
  l_bord_sigungu <- st_read(l_file_path, options="ENCODING=UTF-8")
  return(l_bord_sigungu)
} # end of get_bord_sigungu()

bord_sigungu <- get_bord_sigungu(prj_dir, sigungu_code)

# 2-2. 행정동 경계
get_bord_dong <- function(prj_dir, sigungu_code) {
  l_file_path <- paste0(prj_dir, "/", "경계", "/", "bnd_dong_", sigungu_code, "_2025_2Q.shp")
  l_bord_dong <- st_read(l_file_path, options="ENCODING=UTF-8")
  return(l_bord_dong)
} # end of get_bord_dong()

bord_dong <- get_bord_dong(prj_dir, sigungu_code)

# 2-3. 시군구를 포함하는 1km 격자 경계
get_bord_grid <- function(prj_dir, grid_codes) {
  l_bord_grid <- NULL  # grid 하나 불러오기
  l_bord_grids <- NULL # grid 병합 결과 저장용
  l_file_path <- NULL
  for (grid_code in grid_codes) { # 격자코드
    l_file_path <- paste0(prj_dir, "/", "경계", "/", "grid_", grid_code, "_1K.shp")
    l_bord_grid <- st_read(l_file_path)
    l_bord_grids <- rbind(l_bord_grids, l_bord_grid)
  }
  return(l_bord_grids)
} # end of get_bord_grid()

bord_grid <- get_bord_grid(prj_dir, grid_codes)

# 2-4. 시군구 경계와 겹치는 격자 경계만 저장
bord_intersects <- 
  st_join(bord_grid, bord_sigungu, join=st_intersects, left=FALSE)      

get_map_intersects <- function(bord_sigungu, bord_grid_intersects) {
  l_map_intersects <- ggplot() + 
    geom_sf(data=bord_sigungu, color="black", fill=NA, linewidth=1.0) +
    geom_sf(data=bord_grid_intersects, color="blue", fill=NA, linetype="dotted") + 
    theme_bw() + theme(axis.title = element_blank()) # 축 제목(x, y) 제거
  return(l_map_intersects)
} # end of get_map_intersects()

map_intersects <- get_map_intersects(bord_sigungu, bord_intersects)

map_intersects # 지도를 'Plots' 탭에서 확인


# 3. 숙박업 사업체 통계 선별하기

get_stat_midestablish <- function(prj_dir, base_year, grid_codes, stat_code=stat_cd, column_names=col_names) {
  l_stat_grid <- NULL  # grid 하나 불러오기
  l_stat_grids <- NULL # grid 병합 결과 저장용
  l_file_path <- NULL
  for (grid_code in grid_codes) { # 격자코드
    l_file_path <- paste0(prj_dir, "/", "통계", "/", base_year, "년_사업체중분류_", grid_code, "_1K.csv")
    l_stat_grid <- read.csv(l_file_path, header=FALSE, fileEncoding="CP949")
    l_stat_grids <- rbind(l_stat_grids, l_stat_grid)
  }
  colnames(l_stat_grids) <- column_names
  # 통계파일의 컬럼명 지정
  l_stat_grids <- l_stat_grids[l_stat_grids$STAT_CODE==stat_cd, ]

  return(l_stat_grids)
} # end of get_stat_midestablish()

# 3-1. 2019년

stat_2019 <- get_stat_midestablish(prj_dir, base_years[1], grid_codes)

# 3-2. 2023년

stat_2023 <- get_stat_midestablish(prj_dir, base_years[2], grid_codes)

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

# 차이값 컬럼 만들기(함수 활용을 위해 'STAT_vAL' 항목으로 계산)
stat_comp_pv$STAT_VAL <- stat_comp_pv[, base_years[2]] - stat_comp_pv[, base_years[1]]


# 4. 경계와 통계 조인하기

# 4-1. 2019년

# 경계와 통계 데이터셋과 key 컬럼 지정
join_2019 <- merge(x=bord_intersects, y=stat_2019,
              by.x="GRID_CD", by.y="GRID_CODE", all.x=TRUE)
# all.x=TRUE: 통계값(y)이 매칭되지 않아도 경계(x)는 남기기

join_2019 # 조인 결과 확인

# 불필요한 컬럼 정리, 기준연도(BASE_YEAR) NULL값 채우기
join_2019 <- join_2019 %>% select(-BASE_DATE, -SIGUNGU_CD, -SIGUNGU_NM, -STAT_CODE)
join_2019$BASE_YEAR <- base_years[1]
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
join_2023$BASE_YEAR <- base_years[2]
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
join_comp[is.na(join_comp$STAT_VAL), "STAT_VAL"] <- 0
str(join_comp)
max(join_comp$STAT_VAL) # 차이값 최대값 21
min(join_comp$STAT_VAL) # 차이값 최소값 -15


# 5. 강원도 숙박업 사업체 단계구분도

# 5-1. 2019년

# 통계값의 구간 범위 컬럼 만들기
breaks <- c(1, 5, 20, 50, 100, 116)
labels <- c("1~5","5~20","20~50","50~100","100~116")
colors <- c("#FFFFB2","#FECC5C","#FD8D3C","#F03B20","#BD0026")

legend_name <- "격자별 숙박업(개)"
map_title <- paste0(base_years[1], "년 ", sigungu_name, " 숙박업")

get_thematic_map <- function(join_data, breaks, labels, colors, legend_name, map_title, 
                             bord_detail=bord_dong, bord_total=bord_sigungu) {
  l_join_data <- join_data
  l_join_data$BREAKS <- cut(l_join_data$STAT_VAL, breaks = breaks, labels = labels)
  
  l_thematic_map <- ggplot() +
    # 1. 격자 경계
    geom_sf(data=l_join_data, mapping=aes(fill=BREAKS), linetype="dotted") +
    scale_fill_manual(values=colors,
                      na.value="white", na.translate=FALSE, name=legend_name) +
    # 2. 행정동 경계와 이름
    geom_sf(data=bord_detail, color="blue", fill=NA, linewidth=0.1, alpha=0.5) + 
    geom_sf_text(data=bord_detail, mapping=aes(label=ADM_NM), alpha=0.7, size=3) +
    # 3. 시군구 경계와 이름
    geom_sf(data=bord_total, color="black", fill=NA, linewidth=0.2) +
    # 4 제목과 테마 지정
    ggtitle(map_title) +
    theme_bw() + # 축 제목, 축 텍스트 등 제거
    theme(axis.title=element_blank(), axis.text=element_blank(), axis.ticks=element_blank(), 
          panel.grid=element_blank())
  
  return(l_thematic_map)
} # end of get_thematic_map()

map_2019 <- get_thematic_map(join_2019, breaks, labels, colors, legend_name, map_title)

  
# 5-2. 2023년

# 공통 인수는 재사용(breaks, labels, colors, legend_nam)
map_title <- paste0(base_years[2], "년 ", sigungu_name, " 숙박업")

map_2023 <- get_thematic_map(join_2023, breaks, labels, colors, legend_name, map_title)

# 5-3. 2019년~2023년 변화

# 통계값의 구간 범위 컬럼 만들기
breaks <- c(-15, -10, -1, 1, 10, 15, 21)
labels <- c("-15~-10", "-10~-1","-1~1","1~10", "10~15","15~21")
colors <- c("#6BAED6","#BDD7E7","#FFFFFF","#FECC5C","#FD8D3C","#BD0026")

legend_name <- "격자별 숙박업 변화(개)"
map_title <- paste0(base_years[1], "년~", base_years[2], "년 ", sigungu_name, " 숙박업 변화")

map_comp <- get_thematic_map(join_comp, breaks, labels, colors, legend_name, map_title)


# 6. 지도 그림과 경계파일 저장하기

# 6-1. 지도를 그림파일로 저장
file_path <- paste0(prj_dir, "/", base_years[1], "년 ", sigungu_name, " 숙박업 격자별 단계구분도.png")
ggsave(map_2019, filename=file_path)
# 너비, 높이는 인치 단위로 지정 가능
file_path <- paste0(prj_dir, "/", base_years[2], "년 ", sigungu_name, " 숙박업 격자별 단계구분도.png")
ggsave(map_2023, filename=file_path)
file_path <- paste0(prj_dir, "/", base_years[1], "년~", base_years[2], "년 ", sigungu_name, " 숙박업 변화 단계구분도.png")
ggsave(map_comp, filename=file_path)


# 6.2. 경계를 SHP 파일로 저장
file_path <- paste0(prj_dir, "/", base_years[1], "년 ", sigungu_name, " 숙박업 격자별 단계구분도.shp")
st_write(join_2019, dsn=file_path, append=FALSE, layer_options="ENCODING=UTF-8")
# 한글을 포함한 파일을 저장할 때 적절한 인코딩 지정('UTF-8' 또는 'CP949' 등)
file_path <- paste0(prj_dir, "/", base_years[2], "년 ", sigungu_name, " 숙박업 격자별 단계구분도.shp")
st_write(join_2023, dsn=file_path, append=FALSE, layer_options="ENCODING=UTF-8")
file_path <- paste0(prj_dir, "/", base_years[1], "년~", base_years[2], "년 ", sigungu_name, " 숙박업 변화 단계구분도.shp")
st_write(join_comp, dsn=file_path, append=FALSE, layer_options="ENCODING=UTF-8")

