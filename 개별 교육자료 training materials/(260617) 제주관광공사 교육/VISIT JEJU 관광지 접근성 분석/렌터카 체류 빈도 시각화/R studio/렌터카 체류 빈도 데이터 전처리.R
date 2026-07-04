# =========================================================
# 체류빈도_2021_01.csv ~ 체류빈도_2021_12.csv 합산
# =========================================================
library(dplyr)
library(readr)
library(purrr)

# 경로
path <- "C:/Users/user/Desktop/제주"

# 01~12 파일명 만들기
files <- file.path(
  path,
  paste0("체류빈도_2021_", sprintf("%02d", 1:12), ".csv")
)

# 파일 확인
if (!all(file.exists(files))) {
  print(files[!file.exists(files)])
  stop("위 파일이 없습니다.")
}

# 12개월 합치기
data_all <- map_dfr(files, read_csv, show_col_types = FALSE)

# 격자별 2021년 체류빈도 합산
result_2021 <- data_all %>%
  group_by(j_50_cd) %>%
  summarise(
    left = first(left),
    top = first(top),
    right = first(right),
    bottom = first(bottom),
    xcoord = first(xcoord),
    ycoord = first(ycoord),
    체류빈도_2021 = sum(oid_count, na.rm = TRUE),
    .groups = "drop"
  )

# 저장
write_csv(
  result_2021,
  file.path(path, "체류빈도_2021_합산.csv")
)

# 확인
print(result_2021)
