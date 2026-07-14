library(dplyr)
library(readr)

folder_path <- "C:/Users/user/Desktop/네트워크_ORS/창원시 도서관 입지분석"

file_names <- c(
  "2024년_주택_라라_1K.csv",
  "2024년_주택_라마_1K.csv",
  "2024년_주택_마라_1K.csv",
  "2024년_주택_마마_1K.csv"
)

old_house_codes <- c(
  "ho_yr_001", "ho_yr_002", "ho_yr_003"
)

old_house_data <- lapply(file_names, function(file) {
  
  file_path <- file.path(folder_path, file)
  
  # 헤더 없는 CSV 읽기
  df <- read_csv(
    file_path,
    col_names = FALSE,
    locale = locale(encoding = "CP949"),
    show_col_types = FALSE
  )
  
  # 3번째 열(X3) 기준 필터링
  df_filtered <- df %>%
    filter(X3 %in% old_house_codes) %>%
    mutate(source_file = file)
  
  return(df_filtered)
  
}) %>%
  bind_rows()

# 결과 확인
head(old_house_data)

# 저장
write_excel_csv(
  old_house_data,
  file.path(folder_path, "2024년_노후주택_2000년이전_1K_.csv")
)