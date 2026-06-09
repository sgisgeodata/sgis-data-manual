# ============================================================
# 제주 렌터카 체류빈도 시각화
#
# 1. 2021년 합산 체류빈도 CSV를 불러와 50m 격자별 체류빈도를 정리한다.
# 2. VISIT JEJU 여행장소 CSV의 위도/경도 정보를 이용해 관광지 위치를 준비한다.
# 3. 체류빈도 격자와 관광지 핀을 함께 표시한 확대/축소 가능한 HTML 지도를 만든다.
# ============================================================

# 0. 패키지 설치 및 불러오기 -----------------------------------
# 필요한 패키지가 설치되어 있지 않으면 자동 설치

packages <- c(
  "data.table",
  "terra",
  "raster",
  "sf",
  "leaflet",
  "htmlwidgets",
  "htmltools"
)

new_packages <- packages[!packages %in% installed.packages()[, "Package"]]

if (length(new_packages) > 0) {
  install.packages(new_packages)
}

library(data.table)
library(terra)
library(raster)
library(sf)
library(leaflet)
library(htmlwidgets)
library(htmltools)


# 1. 경로 설정 -------------------------------------------------
# 작업 폴더와 입력/출력 파일 경로 지정

base_dir <- "C:/Users/user/Desktop/제주"

stay_file <- file.path(base_dir, "체류빈도_2021_합산.csv")

place_file <- file.path(
  base_dir,
  "제주관광공사_제주관광정보시스템(VISIT JEJU)_여행장소.csv"
)

out_html <- file.path(base_dir, "제주_렌터카_체류빈도_시각화.html")
out_tif  <- file.path(base_dir, "제주_렌터카_체류빈도_50m.tif")


# 2. 체류빈도 합산 CSV 읽기 ------------------------------------
# grid: 제주도 50m 격자별 렌터카 체류빈도 데이터

grid_data <- fread(stay_file, encoding = "UTF-8")

# j_50_cd는 제주 50m 격자를 구분하는 고유 격자 ID 코드
grid_data[, j_50_cd := as.character(j_50_cd)]

# 체류빈도_2021 컬럼을 지도 제작에 쓰기 쉬운 이름으로 복사
grid_data[, stay_total := as.numeric(체류빈도_2021)]

# 결측값은 체류빈도 0으로 처리
grid_data[is.na(stay_total), stay_total := 0]

cat("격자 수:", nrow(grid_data), "\n")
cat("체류빈도 0 초과 격자 수:", sum(grid_data$stay_total > 0), "\n")
cat("최대 체류빈도:", max(grid_data$stay_total), "\n")


# 3. 색상 구간 설정 --------------------------------------------
# 체류빈도 값에 따라 지도 색을 다르게 표시하기 위한 구간

stay_breaks <- c(
  -0.5, 0.5, 1.5, 2.5, 5.5, 10.5, 20.5,
  50.5, 100.5, 200.5, 500.5, 1000.5,
  max(1001.5, max(grid_data$stay_total) + 0.5)
)

stay_labels <- c(
  "0회", "1회", "2회", "3-5회", "6-10회", "11-20회",
  "21-50회", "51-100회", "101-200회", "201-500회",
  "501-1000회", "1001회 이상"
)

stay_colors <- c(
  "#f2f2f2",
  grDevices::colorRampPalette(
    c("#ffffcc", "#ffeda0", "#feb24c", "#f03b20", "#bd0026", "#800026")
  )(length(stay_labels) - 1)
)

# colorBin은 체류빈도 값을 구간별 색으로 바꿔주는 함수
stay_palette <- colorBin(
  palette = stay_colors,
  domain = grid_data$stay_total,
  bins = stay_breaks,
  na.color = "transparent"
)


# 4. 50m 래스터 만들기 -----------------------------------------
# leaflet에 격자 전체를 빠르게 표시하기 위해 점/폴리곤 대신 raster로 변환
# EPSG:5179는 한국 중부원점 계열의 투영좌표계로, 현재 격자 좌표와 맞춤

stay_raster <- rast(
  xmin = min(grid_data$left),
  xmax = max(grid_data$right),
  ymin = min(grid_data$bottom),
  ymax = max(grid_data$top),
  resolution = 50,
  crs = "EPSG:5179"
)

names(stay_raster) <- "stay_total"

# 각 격자의 중심좌표 xcoord, ycoord가 raster의 몇 번째 칸인지 계산
raster_cells <- terra::cellFromXY(
  stay_raster,
  as.matrix(grid_data[, .(xcoord, ycoord)])
)

# 계산된 raster 칸에 체류빈도 값을 입력
stay_raster[raster_cells] <- grid_data$stay_total

