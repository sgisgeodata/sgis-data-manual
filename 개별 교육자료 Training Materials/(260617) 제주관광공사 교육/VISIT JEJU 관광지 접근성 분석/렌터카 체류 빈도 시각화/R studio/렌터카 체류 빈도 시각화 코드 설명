# ============================================================
# 제주 렌터카 체류빈도 시각화
# ============================================================
#
# [분석 목적]
#
# 1. 2021년 제주 렌터카 체류빈도 합산 CSV를 불러온다.
# 2. 각 50m 격자에 기록된 렌터카 체류빈도를
#    5개의 빈도 구간으로 나눈다.
# 3. 체류빈도가 0회인 격자는 투명하게 처리하고,
#    체류빈도가 있는 격자만 색상으로 표현한다.
# 4. VISIT JEJU 여행장소 CSV에서 관광지의 위도와 경도를 불러온다.
# 5. 렌터카 체류빈도 50m 격자와 여행장소 위치를 함께 보여주는
#    확대·축소 가능한 Leaflet HTML 지도를 만든다.
#
#
# [입력 파일]
#
# ① 체류빈도_2021_합산.csv
#    - 50m 격자별 2021년 렌터카 체류빈도 합산 결과
#    - 주요 열:
#      j_50_cd       : 50m 격자 고유번호
#      체류빈도_2021 : 2021년 체류빈도 합계
#      left          : 격자 왼쪽 경계 X좌표
#      right         : 격자 오른쪽 경계 X좌표
#      bottom        : 격자 아래쪽 경계 Y좌표
#      top           : 격자 위쪽 경계 Y좌표
#      xcoord        : 격자 중심점 X좌표
#      ycoord        : 격자 중심점 Y좌표
#
# ② 제주관광공사_제주관광정보시스템(VISIT JEJU)_여행장소.csv
#    - VISIT JEJU 여행장소 위치와 주소 정보
#    - 주요 열:
#      장소명
#      위도
#      경도
#      도로명주소
#      지번주소
#
#
# [출력 파일]
#
# ① 제주_렌터카_체류빈도_시각화.html
#    - 웹 브라우저에서 열 수 있는 대화형 지도
#
# ② 제주_렌터카_체류빈도_50m.tif
#    - QGIS 등 GIS 프로그램에서도 사용할 수 있는
#      체류빈도 등급 래스터 파일
#
# ============================================================



# ============================================================
# 0. 패키지 설치 및 불러오기
# ============================================================

# 사용할 패키지 이름을 문자 벡터로 저장한다.
# c() 함수는 여러 값을 하나의 벡터로 묶는 함수이다.
packages <- c(
  "data.table",
  "terra",
  "raster",
  "sf",
  "leaflet",
  "htmlwidgets",
  "htmltools",
  "magrittr"
)


# installed.packages()
#   - 현재 컴퓨터에 설치되어 있는 패키지 목록을 가져온다.
#
# [, "Package"]
#   - 설치된 패키지 목록 중 패키지 이름 열만 선택한다.
#
# %in%
#   - 왼쪽 값이 오른쪽 목록에 포함되어 있는지를 확인한다.
#
# !
#   - TRUE와 FALSE를 반대로 바꾼다.
#
# 따라서 아래 코드는 packages 목록 중에서
# 아직 설치되지 않은 패키지만 new_packages에 저장한다.
new_packages <- packages[
  !packages %in% installed.packages()[, "Package"]
]


# length()
#   - 벡터 안에 값이 몇 개 있는지 확인한다.
#
# 설치되지 않은 패키지가 하나 이상 있을 때만
# install.packages()를 실행한다.
#
# 이미 설치된 패키지를 매번 다시 설치하지 않기 위한 과정이다.
if (length(new_packages) > 0) {
  install.packages(new_packages)
}


# library()
#   - 설치된 패키지를 현재 R 작업 환경으로 불러온다.
#
# 패키지는 한 번 설치하면 계속 사용할 수 있지만,
# R을 새로 실행할 때마다 library()로 다시 불러와야 한다.
library(data.table)
library(terra)
library(raster)
library(sf)
library(leaflet)
library(htmlwidgets)
library(htmltools)
library(magrittr)

# 패키지 설명
#
# data.table
#   - CSV 파일을 빠르게 읽고 데이터를 정리하는 데 사용한다.
#   - fread(), fifelse(), := 등의 함수를 제공한다.
#
# terra
#   - 공간 래스터 데이터를 생성하고 저장하는 데 사용한다.
#   - rast(), cellFromXY(), writeRaster() 등을 제공한다.
#
# raster
#   - terra에서 만든 래스터를 Leaflet 지도에 올릴 수 있는
#     RasterLayer 형식으로 변환하기 위해 사용한다.
#
# sf
#   - 공간 좌표계와 공간 객체를 처리하는 데 사용한다.
#   - st_bbox(), st_as_sfc(), st_transform() 등을 제공한다.
#
# leaflet
#   - 확대·축소와 레이어 선택이 가능한 HTML 지도를 만든다.
#
# htmlwidgets
#   - Leaflet 지도를 HTML 파일로 저장한다.
#
# htmltools
#   - 팝업 문자열을 안전한 HTML 형태로 처리하고,
#     CSS와 HTML 요소를 지도에 추가한다.
#
# magrittr
#   - %>% 파이프 연산자를 제공한다.
#   - 앞 단계의 결과를 다음 함수로 전달할 때 사용한다.


# ============================================================
# 1. 입력·출력 파일 경로 설정
# ============================================================

