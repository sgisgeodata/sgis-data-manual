# ============================================================
# 제주 렌터카 체류빈도 시각화
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

new_packages <- packages[
  !packages %in% installed.packages()[, "Package"]
]

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

stay_file <- file.path(
  base_dir,
  "체류빈도_2021_합산.csv"
)

place_file <- file.path(
  base_dir,
  "제주관광공사_제주관광정보시스템(VISIT JEJU)_여행장소.csv"
)

out_html <- file.path(
  base_dir,
  "제주_렌터카_체류빈도_시각화.html"
)

out_tif <- file.path(
  base_dir,
  "제주_렌터카_체류빈도_50m.tif"
)

if (!file.exists(stay_file)) {
  stop("체류빈도 파일을 찾을 수 없습니다:\n", stay_file)
}

if (!file.exists(place_file)) {
  stop("여행장소 파일을 찾을 수 없습니다:\n", place_file)
}


# 2. 체류빈도 합산 CSV 읽기 ------------------------------------

grid_data <- fread(
  stay_file,
  encoding = "UTF-8"
)

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

missing_grid_columns <- setdiff(
  required_grid_columns,
  names(grid_data)
)

if (length(missing_grid_columns) > 0) {
  stop(
    "체류빈도 CSV에 다음 열이 없습니다:\n",
    paste(missing_grid_columns, collapse = ", ")
  )
}

grid_data[, j_50_cd := as.character(j_50_cd)]
grid_data[, stay_total := as.numeric(체류빈도_2021)]
grid_data[is.na(stay_total), stay_total := 0]

coordinate_columns <- c(
  "left",
  "right",
  "bottom",
  "top",
  "xcoord",
  "ycoord"
)

grid_data[
  ,
  (coordinate_columns) := lapply(.SD, as.numeric),
  .SDcols = coordinate_columns
]

valid_grid_rows <- complete.cases(
  grid_data[, ..coordinate_columns]
)

invalid_grid_count <- sum(!valid_grid_rows)

if (invalid_grid_count > 0) {
  warning(
    invalid_grid_count,
    "개의 격자에서 좌표 결측값이 발견되어 제외됩니다."
  )
}

grid_data <- grid_data[valid_grid_rows]

if (nrow(grid_data) == 0) {
  stop("사용할 수 있는 격자 데이터가 없습니다.")
}

cat("격자 수:", nrow(grid_data), "\n")
cat(
  "체류빈도 0 초과 격자 수:",
  sum(grid_data$stay_total > 0),
  "\n"
)
cat(
  "최대 체류빈도:",
  max(grid_data$stay_total, na.rm = TRUE),
  "\n"
)


# 3. 체류빈도 구간 및 색상 설정 -------------------------------

stay_labels <- c(
  "0회",
  "1~10회",
  "11~50회",
  "51~100회",
  "101~250회",
  "251회 이상"
)

stay_colors <- c(
  "#fff7bc",
  "#fee391",
  "#fec44f",
  "#fc8d59",
  "#d7301f"
)

grid_data[, stay_class := fcase(
  stay_total == 0,   NA_real_,
  stay_total <= 10,  1,
  stay_total <= 50,  2,
  stay_total <= 100, 3,
  stay_total <= 250, 4,
  default = 5
)]

cat("\n고정 구간:\n")
cat(" - 0회: 투명\n")
cat(" - 1~10회\n")
cat(" - 11~50회\n")
cat(" - 51~100회\n")
cat(" - 101~250회\n")
cat(" - 251회 이상\n")


# 4. 50m 체류빈도 래스터 만들기 -------------------------------

stay_raster <- rast(
  xmin = min(grid_data$left, na.rm = TRUE),
  xmax = max(grid_data$right, na.rm = TRUE),
  ymin = min(grid_data$bottom, na.rm = TRUE),
  ymax = max(grid_data$top, na.rm = TRUE),
  resolution = 50,
  crs = "EPSG:5179"
)

names(stay_raster) <- "stay_class"

