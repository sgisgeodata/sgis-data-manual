
# 강원도 숙박업 변화 격자별 분석용 라이브러리(항수 모음)

library(dplyr)        # 데이터 처리: mutate() 등
library(sf)           # 공간 데이터 처리: st_read() 등
library(ggplot2)      # ggplot2 시각화: ggplot() 등
library(reshape2)     # 피벗테이블 만들기 # dcast()


# 시군구 경계
get_bord_sigungu <- function(prj_dir, sigungu_code) {
  l_file_path <- paste0(prj_dir, "/", "경계", "/", "bnd_sigungu_", sigungu_code, "_2025_2Q.shp")
  l_bord_sigungu <- st_read(l_file_path, options="ENCODING=UTF-8")
  return(l_bord_sigungu)
} # end of get_bord_sigungu()

# 행정동 경계
get_bord_dong <- function(prj_dir, sigungu_code) {
  l_file_path <- paste0(prj_dir, "/", "경계", "/", "bnd_dong_", sigungu_code, "_2025_2Q.shp")
  l_bord_dong <- st_read(l_file_path, options="ENCODING=UTF-8")
  return(l_bord_dong)
} # end of get_bord_dong()

# 시군구를 포함하는 1km 격자 경계
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

# 시군구 경계와 겹치는 격자 경계만 저장
get_map_intersects <- function(bord_sigungu, bord_grid_intersects) {
  l_map_intersects <- ggplot() + 
    geom_sf(data=bord_sigungu, color="black", fill=NA, linewidth=1.0) +
    geom_sf(data=bord_grid_intersects, color="blue", fill=NA, linetype="dotted") + 
    theme_bw() + theme(axis.title = element_blank()) # 축 제목(x, y) 제거
  return(l_map_intersects)
} # end of get_map_intersects()

# 숙박업 사업체 통계 선별하기
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


# 단계구분도
get_thematic_map <- function(join_data, breaks, labels, colors, legend_name, map_title, 
                             bord_detail=bord_dong, bord_total=bord_sigungu) {
  l_join_data <- join_data
  l_join_data$BREAKS <- cut(l_join_data$STAT_VAL, breaks = breaks, labels = labels)
  
  l_thematic_map <- ggplot() +
    # 1. 격자 경계
    geom_sf(data=l_join_data, mapping=aes(fill=BREAKS), linetype="dotted", show.legend=TRUE) + # 전체 범례 색상 표시
    scale_fill_manual(values=colors, drop=FALSE, # 데이터가 없는 계급도 범례에 표시
                      na.value="white", na.translate=FALSE, name=legend_name) +
    # 2. 행정동 경계와 이름
    geom_sf(data=bord_detail, color="blue", fill=NA, linewidth=0.1, alpha=0.5) + 
    geom_sf_text(data=bord_detail, mapping=aes(label=ADM_NM), alpha=0.7, size=3) +
    # 3. 시군구 경계와 이름
    geom_sf(data=bord_total, color="black", fill=NA, linewidth=0.2) +
    # 4 제목과 테마 지정
    ggtitle(map_title) +
    theme_bw() + # 축 제목, 축 텍스트 등 제거
    theme(axis.title=element_blank(), axis.text=element_blank(), axis.ticks=element_blank(), panel.grid=element_blank())
  
  return(l_thematic_map)
} # end of get_thematic_map()

