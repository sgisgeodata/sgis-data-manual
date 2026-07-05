
source("./제주시 고령인구 비율 격자별 분석(tmap)_lib.R", encoding="UTF-8")

map_2000 <- jeju_elderly_ratio_map(base_year="2000")
map_2010 <- jeju_elderly_ratio_map(base_year="2010")
map_2024 <- jeju_elderly_ratio_map(base_year="2024")

tmap_arrange(map_2000, map_2010, map_2024, ncol=3)

