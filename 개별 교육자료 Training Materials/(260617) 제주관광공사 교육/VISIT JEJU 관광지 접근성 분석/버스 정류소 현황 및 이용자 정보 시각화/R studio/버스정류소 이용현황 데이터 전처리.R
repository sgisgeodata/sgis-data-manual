# ============================================================
# 이용자유형별 버스정류소 이용인원 현황 정류장별 합산
# - station_name 기준으로 user_type 무시하고 user_count 합산
# - 결과: station_name, user_count
# ============================================================

library(data.table)

# 1. 파일 경로 설정 --------------------------------------------

base_dir <- "C:/Users/user/Desktop/제주"

input_file <- file.path(
  base_dir,
  "이용자유형별버스정류소이용인원현황.csv"
)

output_file <- file.path(
  base_dir,
  "버스정류소_이용인원_정류장별합산.csv"
)


# 2. CSV 불러오기 ----------------------------------------------

bus_data <- fread(
  input_file,
  encoding = "UTF-8"
)


# 3. 컬럼명 확인용 출력 ----------------------------------------

print(names(bus_data))


# 4. base_date, user_count 자료형 정리 --------------------------

bus_data[, base_date := as.integer(base_date)]
bus_data[, user_count := as.numeric(user_count)]


# 5. station_name 기준 user_count 합산 --------------------------
# user_type은 group_by에 넣지 않으므로 자동으로 무시됨

result_bus <- bus_data[
  ,
  .(
    user_count = sum(user_count, na.rm = TRUE)
  ),
  by = station_name
]


# 7. 보기 좋게 정렬 --------------------------------------------

setorder(result_bus, -user_count)


# 8. 결과 저장 --------------------------------------------------

fwrite(
  result_bus,
  output_file,
  bom = TRUE
)


# 9. 저장 완료 메시지 ------------------------------------------

cat("저장 완료:", output_file, "\n")