# QGIS 등에서도 열 수 있도록 tif 파일로 저장
writeRaster(
  stay_raster,
  out_tif,
  overwrite = TRUE,
  datatype = "INT4S",
  NAflag = -9999
)

# leaflet::addRasterImage는 raster 패키지 형식을 사용하므로 변환
stay_raster_leaflet <- raster::raster(stay_raster)


# 5. VISIT JEJU 여행장소 읽기 ----------------------------------
# 이 파일은 좌표계 x/y가 아니라 위도/경도 컬럼을 가지고 있음

place_data <- fread(place_file, encoding = "UTF-8")

place_data[, lat := as.numeric(위도)]
place_data[, lon := as.numeric(경도)]

# 제주도 주변의 정상 위도/경도만 남김
place_data <- place_data[
  !is.na(lat) & !is.na(lon) &
    lat >= 33.0 & lat <= 33.7 &
    lon >= 126.0 & lon <= 127.2
]

# 팝업에 들어갈 문자를 HTML에서 안전하게 보이도록 처리
clean_text <- function(text_value) {
  text_value <- as.character(text_value)
  text_value[is.na(text_value)] <- ""
  htmltools::htmlEscape(text_value)
}

place_data[, popup := paste0(
  "<b>", clean_text(장소명), "</b><br>",
  "도로명주소: ", clean_text(도로명주소), "<br>",
  "지번주소: ", clean_text(지번주소)
)]

cat("제주 지역 여행장소 핀 수:", nrow(place_data), "\n")


# 6. 지도 범위 계산 --------------------------------------------
# 격자 데이터는 EPSG:5179 좌표계이고,
# leaflet 지도는 위도/경도 좌표계 EPSG:4326을 사용함
# 그래서 지도 화면을 제주도 격자 범위에 맞추기 위해 좌표계를 변환

grid_bbox_5179 <- st_as_sfc(st_bbox(
  c(
    xmin = min(grid_data$left),
    ymin = min(grid_data$bottom),
    xmax = max(grid_data$right),
    ymax = max(grid_data$top)
  ),
  crs = st_crs(5179)
))

grid_bbox_4326 <- st_bbox(st_transform(grid_bbox_5179, 4326))


# 7. Leaflet HTML 지도 만들기 ----------------------------------
# addProviderTiles: 배경지도 추가
# addRasterImage: 체류빈도 raster 추가
# addCircleMarkers: 관광지 핀 추가
# fitBounds: 처음 열었을 때 제주도 전체가 보이도록 화면 범위 지정

jeju_map <- leaflet(
  options = leafletOptions(
    minZoom = 9,
    maxZoom = 21,
    scrollWheelZoom = TRUE,
    preferCanvas = TRUE
  )
) %>%
  addProviderTiles(
    providers$CartoDB.Positron,
    group = "밝은 지도"
  ) %>%
  addProviderTiles(
    providers$Esri.WorldImagery,
    group = "위성지도"
  ) %>%
  addRasterImage(
    stay_raster_leaflet,
    colors = stay_palette,
    opacity = 0.72,
    group = "렌터카 체류빈도 50m 격자",
    project = TRUE,
    method = "ngb",
    maxBytes = Inf
  ) %>%
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
  addLegend(
    position = "bottomright",
    colors = stay_colors,
    labels = stay_labels,
    opacity = 0.72,
    title = "2021년 합산 체류빈도"
  ) %>%
  addScaleBar(
    position = "bottomleft",
    options = scaleBarOptions(metric = TRUE, imperial = FALSE)
  ) %>%
  addLayersControl(
    baseGroups = c("밝은 지도", "위성지도"),
    overlayGroups = c("렌터카 체류빈도 50m 격자", "여행장소 핀"),
    options = layersControlOptions(collapsed = FALSE)
  ) %>%
  fitBounds(
    lng1 = as.numeric(grid_bbox_4326["xmin"]),
    lat1 = as.numeric(grid_bbox_4326["ymin"]),
    lng2 = as.numeric(grid_bbox_4326["xmax"]),
    lat2 = as.numeric(grid_bbox_4326["ymax"])
  )


# 8. HTML 저장 -------------------------------------------------
# selfcontained = TRUE이면 HTML 파일 하나에 지도 구성요소를 최대한 포함해서 저장

htmlwidgets::saveWidget(
  widget = jeju_map,
  file = out_html,
  selfcontained = TRUE,
  title = "제주 렌터카 체류빈도 시각화"
)

# normalizePath로 저장 경로를 윈도우에서도 인식하기 쉬운 형태로 변환
# browseURL로 완성된 HTML 지도를 기본 웹브라우저로 바로 열기
browseURL(normalizePath(out_html, winslash = "/", mustWork = FALSE))

cat("\n완료\n")
cat("HTML 지도:", out_html, "\n")
cat("50m raster:", out_tif, "\n")
