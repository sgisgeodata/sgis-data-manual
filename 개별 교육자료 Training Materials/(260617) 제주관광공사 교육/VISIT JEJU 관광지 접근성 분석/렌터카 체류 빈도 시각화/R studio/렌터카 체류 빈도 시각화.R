# ============================================================
# 제주 렌터카 체류빈도 시각화
#
# 1. 2021년 합산 체류빈도 CSV를 불러와 50m 격자별 체류빈도를 정리한다.
# 2. VISIT JEJU 여행장소 CSV의 위도/경도 정보를 이용해 관광지 위치를 준비한다.
# 3. 체류빈도 격자와 관광지 핀을 함께 표시한 확대/축소 가능한 HTML 지도를 만든다.
# ============================================================

# 0. 패키지 설치 및 불러오기 -----------------------------------

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
library(magrittr)


# 1. 경로 설정 -------------------------------------------------

base_dir <- "C:/Users/user/Desktop/제주"

stay_file <- file.path(base_dir, "체류빈도_2021_합산.csv")
place_file <- file.path(
  base_dir,
  "제주관광공사_제주관광정보시스템(VISIT JEJU)_여행장소.csv"
)

out_html <- file.path(base_dir, "제주_렌터카_체류빈도_시각화.html")
out_tif  <- file.path(base_dir, "제주_렌터카_체류빈도_50m.tif")


# 2. 체류빈도 합산 CSV 읽기 ------------------------------------

grid_data <- fread(stay_file, encoding = "UTF-8")

grid_data[, j_50_cd := as.character(j_50_cd)]
grid_data[, stay_total := as.numeric(체류빈도_2021)]
grid_data[is.na(stay_total), stay_total := 0]

cat("격자 수:", nrow(grid_data), "\n")
cat("체류빈도 0 초과 격자 수:", sum(grid_data$stay_total > 0), "\n")
cat("최대 체류빈도:", max(grid_data$stay_total, na.rm = TRUE), "\n")


# 3. 색상 구간 설정 --------------------------------------------

stay_breaks <- c(0, 10, 25, 50, 100, Inf)

stay_labels <- c(
  "0회",
  "~10회",
  "~25회",
  "~50회",
  "~1000회",
  "100회 이상"
)

# 양수 5단계용 색상
stay_colors <- c(
  "#fff7bc",
  "#fee391",
  "#fec44f",
  "#fc8d59",
  "#d7301f"
)

# 0은 NA 처리하고, 양수만 단계값으로 변환
grid_data[, stay_class := fifelse(
  stay_total == 0, NA_real_,
  fifelse(stay_total <= 10, 1,
          fifelse(stay_total <= 50, 2,
                  fifelse(stay_total <= 100, 3,
                          fifelse(stay_total <= 250, 4, 5)
                  )
          )
  )
)]

cat("\n고정 구간:\n")
cat(" - 0회 (투명)\n")
cat(" - 1~10회\n")
cat(" - 11~25회\n")
cat(" - 26~50회\n")
cat(" - 51~100회\n")
cat(" - 100회 이상\n")


# 4. 50m 래스터 만들기 -----------------------------------------

stay_raster <- rast(
  xmin = min(grid_data$left),
  xmax = max(grid_data$right),
  ymin = min(grid_data$bottom),
  ymax = max(grid_data$top),
  resolution = 50,
  crs = "EPSG:5179"
)

names(stay_raster) <- "stay_class"

raster_cells <- terra::cellFromXY(
  stay_raster,
  as.matrix(grid_data[, .(xcoord, ycoord)])
)

stay_raster[raster_cells] <- grid_data$stay_class

# 0회는 이미 NA라서 실제로 그려지지 않음 = 진짜 투명
writeRaster(
  stay_raster,
  out_tif,
  overwrite = TRUE,
  datatype = "INT2S",
  NAflag = -9999
)

stay_raster_leaflet <- raster::raster(stay_raster)