# 분석 파일들이 들어 있는 기본 폴더를 지정한다.
#
# Windows 경로에서는 역슬래시 "\" 대신 슬래시 "/"를 사용
base_dir <- "C:/Users/user/Desktop/제주"


# file.path()
#   - 폴더 경로와 파일 이름을 운영체제에 맞게 연결한다.
#
# paste0(base_dir, "/파일명")처럼 직접 붙이는 것보다
# 경로 구분자 오류가 적다는 장점이 있다.


# 2021년 렌터카 체류빈도 합산 CSV 경로
stay_file <- file.path(
  base_dir,
  "체류빈도_2021_합산.csv"
)


# VISIT JEJU 여행장소 CSV 경로
place_file <- file.path(
  base_dir,
  "제주관광공사_제주관광정보시스템(VISIT JEJU)_여행장소.csv"
)


# 최종 Leaflet HTML 지도 저장 경로
out_html <- file.path(
  base_dir,
  "제주_렌터카_체류빈도_시각화.html"
)


# 체류빈도 등급 래스터 저장 경로
out_tif <- file.path(
  base_dir,
  "제주_렌터카_체류빈도_50m.tif"
)



# ------------------------------------------------------------
# 1-1. 입력 파일 존재 여부 확인
# ------------------------------------------------------------

# file.exists()
#   - 지정한 위치에 실제 파일이 존재하면 TRUE,
#     존재하지 않으면 FALSE를 반환한다.
#
# stop()
#   - 오류 메시지를 출력하고 코드 실행을 즉시 중단한다.
#
# 파일 이름이나 폴더 경로가 틀린 상태에서 분석을 계속하면
# 뒤에서 이해하기 어려운 오류가 발생하므로,
# 분석 시작 전에 파일 존재 여부를 먼저 확인한다.

if (!file.exists(stay_file)) {
  stop(
    "체류빈도 파일을 찾을 수 없습니다:\n",
    stay_file
  )
}


if (!file.exists(place_file)) {
  stop(
    "VISIT JEJU 여행장소 파일을 찾을 수 없습니다:\n",
    place_file
  )
}



# ============================================================
# 2. 체류빈도 합산 CSV 읽기
# ============================================================

# fread()
#   - data.table 패키지에서 제공하는 CSV 읽기 함수이다.
#   - 기본 read.csv()보다 대용량 파일을 빠르게 읽을 수 있다.
#
# encoding = "UTF-8"
#   - 한글이 포함된 CSV를 UTF-8 문자 인코딩으로 읽는다.
#
# 한글이 깨져서 표시된다면 원본 CSV 인코딩에 따라
# encoding = "CP949"로 바꿔야 할 수도 있다.
grid_data <- fread(
  stay_file,
  encoding = "UTF-8"
)



# ------------------------------------------------------------
# 2-1. 필수 열 존재 여부 확인
# ------------------------------------------------------------

# 이 분석에 반드시 필요한 열 이름을 벡터로 저장한다.
required_grid_columns <- c(
  "j_50_cd",
  "체류빈도_2021",
  "left",
  "right",
  "bottom",
  "top",
  "xcoord",
  "ycoord"
)


# setdiff()
#   - 첫 번째 목록에는 있지만 두 번째 목록에는 없는 값을 찾는다.
#
# names(grid_data)
#   - grid_data의 전체 열 이름을 가져온다.
#
# 따라서 missing_grid_columns에는
# CSV에 존재하지 않는 필수 열 이름이 저장된다.
missing_grid_columns <- setdiff(
  required_grid_columns,
  names(grid_data)
)


# 필요한 열이 하나라도 없다면 분석을 중단한다.
if (length(missing_grid_columns) > 0) {
  stop(
    "체류빈도 CSV에 다음 필수 열이 없습니다:\n",
    paste(missing_grid_columns, collapse = ", ")
  )
}



# ------------------------------------------------------------
# 2-2. 열 자료형 정리
# ------------------------------------------------------------

# j_50_cd는 계산에 사용하는 숫자가 아니라
# 각 격자를 구분하는 고유번호이다.
#
# 격자번호가 숫자로 읽히면 앞자리의 0이 사라질 수 있으므로
# as.character()를 이용해 문자형으로 변환한다.
#
# data.table에서 아래와 같은 문법을 사용한다.
#
# grid_data[, 열이름 := 계산식]
#
# :=
#   - data.table 내부의 열을 새로 만들거나 수정하는 연산자이다.
#   - 일반적인 $ 또는 <- 방식보다 대용량 자료 처리에 효율적이다.
grid_data[, j_50_cd := as.character(j_50_cd)]


# 원본 체류빈도 열을 숫자형으로 변환해
# stay_total이라는 이름의 새 열에 저장한다.
#
# as.numeric()
#   - 문자로 읽힌 숫자를 실제 계산 가능한 숫자형으로 바꾼다.
grid_data[, stay_total := as.numeric(체류빈도_2021)]


# is.na()
#   - 값이 결측값 NA인지 확인한다.
#
# 체류빈도가 비어 있는 격자는
# 체류가 없었던 것으로 보고 0으로 바꾼다.
grid_data[
  is.na(stay_total),
  stay_total := 0
]



# ------------------------------------------------------------
# 2-3. 공간 좌표 열을 숫자형으로 변환
# ------------------------------------------------------------

# 숫자형으로 변환할 좌표 열 이름을 지정한다.
coordinate_columns <- c(
  "left",
  "right",
  "bottom",
  "top",
  "xcoord",
  "ycoord"
)


