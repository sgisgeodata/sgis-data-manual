# ============================================================
# 제주도 렌터카 체류빈도 2021 합산 CSV + VISIT JEJU 관광지 HTML 지도
# - 체류빈도_2021_합산.csv 사용
# - VISIT JEJU 여행장소는 위도/경도 컬럼 사용
# - 파일명 충돌 방지 코드 제거
# - 핵심 기능만 유지
# ============================================================

library(data.table)
library(terra)
library(raster)
library(sf)
library(leaflet)
library(htmlwidgets)
library(htmltools)

# 1. 경로 설정 -------------------------------------------------

base_dir <- "C:/Users/user/Desktop/제주"

stay_file <- file.path(base_dir, "체류빈도_2021_합산.csv")

place_file <- file.path(
  base_dir,
  "제주관광공사_제주관광정보시스템(VISIT JEJU)_여행장소.csv"
)

out_html <- file.path(base_dir, "결과_렌터카_체류빈도_2021_합산_HTML지도.html")
out_tif  <- file.path(base_dir, "결과_렌터카_체류빈도_2021_합산_50m_래스터.tif")


# 2. 체류빈도 합산 CSV 읽기 ------------------------------------

grid <- fread(stay_file, encoding = "UTF-8")

grid[, j_50_cd := as.character(j_50_cd)]
grid[, stay_total := as.numeric(체류빈도_2021)]
grid[is.na(stay_total), stay_total := 0]

cat("격자 수:", nrow(grid), "\n")
cat("체류빈도 0 초과 격자 수:", sum(grid$stay_total > 0), "\n")
cat("최대 체류빈도:", max(grid$stay_total), "\n")


# 3. 색상 구간 설정 --------------------------------------------

breaks <- c(
  -0.5, 0.5, 1.5, 2.5, 5.5, 10.5, 20.5,
  50.5, 100.5, 200.5, 500.5, 1000.5,
  max(1001.5, max(grid$stay_total) + 0.5)
)

labels <- c(
  "0회", "1회", "2회", "3-5회", "6-10회", "11-20회",
  "21-50회", "51-100회", "101-200회", "201-500회",
  "501-1000회", "1001회 이상"
)

colors <- c(
  "#f2f2f2",
  grDevices::colorRampPalette(
    c("#ffffcc", "#ffeda0", "#feb24c", "#f03b20", "#bd0026", "#800026")
  )(length(labels) - 1)
)

pal <- colorBin(
  palette = colors,
  domain = grid$stay_total,
  bins = breaks,
  na.color = "transparent"
)


# 4. 50m 래스터 만들기 -----------------------------------------

r <- rast(
  xmin = min(grid$left),
  xmax = max(grid$right),
  ymin = min(grid$bottom),
  ymax = max(grid$top),
  resolution = 50,
  crs = "EPSG:5179"
)

names(r) <- "stay_total"

cells <- terra::cellFromXY(
  r,
  as.matrix(grid[, .(xcoord, ycoord)])
)

r[cells] <- grid$stay_total

writeRaster(
  r,
  out_tif,
  overwrite = TRUE,
  datatype = "INT4S",
  NAflag = -9999
)

r_leaflet <- raster::raster(r)


# 5. VISIT JEJU 여행장소 읽기 ----------------------------------
# 확인 결과 이 파일은 x/y 좌표가 아니라 위도/경도 컬럼임

places <- fread(place_file, encoding = "UTF-8")

places[, lat := as.numeric(위도)]
places[, lon := as.numeric(경도)]

places <- places[
  !is.na(lat) & !is.na(lon) &
    lat >= 33.0 & lat <= 33.7 &
    lon >= 126.0 & lon <= 127.2
]

clean_text <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  htmltools::htmlEscape(x)
}

places[, popup := paste0(
  "<b>", clean_text(장소명), "</b><br>",
  "도로명주소: ", clean_text(도로명주소), "<br>",
  "지번주소: ", clean_text(지번주소)
)]

cat("제주 지역 여행장소 핀 수:", nrow(places), "\n")


# 6. 지도 범위 계산 --------------------------------------------

bbox_5179 <- st_as_sfc(st_bbox(
  c(
    xmin = min(grid$left),
    ymin = min(grid$bottom),
    xmax = max(grid$right),
    ymax = max(grid$top)
  ),
  crs = st_crs(5179)
))

bbox_4326 <- st_bbox(st_transform(bbox_5179, 4326))


# 7. Leaflet HTML 지도 만들기 ----------------------------------

m <- leaflet(
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
    r_leaflet,
    colors = pal,
    opacity = 0.72,
    group = "렌터카 체류빈도 50m 격자",
    project = TRUE,
    method = "ngb",
    maxBytes = Inf
  ) %>%
  addCircleMarkers(
    data = places,
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
    colors = colors,
    labels = labels,
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
    lng1 = as.numeric(bbox_4326["xmin"]),
    lat1 = as.numeric(bbox_4326["ymin"]),
    lng2 = as.numeric(bbox_4326["xmax"]),
    lat2 = as.numeric(bbox_4326["ymax"])
  )


# 8. HTML 저장 -------------------------------------------------

htmlwidgets::saveWidget(
  widget = m,
  file = out_html,
  selfcontained = TRUE,
  title = "제주도 렌터카 체류빈도 2021년 합산 HTML 지도"
)

browseURL(normalizePath(out_html, winslash = "/", mustWork = FALSE))

cat("\n완료\n")
cat("HTML 지도:", out_html, "\n")
cat("50m raster:", out_tif, "\n")