raster_cells <- terra::cellFromXY(
  stay_raster,
  as.matrix(
    grid_data[, .(xcoord, ycoord)]
  )
)

valid_raster_cells <- !is.na(raster_cells)

if (sum(!valid_raster_cells) > 0) {
  warning(
    sum(!valid_raster_cells),
    "개의 격자가 래스터 범위를 벗어나 제외됩니다."
  )
}

stay_raster[
  raster_cells[valid_raster_cells]
] <- grid_data$stay_class[valid_raster_cells]

writeRaster(
  stay_raster,
  out_tif,
  overwrite = TRUE,
  datatype = "INT2S",
  NAflag = -9999
)

stay_raster_leaflet <- raster::raster(stay_raster)

stay_palette <- colorFactor(
  palette = stay_colors,
  domain = c(1, 2, 3, 4, 5),
  na.color = "transparent"
)


# 5. VISIT JEJU 여행장소 읽기 ----------------------------------

place_data <- fread(
  place_file,
  encoding = "UTF-8"
)

required_place_columns <- c(
  "장소명",
  "위도",
  "경도",
  "도로명주소",
  "지번주소"
)

missing_place_columns <- setdiff(
  required_place_columns,
  names(place_data)
)

if (length(missing_place_columns) > 0) {
  stop(
    "여행장소 CSV에 다음 열이 없습니다:\n",
    paste(missing_place_columns, collapse = ", ")
  )
}

place_data[, lat := as.numeric(위도)]
place_data[, lon := as.numeric(경도)]

place_data <- place_data[
  !is.na(lat) &
    !is.na(lon) &
    lat >= 33.0 &
    lat <= 33.7 &
    lon >= 126.0 &
    lon <= 127.2
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

cat(
  "제주 지역 여행장소 핀 수:",
  nrow(place_data),
  "\n"
)


# 6. 지도 초기 표시 범위 계산 ----------------------------------

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

grid_bbox_4326 <- st_bbox(
  st_transform(
    grid_bbox_5179,
    4326
  )
)


# 7. 지도 CSS 설정 ---------------------------------------------

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


# 8. 사용자 정의 범례 만들기 -----------------------------------

legend_html <- HTML(
  paste0(
    "<div class='custom-legend'>",
    "<div class='legend-title'>2021년 합산 체류빈도</div>",

    "<div class='legend-row'>",
    "<span class='legend-box' ",
    "style='background:transparent; border:2px dashed #999;'>",
    "</span>",
    stay_labels[1],
    "</div>",

    "<div class='legend-row'>",
    "<span class='legend-box' style='background:",
    stay_colors[1],
    ";'></span>",
    stay_labels[2],
    "</div>",

    "<div class='legend-row'>",
    "<span class='legend-box' style='background:",
    stay_colors[2],
    ";'></span>",
    stay_labels[3],
    "</div>",

    "<div class='legend-row'>",
    "<span class='legend-box' style='background:",
    stay_colors[3],
    ";'></span>",
    stay_labels[4],
    "</div>",

    "<div class='legend-row'>",
    "<span class='legend-box' style='background:",
    stay_colors[4],
    ";'></span>",
    stay_labels[5],
    "</div>",

    "<div class='legend-row'>",
    "<span class='legend-box' style='background:",
    stay_colors[5],
    ";'></span>",
    stay_labels[6],
    "</div>",

    "</div>"
  )
)


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
    options = scaleBarOptions(
      metric = TRUE,
      imperial = FALSE
    )
  ) %>%

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


# 10. HTML 지도 저장 -------------------------------------------

htmlwidgets::saveWidget(
  widget = jeju_map,
  file = out_html,
  selfcontained = TRUE,
  title = "제주 렌터카 체류빈도 시각화"
)

browseURL(
  normalizePath(
    out_html,
    winslash = "/",
    mustWork = FALSE
  )
)

cat("\n분석이 완료되었습니다.\n")
cat("HTML 지도:", out_html, "\n")
cat("50m 체류빈도 래스터:", out_tif, "\n")