# .SD
#   - data.table에서 선택된 열로 구성된 임시 데이터 영역이다.
#
# .SDcols
#   - .SD에 포함할 열을 지정한다.
#
# lapply(.SD, as.numeric)
#   - 선택한 모든 열에 as.numeric()을 반복 적용한다.
#
# (coordinate_columns) := ...
#   - coordinate_columns 벡터에 적힌 여러 열을 한 번에 수정한다.
#
# 좌표가 문자형으로 저장되어 있으면 min(), max() 등의 공간 계산이
# 잘못될 수 있으므로 반드시 숫자형으로 변환한다.
grid_data[
  ,
  (coordinate_columns) := lapply(.SD, as.numeric),
  .SDcols = coordinate_columns
]



# ------------------------------------------------------------
# 2-4. 좌표 결측값 확인
# ------------------------------------------------------------

# complete.cases()
#   - 선택한 열이 모두 결측값 없이 채워져 있으면 TRUE를 반환한다.
#
# 좌표가 하나라도 비어 있는 행은 정상적인 격자를 만들 수 없으므로
# 해당 행을 제외한다.
valid_grid_rows <- complete.cases(
  grid_data[, ..coordinate_columns]
)


# 제외될 행의 수를 계산한다.
invalid_grid_count <- sum(!valid_grid_rows)


# 잘못된 좌표 행이 있다면 개수를 화면에 알린다.
if (invalid_grid_count > 0) {
  warning(
    invalid_grid_count,
    "개의 격자에서 좌표 결측값이 발견되어 제외합니다."
  )
}


# 정상적인 좌표를 가진 행만 다시 저장한다.
grid_data <- grid_data[valid_grid_rows]



# ------------------------------------------------------------
# 2-5. 데이터 기본 현황 출력
# ------------------------------------------------------------

# cat()
#   - R 콘솔에 문자와 계산 결과를 출력한다.
#
# nrow()
#   - 데이터의 행 개수를 반환한다.
#
# 각 행이 50m 격자 하나를 의미하므로
# nrow(grid_data)는 전체 격자 수이다.
cat("격자 수:", nrow(grid_data), "\n")


# sum(grid_data$stay_total > 0)
#   - 체류빈도가 0보다 큰 격자만 TRUE가 된다.
#   - R에서는 TRUE가 1처럼 계산되므로 sum()을 사용하면
#     조건을 만족하는 격자의 수를 구할 수 있다.
cat(
  "체류빈도 0 초과 격자 수:",
  sum(grid_data$stay_total > 0),
  "\n"
)


# max()
#   - 체류빈도 중 가장 큰 값을 찾는다.
#
# na.rm = TRUE
#   - 결측값이 있더라도 제외하고 최댓값을 계산한다.
cat(
  "최대 체류빈도:",
  max(grid_data$stay_total, na.rm = TRUE),
  "\n"
)



# ============================================================
# 3. 체류빈도 색상 등급 설정
# ============================================================

# 체류빈도를 다음과 같이 구분한다.
#
# 0회       : 투명
# 1~10회    : 1등급
# 11~50회   : 2등급
# 51~100회  : 3등급
# 101~250회 : 4등급
# 251회 이상: 5등급
#
# 원래 체류빈도 값을 그대로 색상화하면
# 매우 큰 값 때문에 대부분의 낮은 값이 비슷한 색으로 보일 수 있다.
#
# 따라서 연구자가 의미를 해석하기 쉬운 고정 구간으로 나누어
# 지도의 가독성을 높인다.


# 범례에 표시할 문구를 저장한다.
#
# 첫 번째 값은 0회이고,
# 나머지 다섯 값은 색상이 있는 체류빈도 구간이다.
stay_labels <- c(
  "0회",
  "1~10회",
  "11~50회",
  "51~100회",
  "101~250회",
  "251회 이상"
)


# 양수 체류빈도 5개 등급에 사용할 색상을 지정한다.
#
# 색상은 "#RRGGBB" 형식의 HEX 색상 코드이다.
#
# 낮은 체류빈도는 밝은 노란색,
# 높은 체류빈도는 진한 붉은색으로 표현한다.
stay_colors <- c(
  "#fff7bc",  # 1등급: 1~10회
  "#fee391",  # 2등급: 11~50회
  "#fec44f",  # 3등급: 51~100회
  "#fc8d59",  # 4등급: 101~250회
  "#d7301f"   # 5등급: 251회 이상
)



# ------------------------------------------------------------
# 3-1. 체류빈도를 1~5 등급으로 변환
# ------------------------------------------------------------

# fcase()
#   - data.table에서 여러 조건을 순서대로 검사하는 함수이다.
#   - base R의 ifelse()를 여러 번 중첩하는 것보다
#     조건 구간을 읽기 쉽다는 장점이 있다.
#
# fcase()는 위에서부터 조건을 검사하고,
# 처음으로 TRUE가 된 조건의 값을 반환한다.
#
# stay_total == 0인 경우 NA_real_을 부여한다.
#
# NA_real_
#   - 숫자형 결측값을 의미한다.
#
# 래스터에서 NA는 지도에 그려지지 않기 때문에
# 0회 격자는 완전히 투명하게 표현된다.
#
# default = 5
#   - 앞의 조건에 해당하지 않는 값은 모두 5등급으로 처리한다.
#   - 즉, 250보다 큰 값이 5등급이 된다.
grid_data[, stay_class := fcase(
  stay_total == 0,   NA_real_,
  stay_total <= 10,  1,
  stay_total <= 50,  2,
  stay_total <= 100, 3,
  stay_total <= 250, 4,
  default = 5
)]


