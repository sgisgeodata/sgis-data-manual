# ============================================================
# 제주도 50m 격자 렌터카 체류빈도 2021년 01~12월 합산 HTML 지도 (H 버전)
# - 결과 파일명 뒤에 (H)를 붙여 기존 결과 파일과 충돌하지 않게 저장
# - 체류빈도_2021_01.csv ~ 체류빈도_2021_12.csv 합산
# - 모든 격자를 50m raster로 표시: HTML에서 빠르게 확대/축소 가능
# - 여행장소 CSV를 핀/클러스터로 표시
# - 마우스 휠 확대/축소, 드래그 이동, 레이어 켜기/끄기 가능
# ============================================================

# ------------------------------------------------------------
# 0. 패키지 설치 및 불러오기
# ------------------------------------------------------------

library(data.table)
library(sf)
library(terra)
library(raster)
library(leaflet)
library(htmlwidgets)
library(htmltools)

options(timeout = 300)

# ------------------------------------------------------------
# 1. 경로와 파일명 설정
# ------------------------------------------------------------
base_dir <- "C:/Users/user/Desktop/제주"

months <- sprintf("%02d", 1:12)
stay_files <- file.path(base_dir, paste0("체류빈도_2021_", months, ".csv"))

place_file <- file.path(
  base_dir,
  "제주관광공사_제주관광정보시스템(VISIT JEJU)_여행장소.csv"
)

# 결과 파일명 뒤에 (H)를 붙입니다.
file_suffix <- "(H)"

out_html <- file.path(base_dir, paste0("결과_렌터카_체류빈도_2021_합산_확대축소_HTML지도", file_suffix, ".html"))
out_gpkg <- file.path(base_dir, paste0("결과_렌터카_체류빈도_2021_합산_전체격자_여행장소", file_suffix, ".gpkg"))
out_tif  <- file.path(base_dir, paste0("결과_렌터카_체류빈도_2021_합산_50m_래스터", file_suffix, ".tif"))
out_csv  <- file.path(base_dir, paste0("결과_렌터카_체류빈도_2021_합산_속성표", file_suffix, ".csv"))

# ------------------------------------------------------------
# 2. 실행 옵션
# ------------------------------------------------------------
# 여행장소 파일 안에 김포공항/대구공항 등 제주 밖 좌표가 섞일 수 있어 기본적으로 제주 근처만 남깁니다.
filter_places_to_jeju <- TRUE

# QGIS에서도 열 수 있는 GeoPackage를 저장합니다.
# 시간이 너무 오래 걸리거나 GeoPackage가 필요 없으면 FALSE로 바꿔도 HTML 지도는 만들어집니다.
save_gpkg <- TRUE

# ------------------------------------------------------------
# 3. 기존 (H) 결과 파일 처리 함수
# ------------------------------------------------------------
# 같은 (H) 결과 파일이 이미 있으면 먼저 삭제합니다.
# 단, QGIS/엑셀/브라우저에서 파일이 열려 있으면 Windows에서 삭제가 안 될 수 있습니다.
safe_delete_file <- function(path) {
  if (file.exists(path)) {
    message("기존 파일이 있어서 삭제 후 새로 저장합니다: ", path)
    try(unlink(path, force = TRUE), silent = TRUE)
    
    if (file.exists(path)) {
      stop(
        "기존 결과 파일을 삭제하지 못했습니다.\n",
        "QGIS, 엑셀, 브라우저 등에서 아래 파일을 닫고 다시 실행하세요.\n",
        path
      )
    }
  }
}

# ------------------------------------------------------------
# 4. 입력 파일 확인
# ------------------------------------------------------------
if (!dir.exists(base_dir)) {
  stop("폴더가 없습니다: ", base_dir)
}

missing_stay_files <- stay_files[!file.exists(stay_files)]
if (length(missing_stay_files) > 0) {
  stop(
    "아래 체류빈도 파일이 없습니다. 파일명과 위치를 확인하세요:\n",
    paste(missing_stay_files, collapse = "\n")
  )
}

if (!file.exists(place_file)) {
  stop("여행장소 CSV 파일이 없습니다. 파일명과 위치를 확인하세요:\n", place_file)
}

cat("입력 파일 확인 완료\n")

# ------------------------------------------------------------
# 5. 1월 파일에서 기본 격자 좌표 읽기
# ------------------------------------------------------------
# 체류빈도 CSV 컬럼 구조:
# j_50_cd, left, top, right, bottom, xcoord, ycoord, oid_count
# 좌표계는 EPSG:5179입니다. 위도/경도가 아니라 미터 단위 한국 투영좌표입니다.

