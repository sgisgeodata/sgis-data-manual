
# 라이브러리(함수 모음) 활용 버전

source("강원도 숙박업 변화 격자별 분석_lib.R", encoding="UTF-8")

# 프로젝트 폴더 지정
prj_dir <- "C:/SGIS/R/강원도 숙박업 변화 격자별 분석"

sigungu_code <- "32610" # 양양군
sigungu_name <- "양양군"
grid_codes <- c("라사", "라아", "마사", "마아")
# 강릉시: "라사", "마사"
# 양양군: "라사", "라아", "마사", "마아"
# 속초시: "라아"

base_years <- c("2019", "2023")
stat_cd <- "cp2_bnu_55"
col_names <- c("BASE_YEAR", "GRID_CODE", "STAT_CODE", "STAT_VAL")

breaks <- c() # 단계구분도 범위
labels <- c() # 단계구분도 라벨
colors <- c() # 단계구분도 색상


# 2. 시군구 경계와 겹치는 격자 경계 만들기

bord_sigungu <- get_bord_sigungu(prj_dir, sigungu_code)

# 2-2. 행정동 경계
bord_dong <- get_bord_dong(prj_dir, sigungu_code)

# 2-3. 시군구를 포함하는 1km 격자 경계
bord_grid <- get_bord_grid(prj_dir, grid_codes)

# 2-4. 시군구 경계와 겹치는 격자 경계만 저장
bord_intersects <- 
  st_join(bord_grid, bord_sigungu, join=st_intersects, left=FALSE)      

map_intersects <- get_map_intersects(bord_sigungu, bord_intersects)

map_intersects # 지도를 'Plots' 탭에서 확인


# 3. 숙박업 사업체 통계 선별하기

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


# 5. 시군구 숙박업 사업체 단계구분도

# 5-1. 2019년

# 통계값의 구간 범위 컬럼 만들기
breaks <- c(1, 5, 20, 50, 100, 116)
labels <- c("1~5","5~20","20~50","50~100","100~116")
colors <- c("#FFFFB2","#FECC5C","#FD8D3C","#F03B20","#BD0026")

legend_name <- "격자별 숙박업(개)"
map_title <- paste0(base_years[1], "년 ", sigungu_name, " 숙박업")

map_2019 <- get_thematic_map(join_2019, breaks, labels, colors, legend_name, map_title)

# 5-2. 2023년

# 공통 인수는 재사용(breaks, labels, colors, legend_nam)
map_title <- paste0(base_years[2], "년 ", sigungu_name, " 숙박업")

map_2023 <- get_thematic_map(join_2023, breaks, labels, colors, legend_name, map_title)

# 5-3. 2019년~2023년 변화

# 통계값의 구간 범위 컬럼 만들기
breaks <- c(-24, -15, -10, -1, 1, 10)
labels <- c("-24~-15", "-15~-10", "-10~-1","-1~1","1~10")
colors <- c("#08519C","#6BAED6","#BDD7E7","#FFFFFF","#FECC5C")

legend_name <- "격자별 숙박업 변화(개)"
map_title <- paste0(base_years[1], "년~", base_years[2], "년 ", sigungu_name, " 숙박업 변화")

(map_comp <- get_thematic_map(join_comp, breaks, labels, colors, legend_name, map_title))


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