# class 값 1~5를 색으로 연결
stay_palette <- colorFactor(
  palette = stay_colors,
  domain = c(1, 2, 3, 4, 5),
  na.color = "transparent"
)


# 5. VISIT JEJU 여행장소 읽기 ----------------------------------

place_data <- fread(place_file, encoding = "UTF-8")

place_data[, lat := as.numeric(위도)]
place_data[, lon := as.numeric(경도)]

place_data <- place_data[
  !is.na(lat) & !is.na(lon) &
    lat >= 33.0 & lat <= 33.7 &
    lon >= 126.0 & lon <= 127.2
]

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


# 7. 큰 범례/레이어 선택창 CSS ---------------------------------

map_css <- HTML("
  .leaflet-control-layers {
    font-size: 20px !important;
    line-height: 1.6 !important;
    padding: 12px 14px !important;
    border-radius: 12px !important;
    background: rgba(255,255,255,0.96) !important;
  }

  .leaflet-control-layers-expanded {
    min-width: 270px !important;
  }

  .leaflet-control-layers label {
    display: block !important;
    padding: 7px 0 !important;
    margin: 0 !important;
  }

  .leaflet-control-layers-selector {
    transform: scale(1.5);
    margin-right: 10px !important;
  }

  .leaflet-touch .leaflet-control-layers-toggle {
    width: 48px !important;
    height: 48px !important;
    background-size: 28px 28px !important;
  }

  .leaflet-control-zoom a {
    width: 42px !important;
    height: 42px !important;
    line-height: 42px !important;
    font-size: 24px !important;
  }

  .custom-legend {
    background: rgba(255,255,255,0.96);
    padding: 14px 16px;
    border-radius: 12px;
    box-shadow: 0 1px 5px rgba(0,0,0,0.3);
    font-size: 18px;
    line-height: 1.8;
    color: #333;
  }

  .custom-legend .legend-title {
    font-weight: 700;
    margin-bottom: 8px;
    font-size: 20px;
  }

  .custom-legend .legend-row {
    display: flex;
    align-items: center;
    margin-bottom: 4px;
  }

  .custom-legend .legend-box {
    width: 24px;
    height: 24px;
    margin-right: 10px;
    border: 1px solid #777;
    box-sizing: border-box;
  }

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


# 8. 사용자 정의 범례 HTML -------------------------------------

legend_html <- HTML(paste0(
  "<div class='custom-legend'>",
  "<div class='legend-title'>2021년 합산 체류빈도</div>",
  
  # 0회는 '투명'을 보여주기 위해 흰색 박스 + 점선 테두리
  "<div class='legend-row'><span class='legend-box' style='background: transparent; border: 2px dashed #999;'></span>0회</div>",
  
  "<div class='legend-row'><span class='legend-box' style='background:", stay_colors[1], ";'></span>~10회</div>",
  "<div class='legend-row'><span class='legend-box' style='background:", stay_colors[2], ";'></span>~50회</div>",
  "<div class='legend-row'><span class='legend-box' style='background:", stay_colors[3], ";'></span>~100회</div>",
  "<div class='legend-row'><span class='legend-box' style='background:", stay_colors[4], ";'></span>~250회</div>",
  "<div class='legend-row'><span class='legend-box' style='background:", stay_colors[5], ";'></span>251회 이상</div>",
  "</div>"
))


# 9. Leaflet HTML 지도 만들기 ----------------------------------

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
    opacity = 0.7,
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
  addControl(
    html = legend_html,
    position = "bottomright"
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
  ) %>%
  prependContent(
    tags$head(
      tags$style(map_css)
    )
  )


# 10. HTML 저장 ------------------------------------------------

htmlwidgets::saveWidget(
  widget = jeju_map,
  file = out_html,
  selfcontained = TRUE,
  title = "제주 렌터카 체류빈도 시각화"
)

browseURL(normalizePath(out_html, winslash = "/", mustWork = FALSE))

cat("\n완료\n")
cat("HTML 지도:", out_html, "\n")
cat("50m raster:", out_tif, "\n")