grid_cols <- c("j_50_cd", "left", "top", "right", "bottom", "xcoord", "ycoord")

base_grid <- fread(
  stay_files[1],
  encoding = "UTF-8",
  select = grid_cols,
  showProgress = TRUE
)

base_grid[, j_50_cd := as.character(j_50_cd)]
base_grid <- unique(base_grid, by = "j_50_cd")
base_grid[, stay_total := 0]

cat("기본 격자 수:", nrow(base_grid), "\n")

# ------------------------------------------------------------
# 6. 2021년 01~12월 체류빈도 합산
# ------------------------------------------------------------
# oid_count가 비어 있으면 0으로 처리합니다.
# 혹시 1월에는 없고 다른 월에만 있는 격자 코드가 있으면 자동으로 추가합니다.

month_count_cols <- character(0)

for (i in seq_along(stay_files)) {
  m <- months[i]
  f <- stay_files[i]
  
  cat("읽는 중:", basename(f), "\n")
  
  dt <- fread(
    f,
    encoding = "UTF-8",
    select = c("j_50_cd", "oid_count"),
    showProgress = TRUE
  )
  
  dt[, j_50_cd := as.character(j_50_cd)]
  dt[, oid_count := as.numeric(oid_count)]
  dt[is.na(oid_count), oid_count := 0]
  
  # 같은 격자 코드가 여러 번 있으면 월별로 합산
  dt <- dt[, .(month_count = sum(oid_count, na.rm = TRUE)), by = j_50_cd]
  
  # 1월 기본 격자에 없는 코드가 있으면 해당 월 파일에서 좌표를 읽어 추가
  new_ids <- setdiff(dt$j_50_cd, base_grid$j_50_cd)
  if (length(new_ids) > 0) {
    cat("새 격자 코드 추가:", length(new_ids), "개\n")
    
    extra_grid <- fread(
      f,
      encoding = "UTF-8",
      select = grid_cols,
      showProgress = FALSE
    )
    extra_grid[, j_50_cd := as.character(j_50_cd)]
    extra_grid <- unique(extra_grid[j_50_cd %in% new_ids], by = "j_50_cd")
    
    # 이전 월별 컬럼은 0으로 채움
    if (length(month_count_cols) > 0) {
      for (old_col in month_count_cols) {
        extra_grid[, (old_col) := 0]
      }
    }
    extra_grid[, stay_total := 0]
    
    base_grid <- rbindlist(list(base_grid, extra_grid), fill = TRUE)
  }
  
  month_col <- paste0("stay_", m)
  month_count_cols <- c(month_count_cols, month_col)
  
  base_grid[, (month_col) := 0]
  base_grid[dt, (month_col) := i.month_count, on = "j_50_cd"]
  base_grid[, stay_total := stay_total + get(month_col)]
  
  rm(dt)
  gc()
}

cat("12개월 체류빈도 합산 완료\n")
cat("전체 격자 수:", nrow(base_grid), "\n")
cat("합산 체류빈도 0 초과 격자 수:", sum(base_grid$stay_total > 0), "\n")
cat("최대 합산 체류빈도:", max(base_grid$stay_total, na.rm = TRUE), "\n")

# ------------------------------------------------------------
# 7. 단계구분 구간과 색상 설정
# ------------------------------------------------------------
# 모든 격자를 표현하기 위해 0회도 별도 구간으로 둡니다.

max_total <- max(base_grid$stay_total, na.rm = TRUE)
upper_break <- max(1001.5, max_total + 0.5)

breaks_for_color <- c(
  -0.5,
  0.5,
  1.5,
  2.5,
  5.5,
  10.5,
  20.5,
  50.5,
  100.5,
  200.5,
  500.5,
  1000.5,
  upper_break
)

labels_for_color <- c(
  "0회",
  "1회",
  "2회",
  "3-5회",
  "6-10회",
  "11-20회",
  "21-50회",
  "51-100회",
  "101-200회",
  "201-500회",
  "501-1000회",
  "1001회 이상"
)

# 0회는 연회색, 1회 이상은 노랑-빨강 계열
colors_for_color <- c(
  "#f2f2f2",
  grDevices::colorRampPalette(c("#ffffcc", "#ffeda0", "#feb24c", "#f03b20", "#bd0026", "#800026"))(
    length(labels_for_color) - 1
  )
)

