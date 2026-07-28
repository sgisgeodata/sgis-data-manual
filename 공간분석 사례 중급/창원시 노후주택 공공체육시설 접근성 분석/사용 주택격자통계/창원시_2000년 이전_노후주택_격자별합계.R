library(dplyr)
library(readr)

# ------------------------------------------------------------
# 1. 경로 및 파일 설정
# ------------------------------------------------------------

folder_path <- "C:/sgis/qgis/창원시 공공체육시설 접근성분석"

file_names <- c("2024년_주택_라라_1K.csv","2024년_주택_라마_1K.csv",
                "2024년_주택_마라_1K.csv","2024년_주택_마마_1K.csv")

# 2000년 이전 노후주택 코드
old_house_codes <- c("ho_yr_001", "ho_yr_002", "ho_yr_003")


# ------------------------------------------------------------
# 2. 파일 불러오기 및 노후주택 코드 추출
# ------------------------------------------------------------

old_house_data <- lapply(file_names, function(file) {
  
  file_path <- file.path(folder_path, file)
  
  # 헤더가 없는 CP949 인코딩 CSV 읽기
  df <- read_csv(file_path,col_names = FALSE,locale = locale(encoding = "CP949"),
                 show_col_types = FALSE,trim_ws = TRUE)
  
  # X3가 노후주택 코드인 행만 추출
  df_filtered <- df %>%
    filter(X3 %in% old_house_codes) %>%
    mutate( # 쉼표 등이 포함되어도 숫자로 변환 
      X4 = parse_number(as.character(X4)),source_file = file)
  
  return(df_filtered)
  
}) %>%
  bind_rows()

# ------------------------------------------------------------
# 3. X2 격자코드별 X4 합계 계산
# ------------------------------------------------------------

old_house_sum <- old_house_data %>%
  group_by(X2) %>%
  summarise( X4_합 = sum(X4, na.rm = TRUE),.groups = "drop") %>%
  arrange(X2)

# ------------------------------------------------------------
# 4. 결과 확인
# ------------------------------------------------------------

head(old_house_sum)

cat("원본 노후주택 행 수:", nrow(old_house_data), "\n")
cat("합산 후 격자 수:", nrow(old_house_sum), "\n")
cat("전체 노후주택 수:", sum(old_house_sum$X4_합, na.rm = TRUE), "\n")

# ------------------------------------------------------------
# 5. CSV 저장
# ------------------------------------------------------------

output_path <- file.path(folder_path,"2024년_노후주택_2000년이전.csv")

write_excel_csv(old_house_sum,output_path)

cat("저장 완료:", output_path, "\n")