# 실제 적용된 구간을 콘솔에 출력한다.
cat("\n고정 구간:\n")
cat(" - ", stay_labels[1], " (투명)\n", sep = "")
cat(" - ", stay_labels[2], "\n", sep = "")
cat(" - ", stay_labels[3], "\n", sep = "")
cat(" - ", stay_labels[4], "\n", sep = "")
cat(" - ", stay_labels[5], "\n", sep = "")
cat(" - ", stay_labels[6], "\n", sep = "")



# ============================================================
# 4. 체류빈도 50m 래스터 만들기
# ============================================================

# 래스터는 공간을 일정한 크기의 사각형 셀로 나눈 자료이다.
#
# 이번 분석의 격자는 한 변이 50m이므로
# 해상도 50m의 래스터를 생성한다.
#
# CSV에는 격자의 좌표와 체류빈도가 있지만,
# Leaflet 지도나 QGIS에서 공간 자료로 사용하려면
# 이를 실제 래스터 구조로 변환해야 한다.


# rast()
#   - terra 패키지에서 빈 SpatRaster 객체를 만드는 함수이다.
#
# xmin, xmax
#   - 래스터의 최소·최대 X좌표
#
# ymin, ymax
#   - 래스터의 최소·최대 Y좌표
#
# resolution = 50
#   - 각 셀의 가로와 세로 크기를 50m로 설정한다.
#
# crs = "EPSG:5179"
#   - 원본 격자 좌표계를 EPSG:5179로 지정한다.
#
# EPSG:5179
#   - Korea 2000 / Unified CS 좌표계이다.
#   - 한국의 공공 공간자료에서 자주 사용되는 미터 단위 좌표계이다.
#   - 좌표 단위가 미터이므로 resolution = 50은 실제 50m를 의미한다.
stay_raster <- rast(
  xmin = min(grid_data$left, na.rm = TRUE),
  xmax = max(grid_data$right, na.rm = TRUE),
  ymin = min(grid_data$bottom, na.rm = TRUE),
  ymax = max(grid_data$top, na.rm = TRUE),
  resolution = 50,
  crs = "EPSG:5179"
)


# 래스터 레이어 이름을 stay_class로 지정한다.
#
# names()
#   - 객체의 이름을 확인하거나 변경하는 함수이다.
names(stay_raster) <- "stay_class"



# ------------------------------------------------------------
# 4-1. 각 격자 중심점이 들어가는 래스터 셀 찾기
# ------------------------------------------------------------

# grid_data에서 xcoord와 ycoord 열만 선택해 행렬로 변환한다.
#
# as.matrix()
#   - 데이터프레임 또는 data.table을 행렬 형태로 바꾼다.
#
# cellFromXY()
#   - 각 X·Y 좌표가 래스터의 몇 번째 셀에 해당하는지 계산한다.
#
# 결과인 raster_cells에는 각 CSV 행과 대응하는
# 래스터 셀 번호가 저장된다.
raster_cells <- terra::cellFromXY(
  stay_raster,
  as.matrix(
    grid_data[, .(xcoord, ycoord)]
  )
)



# ------------------------------------------------------------
# 4-2. 래스터 셀에 체류빈도 등급 입력
# ------------------------------------------------------------

# stay_raster[raster_cells]
#   - 앞에서 찾은 셀 위치를 선택한다.
#
# grid_data$stay_class
#   - 각 격자의 체류빈도 등급을 선택한 래스터 셀에 입력한다.
#
# 체류빈도가 0인 격자는 stay_class가 NA이므로
# 해당 래스터 셀도 NA로 유지된다.
stay_raster[raster_cells] <- grid_data$stay_class



# ------------------------------------------------------------
# 4-3. GeoTIFF 래스터 파일 저장
# ------------------------------------------------------------

# writeRaster()
#   - terra 래스터를 실제 파일로 저장한다.
#
# out_tif
#   - 저장할 파일 경로
#
# overwrite = TRUE
#   - 같은 이름의 파일이 이미 있으면 덮어쓴다.
#
# datatype = "INT2S"
#   - 2바이트 부호 있는 정수형으로 저장한다.
#   - 현재 값은 1~5의 작은 정수이므로 충분하다.
#
# NAflag = -9999
#   - 래스터 파일 내부에서 결측값을 -9999로 기록한다.
#   - QGIS에서는 이 값을 NoData로 인식한다.
writeRaster(
  stay_raster,
  out_tif,
  overwrite = TRUE,
  datatype = "INT2S",
  NAflag = -9999
)



# ------------------------------------------------------------
# 4-4. Leaflet용 래스터 형식으로 변환
# ------------------------------------------------------------

# terra 패키지의 SpatRaster를
# raster 패키지의 RasterLayer로 변환한다.
#
# Leaflet의 addRasterImage()는 RasterLayer 형식을
# 안정적으로 처리할 수 있기 때문에 변환 과정을 거친다.
stay_raster_leaflet <- raster::raster(stay_raster)



# ------------------------------------------------------------
# 4-5. 래스터 값과 색상 연결
# ------------------------------------------------------------

# colorFactor()
#   - 범주형 값에 각각 다른 색상을 연결하는 함수이다.
#
# palette = stay_colors
#   - 사용할 색상 목록
#
# domain = c(1, 2, 3, 4, 5)
#   - 래스터에서 색을 부여할 실제 등급 값
#
# na.color = "transparent"
#   - NA인 셀은 완전히 투명하게 처리한다.
#
# 따라서 체류빈도 0회인 격자는 지도에서 색이 표시되지 않는다.
stay_palette <- colorFactor(
  palette = stay_colors,
  domain = c(1, 2, 3, 4, 5),
  na.color = "transparent"
)



# ============================================================
# 5. VISIT JEJU 여행장소 데이터 읽기
# ============================================================