base_grid[, stay_class := cut(
  stay_total,
  breaks = breaks_for_color,
  labels = labels_for_color,
  include.lowest = TRUE,
  right = TRUE
)]

pal_fun <- colorBin(
  palette = colors_for_color,
  domain = base_grid$stay_total,
  bins = breaks_for_color,
  na.color = "transparent",
  right = TRUE
)

# ------------------------------------------------------------
# 8. 전체 격자를 50m raster로 만들기
# ------------------------------------------------------------
# HTML에서 70만 개 이상의 사각형 폴리곤을 직접 그리면 매우 느립니다.
# 그래서 모든 격자 값을 50m raster로 바꿔서 지도에 올립니다.
# 해상도는 50m 그대로이므로 확대하면 격자 위치를 확인할 수 있습니다.

r <- rast(
  xmin = min(base_grid$left, na.rm = TRUE),
  xmax = max(base_grid$right, na.rm = TRUE),
  ymin = min(base_grid$bottom, na.rm = TRUE),
  ymax = max(base_grid$top, na.rm = TRUE),
  resolution = 50,
  crs = "EPSG:5179"
)
names(r) <- "stay_total"

xy <- as.matrix(base_grid[, .(xcoord, ycoord)])
cells <- terra::cellFromXY(r, xy)
r[cells] <- base_grid$stay_total

safe_delete_file(out_tif)
writeRaster(
  r,
  out_tif,
  overwrite = TRUE,
  datatype = "INT4S",
  NAflag = -9999
)
cat("50m raster 저장 완료:", out_tif, "\n")

# leaflet::addRasterImage()에서 안정적으로 쓰기 위해 raster 패키지 형식으로 변환합니다.
r_leaflet <- tryCatch({
  raster::raster(r)
}, error = function(e) {
  raster::raster(out_tif)
})

# ------------------------------------------------------------
# 9. 여행장소 CSV 읽기 및 핀용 위경도 정리
# ------------------------------------------------------------
places <- fread(place_file, encoding = "UTF-8", showProgress = TRUE)

need_cols <- c("장소명", "위도", "경도")
if (!all(need_cols %in% names(places))) {
  # Windows 한글 환경에서 인코딩 문제로 컬럼명이 깨질 때를 대비해 한 번 더 시도합니다.
  places <- fread(place_file, encoding = "unknown", showProgress = TRUE)
}

missing_place_cols <- setdiff(need_cols, names(places))
if (length(missing_place_cols) > 0) {
  stop(
    "여행장소 CSV에 필요한 컬럼이 없습니다: ",
    paste(missing_place_cols, collapse = ", "),
    "\n현재 읽힌 컬럼명은 다음과 같습니다:\n",
    paste(names(places), collapse = ", ")
  )
}

places[, lat := as.numeric(`위도`)]
places[, lon := as.numeric(`경도`)]

# 일부 행이 위도/경도 순서가 뒤집힌 경우 자동 보정
swap_idx <- !is.na(places$lat) & !is.na(places$lon) & places$lat > 90 & places$lon < 90
if (any(swap_idx)) {
  tmp_lat <- places$lat[swap_idx]
  places$lat[swap_idx] <- places$lon[swap_idx]
  places$lon[swap_idx] <- tmp_lat
}
places[, coord_note := ifelse(swap_idx, "위경도_순서자동수정", "원본")]

# 전세계 위경도 범위를 벗어나는 이상 좌표 제거
places <- places[
  !is.na(lat) & !is.na(lon) &
    lat >= -90 & lat <= 90 &
    lon >= -180 & lon <= 180
]

# 제주도 근처만 남기기
if (filter_places_to_jeju) {
  places <- places[
    lat >= 33.0 & lat <= 33.7 &
      lon >= 126.0 & lon <= 127.2
  ]
}

cat("여행장소 핀 수:", nrow(places), "\n")
cat("위경도 순서 자동수정 행 수:", sum(places$coord_note == "위경도_순서자동수정"), "\n")

# 팝업 HTML 만들기
clean_text <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  htmltools::htmlEscape(x)
}

# 없는 주소 컬럼이 있을 수도 있으므로 안전하게 처리
if (!"도로명주소" %in% names(places)) places[, `도로명주소` := ""]
if (!"지번주소" %in% names(places)) places[, `지번주소` := ""]
if (!"수정일시" %in% names(places)) places[, `수정일시` := ""]

