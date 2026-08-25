source("./제주시 고령인구 비율 격자별 분석(ggplot2)_lib.R", encoding="UTF-8")

# install.packages("gridExtra")

library(gridExtra)        # 데이터 처리: mutate() 등

# 프로젝트 폴더 지정
prj_dir <- "C:/SGIS/R/제주시 고령인구 비율 격자별 분석"

map_2000 <- jeju_elderly_ratio_map(base_year="2000")
map_2010 <- jeju_elderly_ratio_map(base_year="2010")
map_2024 <- jeju_elderly_ratio_map(base_year="2024")

map_grid <- grid.arrange(map_2000, map_2010, map_2024, ncol=3)

# 지도를 그림파일로 저장
file_path <- paste(prj_dir, "제주도 고령인구 비율 격자별 분석_GRID.png", sep="/")
ggsave(map_grid, filename=file_path)
# 너비, 높이는 인치 단위로 지정 가능