# VISIT JEJU 여행장소 CSV를 불러온다.
place_data <- fread(
  place_file,
  encoding = "UTF-8"
)



# ------------------------------------------------------------
# 5-1. 여행장소 필수 열 확인
# ------------------------------------------------------------

# 관광지 위치와 팝업을 만들 때 필요한 열을 지정한다.
required_place_columns <- c(
  "장소명",
  "위도",
  "경도",
  "도로명주소",
  "지번주소"
)


# 여행장소 CSV에서 누락된 필수 열을 찾는다.
missing_place_columns <- setdiff(
  required_place_columns,
  names(place_data)
)


# 필수 열이 없다면 실행을 중단한다.
if (length(missing_place_columns) > 0) {
  stop(
    "여행장소 CSV에 다음 필수 열이 없습니다:\n",
    paste(missing_place_columns, collapse = ", ")
  )
}



# ------------------------------------------------------------
# 5-2. 위도·경도를 숫자형으로 변환
# ------------------------------------------------------------

# 원본의 위도 열을 숫자형으로 바꾸어 lat 열에 저장한다.
#
# lat은 latitude의 줄임말로 위도를 의미한다.
place_data[, lat := as.numeric(위도)]


# 원본의 경도 열을 숫자형으로 바꾸어 lon 열에 저장한다.
#
# lon은 longitude의 줄임말로 경도를 의미한다.
place_data[, lon := as.numeric(경도)]



# ------------------------------------------------------------
# 5-3. 제주도 범위에 포함되는 여행장소만 선택
# ------------------------------------------------------------

# 다음 조건을 모두 만족하는 행만 남긴다.
#
# !is.na(lat), !is.na(lon)
#   - 위도와 경도가 비어 있지 않아야 한다.
#
# lat >= 33.0 & lat <= 33.7
#   - 위도가 제주도 주변 범위에 있어야 한다.
#
# lon >= 126.0 & lon <= 127.2
#   - 경도가 제주도 주변 범위에 있어야 한다.
#
# 잘못 입력된 좌표나 다른 지역의 위치가 지도에 표시되는 것을
# 방지하기 위한 간단한 공간 범위 필터이다.
place_data <- place_data[
  !is.na(lat) &
    !is.na(lon) &
    lat >= 33.0 &
    lat <= 33.7 &
    lon >= 126.0 &
    lon <= 127.2
]



# ------------------------------------------------------------
# 5-4. 팝업에 사용할 문자 정리 함수
# ------------------------------------------------------------

# clean_text라는 사용자 정의 함수를 만든다.
#
# function(text_value)
#   - text_value라는 값을 입력받는 함수를 정의한다.
#
# 이 함수는 팝업에 들어갈 장소명과 주소를 안전한 HTML 문자로
# 변환하는 역할을 한다.
clean_text <- function(text_value) {

  # 입력값을 문자형으로 변환한다.
  text_value <- as.character(text_value)

  # 결측값은 빈 문자열로 바꾼다.
  #
  # 결측값을 그대로 paste0()에 넣으면
  # 팝업에 NA라는 글자가 나타날 수 있다.
  text_value[is.na(text_value)] <- ""

  # htmlEscape()
  #   - <, >, &, 따옴표처럼 HTML 문법과 충돌할 수 있는 문자를
  #     안전한 형태로 변환한다.
  #
  # 장소명이나 주소에 특수문자가 포함되어 있어도
  # 지도 팝업의 HTML 구조가 깨지지 않도록 한다.
  htmltools::htmlEscape(text_value)
}



# ------------------------------------------------------------
# 5-5. 지도 팝업 내용 만들기
# ------------------------------------------------------------

# paste0()
#   - 여러 문자와 값을 공백 없이 이어 붙인다.
#
# <b>...</b>
#   - 장소명을 굵은 글씨로 표시하는 HTML 태그이다.
#
# <br>
#   - 줄바꿈을 의미하는 HTML 태그이다.
#
# 각 여행장소 핀을 클릭하면
# 장소명, 도로명주소, 지번주소가 나타나도록 popup 열을 만든다.
place_data[, popup := paste0(
  "<b>",
  clean_text(장소명),
  "</b><br>",
  "도로명주소: ",
  clean_text(도로명주소),
  "<br>",
  "지번주소: ",
  clean_text(지번주소)
)]


# 최종적으로 지도에 표시할 여행장소 수를 출력한다.
cat(
  "제주 지역 여행장소 핀 수:",
  nrow(place_data),
  "\n"
)



# ============================================================
# 6. 지도를 처음 열었을 때 보여줄 범위 계산
# ============================================================

# 현재 격자 좌표는 EPSG:5179 미터 좌표계이다.
#
# 그러나 Leaflet은 경도·위도 좌표계인 EPSG:4326을 사용한다.
#
# 따라서 전체 격자의 외곽 범위를 EPSG:5179로 만든 다음
# EPSG:4326으로 변환해야 한다.



# ------------------------------------------------------------
# 6-1. EPSG:5179 좌표계의 격자 경계상자 만들기
# ------------------------------------------------------------

# st_bbox()
#   - xmin, ymin, xmax, ymax 값을 이용해
#     사각형 형태의 경계상자를 만든다.
#
# st_crs(5179)
#   - 해당 좌표가 EPSG:5179 좌표계임을 지정한다.
#
# st_as_sfc()
#   - 단순한 경계상자를 실제 sf 공간 객체로 변환한다.
grid_bbox_5179 <- st_as_sfc(
  st_bbox(
    c(
      xmin = min(grid_data$left, na.rm = TRUE),
      ymin = min(grid_data$bottom, na.rm = TRUE),
      xmax = max(grid_data$right, na.rm = TRUE),
      ymax = max(grid_data$top, na.rm = TRUE)
    ),
    crs = st_crs(5179)
  )
)