places[, popup_html := paste0(
  "<b>", clean_text(`장소명`), "</b><br>",
  "도로명주소: ", clean_text(`도로명주소`), "<br>",
  "지번주소: ", clean_text(`지번주소`), "<br>",
  "수정일시: ", clean_text(`수정일시`), "<br>",
  "좌표: ", round(lat, 6), ", ", round(lon, 6), "<br>",
  "좌표확인: ", clean_text(coord_note)
)]

# ------------------------------------------------------------
# 10. QGIS에서도 열 수 있도록 GeoPackage와 속성표 저장
# ------------------------------------------------------------
if (save_gpkg) {
  cat("GeoPackage 저장 준비 중...\n")
  
  # (H) GeoPackage가 이미 있으면 지우고 새로 저장합니다.
  safe_delete_file(out_gpkg)
  
  grid_sf <- st_as_sf(
    base_grid,
    coords = c("left", "bottom", "right", "top"),
    crs = 5179,
    remove = FALSE
  )
  
  places_sf_4326 <- st_as_sf(
    places,
    coords = c("lon", "lat"),
    crs = 4326,
    remove = FALSE
  )
  places_sf_5179 <- st_transform(places_sf_4326, 5179)
  
  # 새 파일명이므로 기존 파일과 충돌하지 않습니다.
  # 그래도 st_write에 append=FALSE를 명시해 레이어 추가 충돌을 방지합니다.
  st_write(
    grid_sf,
    out_gpkg,
    layer = "rentalcar_stay_2021_all_grid_50m_H",
    append = FALSE,
    quiet = FALSE
  )
  
  st_write(
    places_sf_5179,
    out_gpkg,
    layer = "visitjeju_places_pins_H",
    append = FALSE,
    quiet = FALSE
  )
  
  cat("GeoPackage 저장 완료:", out_gpkg, "\n")
  
  fwrite(st_drop_geometry(grid_sf), out_csv, bom = TRUE)
} else {
  fwrite(base_grid, out_csv, bom = TRUE)
}
cat("합산 속성표 CSV 저장 완료:", out_csv, "\n")

# ------------------------------------------------------------
# 11. HTML 지도 범위 계산
# ------------------------------------------------------------
bbox_5179 <- st_as_sfc(st_bbox(
  c(
    xmin = min(base_grid$left, na.rm = TRUE),
    ymin = min(base_grid$bottom, na.rm = TRUE),
    xmax = max(base_grid$right, na.rm = TRUE),
    ymax = max(base_grid$top, na.rm = TRUE)
  ),
  crs = st_crs(5179)
))
bbox_4326 <- st_bbox(st_transform(bbox_5179, 4326))

# ------------------------------------------------------------
# 12. Leaflet HTML 지도 만들기
# ------------------------------------------------------------
# 핵심: scrollWheelZoom = TRUE
# 이 옵션 때문에 HTML에서 마우스 휠로 확대/축소가 됩니다.

m <- leaflet(
  options = leafletOptions(
    minZoom = 9,
    maxZoom = 21,
    zoomControl = TRUE,
    scrollWheelZoom = TRUE,
    wheelPxPerZoomLevel = 60,
    zoomSnap = 0.25,
    zoomDelta = 0.5,
    preferCanvas = TRUE
  )
)

# 배경지도 3종
m <- addProviderTiles(
  m,
  providers$CartoDB.Positron,
  group = "밝은 지도"
)

m <- addProviderTiles(
  m,
  providers$OpenStreetMap,
  group = "OpenStreetMap"
)

m <- addProviderTiles(
  m,
  providers$Esri.WorldImagery,
  group = "위성지도"
)

# 격자 raster 올리기
# method = "ngb"는 nearest neighbor입니다. 체류빈도 같은 구간 값이 중간값으로 흐려지지 않게 합니다.
m <- addRasterImage(
  m,
  r_leaflet,
  colors = pal_fun,
  opacity = 0.72,
  group = "렌터카 체류빈도 50m 격자",
  project = TRUE,
  method = "ngb",
  maxBytes = Inf
)

# 여행장소 핀: 많을 수 있으므로 클러스터로 묶어 표시
m <- addCircleMarkers(
  m,
  data = places,
  lng = ~lon,
  lat = ~lat,
  radius = 5,
  stroke = TRUE,
  color = "#222222",
  weight = 1,
  opacity = 0.9,
  fill = TRUE,
  fillColor = "#2b8cbe",
  fillOpacity = 0.85,
  popup = ~popup_html,
  label = ~`장소명`,
  group = "여행장소 핀",
  clusterOptions = markerClusterOptions()
)

# 범례
m <- addLegend(
  m,
  position = "bottomright",
  colors = colors_for_color,
  labels = labels_for_color,
  opacity = 0.72,
  title = "2021년 합산 체류빈도"
)

# 축척 막대
m <- addScaleBar(
  m,
  position = "bottomleft",
  options = scaleBarOptions(metric = TRUE, imperial = FALSE)
)

# 레이어 켜기/끄기
m <- addLayersControl(
  m,
  baseGroups = c("밝은 지도", "OpenStreetMap", "위성지도"),
  overlayGroups = c("렌터카 체류빈도 50m 격자", "여행장소 핀"),
  options = layersControlOptions(collapsed = FALSE)
)

# 지도 범위를 제주 전체 격자로 맞추기
m <- fitBounds(
  m,
  lng1 = as.numeric(bbox_4326["xmin"]),
  lat1 = as.numeric(bbox_4326["ymin"]),
  lng2 = as.numeric(bbox_4326["xmax"]),
  lat2 = as.numeric(bbox_4326["ymax"])
)

# 사용 안내 박스
note_html <- HTML(paste0(
  "<div style='background:white; padding:8px 10px; border-radius:6px; ",
  "box-shadow:0 1px 5px rgba(0,0,0,0.35); font-size:13px; line-height:1.45;'>",
  "<b>조작 방법</b><br>",
  "마우스 휠: 확대/축소<br>",
  "드래그: 지도 이동<br>",
  "핀 클릭: 여행장소 정보<br>",
  "오른쪽 레이어창: 배경지도/핀 켜기 끄기",
  "</div>"
))

m <- addControl(
  m,
  html = note_html,
  position = "topleft",
  className = "map-note"
)

# HTML 렌더링 후 한 번 더 마우스 휠 확대를 강제로 켜고,
# raster가 확대될 때 격자 픽셀이 흐릿해지지 않도록 CSS 적용
m <- htmlwidgets::onRender(
  m,
  "function(el, x) {
    var map = this;
    if (map.scrollWheelZoom) map.scrollWheelZoom.enable();
    if (map.doubleClickZoom) map.doubleClickZoom.enable();
    if (map.boxZoom) map.boxZoom.enable();
    if (map.touchZoom) map.touchZoom.enable();

    var css = '.leaflet-image-layer { image-rendering: pixelated; image-rendering: crisp-edges; }';
    var style = document.createElement('style');
    style.type = 'text/css';
    style.appendChild(document.createTextNode(css));
    document.head.appendChild(style);
  }"
)

# ------------------------------------------------------------
# 13. HTML 저장
# ------------------------------------------------------------
# selfcontained = TRUE는 HTML 하나로 묶습니다.
# 일부 PC에서 pandoc 문제로 실패하면 자동으로 selfcontained = FALSE로 다시 저장합니다.

cat("HTML 지도 저장 중...\n")

tryCatch({
  htmlwidgets::saveWidget(
    widget = m,
    file = out_html,
    selfcontained = TRUE,
    title = "제주도 렌터카 체류빈도 2021년 합산 HTML 지도 (H)"
  )
  cat("HTML 지도 저장 완료:", out_html, "\n")
}, error = function(e) {
  message("selfcontained=TRUE 저장 실패: ", e$message)
  message("부속 파일 폴더를 함께 만드는 방식으로 다시 저장합니다.")
  
  htmlwidgets::saveWidget(
    widget = m,
    file = out_html,
    selfcontained = FALSE,
    libdir = paste0(tools::file_path_sans_ext(basename(out_html)), "_files"),
    title = "제주도 렌터카 체류빈도 2021년 합산 HTML 지도 (H)"
  )
  cat("HTML 지도 저장 완료:", out_html, "\n")
})

# 저장 후 자동으로 브라우저에서 열기
browseURL(normalizePath(out_html, winslash = "/", mustWork = FALSE))

cat("\n================ 완료 ================\n")
cat("HTML 지도:\n  ", out_html, "\n", sep = "")
cat("50m raster:\n  ", out_tif, "\n", sep = "")
cat("합산 속성표 CSV:\n  ", out_csv, "\n", sep = "")
if (save_gpkg) {
  cat("QGIS용 GeoPackage:\n  ", out_gpkg, "\n", sep = "")
}
cat("======================================\n")