# ------------------------------------------------------------
# 6-2. 경계상자를 EPSG:4326으로 변환
# ------------------------------------------------------------

# st_transform()
#   - 공간 객체의 좌표계를 변환한다.
#
# 4326
#   - WGS84 경도·위도 좌표계이다.
#   - 일반적인 웹 지도와 GPS에서 사용하는 좌표계이다.
#
# st_bbox()
#   - 변환된 공간 객체에서 다시
#     xmin, ymin, xmax, ymax 값을 추출한다.
grid_bbox_4326 <- st_bbox(
  st_transform(
    grid_bbox_5179,
    4326
  )
)



# ============================================================
# 7. 지도 범례와 레이어 선택창 CSS 설정
# ============================================================

# CSS는 HTML 화면의 글자 크기, 여백, 테두리,
# 배경색 등을 꾸미는 문법이다.
#
# 아래 CSS는 다음 요소를 크게 표시하도록 설정한다.
#
# - 지도 우측 상단의 레이어 선택창
# - 지도 좌측 상단의 확대·축소 버튼
# - 지도 우측 하단의 사용자 정의 범례
#
# HTML()
#   - 문자열을 일반 문자가 아니라
#     실제 HTML/CSS 코드로 인식하도록 만든다.
map_css <- HTML("
  /* --------------------------------------------------------
     우측 상단 레이어 선택창 전체 설정
     -------------------------------------------------------- */

  .leaflet-control-layers {
    font-size: 20px !important;
    line-height: 1.6 !important;
    padding: 12px 14px !important;
    border-radius: 12px !important;
    background: rgba(255,255,255,0.96) !important;
  }


  /* 레이어 선택창을 펼쳤을 때의 최소 너비 */
  .leaflet-control-layers-expanded {
    min-width: 270px !important;
  }


  /* 각 레이어 선택 항목의 줄 간격 */
  .leaflet-control-layers label {
    display: block !important;
    padding: 7px 0 !important;
    margin: 0 !important;
  }


  /* 체크박스와 라디오 버튼의 크기 */
  .leaflet-control-layers-selector {
    transform: scale(1.5);
    margin-right: 10px !important;
  }


  /* 터치 환경에서 접힌 레이어 버튼 크기 */
  .leaflet-touch .leaflet-control-layers-toggle {
    width: 48px !important;
    height: 48px !important;
    background-size: 28px 28px !important;
  }


  /* 좌측 상단 확대·축소 버튼 */
  .leaflet-control-zoom a {
    width: 42px !important;
    height: 42px !important;
    line-height: 42px !important;
    font-size: 24px !important;
  }


  /* --------------------------------------------------------
     우측 하단 사용자 정의 범례 전체 설정
     -------------------------------------------------------- */

  .custom-legend {
    background: rgba(255,255,255,0.96);
    padding: 14px 16px;
    border-radius: 12px;
    box-shadow: 0 1px 5px rgba(0,0,0,0.3);
    font-size: 18px;
    line-height: 1.8;
    color: #333;
  }


  /* 범례 제목 */
  .custom-legend .legend-title {
    font-weight: 700;
    margin-bottom: 8px;
    font-size: 20px;
  }


  /* 범례 한 줄 */
  .custom-legend .legend-row {
    display: flex;
    align-items: center;
    margin-bottom: 4px;
  }


  /* 범례 색상 네모 */
  .custom-legend .legend-box {
    width: 24px;
    height: 24px;
    margin-right: 10px;
    border: 1px solid #777;
    box-sizing: border-box;
  }


  /* --------------------------------------------------------
     화면 너비가 768px 이하인 모바일·작은 화면 설정
     -------------------------------------------------------- */

  @media (max-width: 768px) {

    .leaflet-control-layers {
      font-size: 21px !important;
      padding: 14px 16px !important;
    }

    .leaflet-control-layers-expanded {
      min-width: 290px !important;
    }

    .leaflet-control-layers-selector {
      transform: scale(1.7);
      margin-right: 12px !important;
    }

    .custom-legend {
      font-size: 19px;
      line-height: 1.9;
      padding: 16px 18px;
    }

    .custom-legend .legend-title {
      font-size: 21px;
    }

    .custom-legend .legend-box {
      width: 26px;
      height: 26px;
    }
  }
")



# ============================================================
# 8. 사용자 정의 범례 HTML 만들기
# ============================================================

# 기본 addLegend() 대신 직접 HTML 범례를 만드는 이유는
# 0회 격자를 투명한 점선 박스로 표현하기 위해서이다.
#
# paste0()를 사용해 HTML 문자열과 색상값을 연결한다.
#
# stay_colors[1]
#   - stay_colors의 첫 번째 색상
#
# stay_labels[1]
#   - stay_labels의 첫 번째 문구
legend_html <- HTML(
  paste0(
    "<div class='custom-legend'>",

    "<div class='legend-title'>",
    "2021년 합산 체류빈도",
    "</div>",

    # 0회는 실제 지도에서 투명하다.
    # 범례에서도 투명한 박스와 점선 테두리로 표현한다.
    "<div class='legend-row'>",
    "<span class='legend-box' ",
    "style='background: transparent; ",
    "border: 2px dashed #999;'>",
    "</span>",
    stay_labels[1],
    "</div>",

    # 1~10회
    "<div class='legend-row'>",
    "<span class='legend-box' style='background:",
    stay_colors[1],
    ";'></span>",
    stay_labels[2],
    "</div>",

    # 11~50회
    "<div class='legend-row'>",
    "<span class='legend-box' style='background:",
    stay_colors[2],
    ";'></span>",
    stay_labels[3],
    "</div>",

    # 51~100회
    "<div class='legend-row'>",
    "<span class='legend-box' style='background:",
    stay_colors[3],
    ";'></span>",
    stay_labels[4],
    "</div>",

    # 101~250회
    "<div class='legend-row'>",
    "<span class='legend-box' style='background:",
    stay_colors[4],
    ";'></span>",
    stay_labels[5],
    "</div>",

    # 251회 이상
    "<div class='legend-row'>",
    "<span class='legend-box' style='background:",
    stay_colors[5],
    ";'></span>",
    stay_labels[6],
    "</div>",

    "</div>"
  )
)



# ============================================================
# 9. Leaflet HTML 지도 만들기
# ============================================================

# leaflet()
#   - 새로운 Leaflet 지도 객체를 만든다.
#
# 이후 %>%를 사용해 배경지도, 래스터, 관광지 핀,
# 범례 등을 순서대로 추가한다.
#
# %>%
#   - 앞 함수의 결과를 다음 함수의 첫 번째 입력값으로 전달한다.
#   - 여러 지도 구성 요소를 위에서 아래로 연결할 수 있다.


jeju_map <- leaflet(

  # leafletOptions()
  #   - 지도의 기본 동작을 설정한다.
  options = leafletOptions(

    # 사용자가 축소할 수 있는 최소 확대 수준
    minZoom = 9,

    # 사용자가 확대할 수 있는 최대 확대 수준
    maxZoom = 21,

    # 마우스 휠로 확대·축소할 수 있도록 설정
    scrollWheelZoom = TRUE,

    # 많은 원형 마커를 SVG 대신 Canvas 방식으로 그린다.
    # 핀이 많을 때 지도 성능을 높이는 데 도움이 된다.
    preferCanvas = TRUE
  )

) %>%


  # ----------------------------------------------------------
  # 9-1. 밝은 배경지도 추가
  # ----------------------------------------------------------

  # addProviderTiles()
  #   - Leaflet에서 제공하는 외부 배경지도를 추가한다.
  #
  # providers$CartoDB.Positron
  #   - 지명과 도로가 단순하게 표시되는 밝은 배경지도이다.
  #
  # group
  #   - 레이어 선택창에 표시할 이름이다.
  addProviderTiles(
    providers$CartoDB.Positron,
    group = "밝은 지도"
  ) %>%


  # ----------------------------------------------------------
  # 9-2. 위성 배경지도 추가
  # ----------------------------------------------------------

  # Esri.WorldImagery
  #   - Esri에서 제공하는 위성영상 배경지도이다.
  addProviderTiles(
    providers$Esri.WorldImagery,
    group = "위성지도"
  ) %>%


  # ----------------------------------------------------------
  # 9-3. 체류빈도 래스터 추가
  # ----------------------------------------------------------

  # addRasterImage()
  #   - 래스터 자료를 Leaflet 지도 위에 이미지 형태로 올린다.
  #
  # colors = stay_palette
  #   - 래스터의 1~5 등급을 앞에서 지정한 색상과 연결한다.
  #
  # opacity = 0.7
  #   - 전체 래스터의 불투명도를 70%로 설정한다.
  #   - 배경지도도 함께 볼 수 있도록 약간 투명하게 만든다.
  #
  # project = TRUE
  #   - EPSG:5179 래스터를 Leaflet용 웹 지도 좌표계로 변환한다.
  #
  # method = "ngb"
  #   - 최근접 이웃 방식으로 좌표를 변환한다.
  #   - 등급형 자료의 1~5 값이 중간값으로 섞이지 않게 한다.
  #
  # maxBytes = Inf
  #   - Leaflet의 기본 래스터 용량 제한을 해제한다.
  #   - 다만 래스터가 매우 크면 HTML 파일 크기도 커질 수 있다.
  addRasterImage(
    stay_raster_leaflet,
    colors = stay_palette,
    opacity = 0.7,
    group = "렌터카 체류빈도 50m 격자",
    project = TRUE,
    method = "ngb",
    maxBytes = Inf
  ) %>%


  # ----------------------------------------------------------
  # 9-4. VISIT JEJU 여행장소 핀 추가
  # ----------------------------------------------------------

  # addCircleMarkers()
  #   - 위도·경도 위치에 원형 마커를 추가한다.
  #
  # data = place_data
  #   - 사용할 데이터
  #
  # lng = ~lon
  #   - 경도 열
  #
  # lat = ~lat
  #   - 위도 열
  #
  # ~lon, ~lat
  #   - place_data 내부의 lon과 lat 열을 사용한다는 뜻이다.
  #
  # radius = 5
  #   - 원형 핀 반지름을 화면 픽셀 단위로 지정한다.
  #   - 실제 거리 5m를 의미하는 것은 아니다.
  #
  # color
  #   - 원형 핀 외곽선 색상
  #
  # weight
  #   - 외곽선 두께
  #
  # fillColor
  #   - 핀 내부 색상
  #
  # fillOpacity
  #   - 핀 내부 불투명도
  #
  # popup
  #   - 핀을 클릭했을 때 표시할 정보
  #
  # label
  #   - 마우스를 핀 위에 올렸을 때 표시할 장소명
  #
  # markerClusterOptions()
  #   - 가까운 핀들을 하나의 숫자 묶음으로 표시한다.
  #   - 핀이 많을 때 지도가 복잡해지는 것을 방지한다.
  addCircleMarkers(
    data = place_data,
    lng = ~lon,
    lat = ~lat,
    radius = 5,
    color = "#222222",
    weight = 1,
    fillColor = "#2b8cbe",
    fillOpacity = 0.85,
    popup = ~popup,
    label = ~장소명,
    group = "여행장소 핀",
    clusterOptions = markerClusterOptions()
  ) %>%


  # ----------------------------------------------------------
  # 9-5. 사용자 정의 범례 추가
  # ----------------------------------------------------------

  # addControl()
  #   - 지도 위에 사용자 정의 HTML 요소를 추가한다.
  #
  # position = "bottomright"
  #   - 범례를 오른쪽 아래에 배치한다.
  addControl(
    html = legend_html,
    position = "bottomright"
  ) %>%


  # ----------------------------------------------------------
  # 9-6. 축척 막대 추가
  # ----------------------------------------------------------

  # addScaleBar()
  #   - 현재 확대 수준에 맞는 거리 축척을 표시한다.
  #
  # metric = TRUE
  #   - m와 km 단위를 표시한다.
  #
  # imperial = FALSE
  #   - mile과 feet 단위는 표시하지 않는다.
  addScaleBar(
    position = "bottomleft",
    options = scaleBarOptions(
      metric = TRUE,
      imperial = FALSE
    )
  ) %>%


  # ----------------------------------------------------------
  # 9-7. 배경지도·레이어 선택창 추가
  # ----------------------------------------------------------

  # addLayersControl()
  #   - 사용자가 지도 레이어를 켜고 끌 수 있는 선택창을 만든다.
  #
  # baseGroups
  #   - 한 번에 하나만 선택하는 배경지도 목록
  #
  # overlayGroups
  #   - 각각 독립적으로 켜고 끌 수 있는 분석 레이어 목록
  #
  # collapsed = FALSE
  #   - 레이어 선택창이 처음부터 펼쳐진 상태로 표시된다.
  addLayersControl(
    baseGroups = c(
      "밝은 지도",
      "위성지도"
    ),
    overlayGroups = c(
      "렌터카 체류빈도 50m 격자",
      "여행장소 핀"
    ),
    options = layersControlOptions(
      collapsed = FALSE
    )
  ) %>%


  # ----------------------------------------------------------
  # 9-8. 지도의 초기 표시 범위 설정
  # ----------------------------------------------------------

  # fitBounds()
  #   - 지정된 경계 전체가 화면에 들어오도록
  #     지도의 중심과 확대 수준을 자동 조정한다.
  #
  # 앞에서 EPSG:4326으로 변환한 격자 경계를 사용한다.
  #
  # as.numeric()
  #   - sf 경계값을 일반 숫자로 변환한다.
  fitBounds(
    lng1 = as.numeric(grid_bbox_4326["xmin"]),
    lat1 = as.numeric(grid_bbox_4326["ymin"]),
    lng2 = as.numeric(grid_bbox_4326["xmax"]),
    lat2 = as.numeric(grid_bbox_4326["ymax"])
  ) %>%


  # ----------------------------------------------------------
  # 9-9. CSS를 HTML 지도에 삽입
  # ----------------------------------------------------------

  # prependContent()
  #   - 지도 HTML 문서의 앞부분에 추가 내용을 삽입한다.
  #
  # tags$head()
  #   - HTML 문서의 head 영역을 만든다.
  #
  # tags$style()
  #   - 앞에서 작성한 CSS를 style 태그로 삽입한다.
  prependContent(
    tags$head(
      tags$style(map_css)
    )
  )



# ============================================================
# 10. Leaflet 지도를 HTML 파일로 저장
# ============================================================

# saveWidget()
#   - htmlwidgets 형식의 객체를 HTML 파일로 저장한다.
#
# widget = jeju_map
#   - 저장할 Leaflet 지도 객체
#
# file = out_html
#   - 저장할 HTML 파일 경로
#
# selfcontained = TRUE
#   - 지도에 필요한 JavaScript와 CSS 파일을
#     하나의 HTML 파일 안에 포함한다.
#
# 따라서 별도의 lib 폴더 없이 HTML 파일 하나만 이동해도
# 대부분의 환경에서 지도를 열 수 있다.
#
# 다만 래스터와 핀이 많으면 HTML 파일 용량이 커질 수 있다.
#
# title
#   - 브라우저 탭에 표시할 제목이다.
htmlwidgets::saveWidget(
  widget = jeju_map,
  file = out_html,
  selfcontained = TRUE,
  title = "제주 렌터카 체류빈도 시각화"
)



# ============================================================
# 11. 저장된 HTML 지도 열기
# ============================================================

# normalizePath()
#   - 저장 경로를 운영체제가 인식하기 쉬운 절대경로로 정리한다.
#
# winslash = "/"
#   - Windows 경로 구분자를 "/" 형태로 바꾼다.
#
# mustWork = FALSE
#   - 경로 확인 과정에서 파일이 아직 인식되지 않더라도
#     즉시 오류를 발생시키지 않는다.
#
# browseURL()
#   - 지정된 파일이나 URL을 기본 웹 브라우저에서 연다.
browseURL(
  normalizePath(
    out_html,
    winslash = "/",
    mustWork = FALSE
  )
)



# ============================================================
# 12. 최종 결과 경로 출력
# ============================================================

cat("\n분석이 완료되었습니다.\n")

cat(
  "HTML 지도:",
  out_html,
  "\n"
)

cat(
  "50m 체류빈도 래스터:",
  out_tif,
  "\n"
)
