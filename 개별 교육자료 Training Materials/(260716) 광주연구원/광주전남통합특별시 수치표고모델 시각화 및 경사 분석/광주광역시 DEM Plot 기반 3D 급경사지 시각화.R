# ============================================================
# 광주광역시 90m DEM 기반 3D 지형 및 급경사지 시각화
#
# 목표
#
# - 광주광역시 경계에 맞춰 DEM을 가공하고, 지형의 고저 차이를 3D로 표현한다.
# - 배경지도 위에 입체 지형을 중첩하여 광주 내 산지·고지대 분포를 직관적으로 확인한다.
# - 급경사지의 하향 흐름 방향을 화살표로 표시하여 경사 이동 방향을 시각화한다.
# - 배경지도, 지형 표현 방식, 화살표 표시 기준을 선택할 수 있는 HTML 지도를 제작한다.
# ============================================================


# 0. 패키지 설치 및 불러오기 ---------------------------------

packages <- c(
  "terra",
  "sf",
  "dplyr",
  "jsonlite",
  "htmltools"
)

new_packages <- packages[!(packages %in% installed.packages()[, "Package"])]

if (length(new_packages) > 0) {
  install.packages(new_packages)
}

library(terra)
library(sf)
library(dplyr)
library(jsonlite)
library(htmltools)


# 1. 경로 설정 -------------------------------------------------

base_dir <- "C:/Users/user/Desktop/R/데이터"

dem_file <- file.path(base_dir, "한반도90m_GRS80.img")
sigungu_file <- file.path(base_dir, "bnd_sigungu_00_2025_2Q.shp")

output_html <- file.path(base_dir, "광주광역시 DEM Plot 기반 3D 급경사지 시각화.html")
temp_geojson <- file.path(base_dir, "temp_gwangju_dem_3d.geojson")


# 2. 시각화 옵션 -----------------------------------------------

# 높이 과장값
z_exaggeration <- 3.5

# 3D 지형 표현용 DEM 셀 수 제한
target_cells <- 12000

# 화살표 최소 후보 기준
# HTML 버튼에서 15/20/25/30을 선택할 수 있도록 최소 후보는 15도 이상으로 생성
arrow_min_degree <- 15

# 화살촉 크기
arrow_head_length_meter <- 32
arrow_head_width_meter <- 22

# 화살표를 윗면에 거의 붙이기 위한 높이 보정
arrow_lift <- 4

# 경계선이 DEM에 묻히지 않도록 띄우는 높이
boundary_lift <- 220


# 3. 데이터 불러오기 -------------------------------------------

dem <- rast(dem_file)

sigungu <- st_read(
  sigungu_file,
  options = "ENCODING=CP949",
  quiet = TRUE
)

cat("DEM CRS:\n")
print(crs(dem))

cat("시군구 컬럼명:\n")
print(names(sigungu))


# 4. 광주광역시 5개 구 추출 ------------------------------------

# bnd_sigungu_00_2025_2Q 기준
# 24010 동구, 24020 서구, 24030 남구, 24040 북구, 24050 광산구

gwangju <- sigungu %>%
  mutate(SIGUNGU_CD = as.character(SIGUNGU_CD)) %>%
  filter(SIGUNGU_CD %in% c("24010", "24020", "24030", "24040", "24050"))

if (nrow(gwangju) == 0) {
  stop("SIGUNGU_CD 기준으로 광주광역시 경계를 찾지 못했습니다.")
}

cat("선택된 광주광역시 구 목록:\n")
print(gwangju %>% st_drop_geometry() %>% select(SIGUNGU_CD, SIGUNGU_NM))

gwangju <- gwangju %>%
  st_make_valid() %>%
  st_transform(crs(dem))

gwangju_vect <- vect(gwangju)


# 5. DEM 자르기 -------------------------------------------------

dem_gwangju <- dem %>%
  crop(gwangju_vect) %>%
  mask(gwangju_vect)

dem_gwangju[dem_gwangju < -100] <- NA


# 6. DEM 해상도 조정 -------------------------------------------

# 중요:
# 화면에 보이는 3D 블록과 화살표 기준을 일치시키기 위해
# dem_plot 기준으로 화살표도 계산한다.

if (ncell(dem_gwangju) > target_cells) {
  fact_value <- ceiling(sqrt(ncell(dem_gwangju) / target_cells))
  dem_plot <- aggregate(
    dem_gwangju,
    fact = fact_value,
    fun = mean,
    na.rm = TRUE
  )
} else {
  dem_plot <- dem_gwangju
}

names(dem_plot) <- "elev"

cat("3D 표시용 DEM 셀 수:", ncell(dem_plot), "\n")


# 7. DEM을 3D 폴리곤 GeoJSON으로 변환 --------------------------

dem_poly <- as.polygons(
  dem_plot,
  dissolve = FALSE,
  na.rm = TRUE
)

names(dem_poly) <- "elev"

dem_poly_sf <- st_as_sf(dem_poly)

dem_poly_sf <- dem_poly_sf %>%
  filter(!is.na(elev)) %>%
  mutate(
    elev = round(elev, 1),
    height = round(elev * z_exaggeration, 1)
  ) %>%
  st_transform(4326)

if (file.exists(temp_geojson)) {
  file.remove(temp_geojson)
}

st_write(
  dem_poly_sf,
  temp_geojson,
  driver = "GeoJSON",
  quiet = TRUE
)

dem_geojson_text <- paste(readLines(temp_geojson, encoding = "UTF-8"), collapse = "\n")


# 8. 셀 기반 급경사 화살표 계산 --------------------------------

dem_matrix <- as.matrix(dem_plot, wide = TRUE)

nr <- nrow(dem_matrix)
nc <- ncol(dem_matrix)

res_x <- res(dem_plot)[1]
res_y <- res(dem_plot)[2]

xmin_dem <- xmin(dem_plot)
ymax_dem <- ymax(dem_plot)

cell_center_x <- function(col) {
  xmin_dem + (col - 0.5) * res_x
}

cell_center_y <- function(row) {
  ymax_dem - (row - 0.5) * res_y
}

neighbor_dirs <- expand.grid(
  dr = c(-1, 0, 1),
  dc = c(-1, 0, 1)
) %>%
  filter(!(dr == 0 & dc == 0))

arrow_records <- list()

for (r in seq_len(nr)) {
  
  for (c in seq_len(nc)) {
    
    elev_a <- dem_matrix[r, c]
    
    if (is.na(elev_a)) {
      next
    }
    
    x_a <- cell_center_x(c)
    y_a <- cell_center_y(r)
    
    best_slope <- -Inf
    best_info <- NULL
    
    for (k in seq_len(nrow(neighbor_dirs))) {
      
      dr <- neighbor_dirs$dr[k]
      dc <- neighbor_dirs$dc[k]
      
      rb <- r + dr
      cb <- c + dc
      
      if (rb < 1 || rb > nr || cb < 1 || cb > nc) {
        next
      }
      
      elev_b <- dem_matrix[rb, cb]
      
      if (is.na(elev_b)) {
        next
      }
      
      elev_diff <- elev_a - elev_b
      
      if (elev_diff <= 0) {
        next
      }
      
      dist_xy <- sqrt((dc * res_x)^2 + (dr * res_y)^2)
      slope_deg <- atan(elev_diff / dist_xy) * 180 / pi
      
      if (slope_deg > best_slope) {
        best_slope <- slope_deg
        
        best_info <- list(
          rb = rb,
          cb = cb,
          dr = dr,
          dc = dc,
          elev_b = elev_b,
          x_b = cell_center_x(cb),
          y_b = cell_center_y(rb),
          slope_deg = slope_deg
        )
      }
    }
    
    if (is.null(best_info)) {
      next
    }
    
    if (best_info$slope_deg < arrow_min_degree) {
      next
    }
    
    dr_best <- best_info$dr
    dc_best <- best_info$dc
    
    sign_x <- sign(dc_best)
    sign_y <- -sign(dr_best)
    
    # 시작점 계산
    # 선 접촉: A의 B쪽 윗면 모서리 중심
    # 점 접촉: A의 B쪽 윗면 꼭짓점
    if (abs(dc_best) + abs(dr_best) == 1) {
      if (dc_best != 0) {
        x_start <- x_a + sign_x * res_x / 2
        y_start <- y_a
      } else {
        x_start <- x_a
        y_start <- y_a + sign_y * res_y / 2
      }
    } else {
      x_start <- x_a + sign_x * res_x / 2
      y_start <- y_a + sign_y * res_y / 2
    }
    
    x_tip <- best_info$x_b
    y_tip <- best_info$y_b
    
    z_start <- elev_a * z_exaggeration + arrow_lift
    z_tip <- best_info$elev_b * z_exaggeration + arrow_lift
    
    dx <- x_tip - x_start
    dy <- y_tip - y_start
    
    len_xy <- sqrt(dx^2 + dy^2)
    
    if (len_xy == 0) {
      next
    }
    
    unit_x <- dx / len_xy
    unit_y <- dy / len_xy
    
    head_len <- min(arrow_head_length_meter, len_xy * 0.35)
    head_wid <- min(arrow_head_width_meter, len_xy * 0.28)
    
    x_head_base <- x_tip - unit_x * head_len
    y_head_base <- y_tip - unit_y * head_len
    
    base_ratio <- sqrt((x_head_base - x_start)^2 + (y_head_base - y_start)^2) / len_xy
    z_head_base <- z_start + (z_tip - z_start) * base_ratio
    
    x_shaft_end <- x_head_base
    y_shaft_end <- y_head_base
    z_shaft_end <- z_head_base
    
    perp_x <- -unit_y
    perp_y <- unit_x
    
    x_head_left <- x_head_base + perp_x * head_wid / 2
    y_head_left <- y_head_base + perp_y * head_wid / 2
    
    x_head_right <- x_head_base - perp_x * head_wid / 2
    y_head_right <- y_head_base - perp_y * head_wid / 2
    
    arrow_records[[length(arrow_records) + 1]] <- data.frame(
      a_row = r,
      a_col = c,
      b_row = best_info$rb,
      b_col = best_info$cb,
      slope = round(best_info$slope_deg, 1),
      
      x_start = x_start,
      y_start = y_start,
      z_start = z_start,
      
      x_shaft_end = x_shaft_end,
      y_shaft_end = y_shaft_end,
      z_shaft_end = z_shaft_end,
      
      x_tip = x_tip,
      y_tip = y_tip,
      z_tip = z_tip,
      
      x_head_left = x_head_left,
      y_head_left = y_head_left,
      z_head_left = z_head_base,
      
      x_head_right = x_head_right,
      y_head_right = y_head_right,
      z_head_right = z_head_base
    )
  }
}

if (length(arrow_records) == 0) {
  stop("화살표 후보가 없습니다. arrow_min_degree 값을 낮춰 주세요.")
}

arrow_df <- bind_rows(arrow_records)

# 정확한 중복 제거:
# 시작점과 도착점이 완전히 같은 동일 화살표만 제거
arrow_df <- arrow_df %>%
  mutate(
    arrow_key = paste(
      round(x_start, 3),
      round(y_start, 3),
      round(x_tip, 3),
      round(y_tip, 3),
      sep = "_"
    )
  ) %>%
  distinct(arrow_key, .keep_all = TRUE) %>%
  select(-arrow_key)

cat("화살표 후보 전체 개수:", nrow(arrow_df), "개\n")


# 8-1. 화살표 좌표를 위경도로 변환 -------------------------------

make_point_4326 <- function(x, y) {
  temp_sf <- st_as_sf(
    data.frame(x = x, y = y),
    coords = c("x", "y"),
    crs = crs(dem_plot)
  )
  
  temp_4326 <- st_transform(temp_sf, 4326)
  st_coordinates(temp_4326)
}

start_xy <- make_point_4326(arrow_df$x_start, arrow_df$y_start)
shaft_end_xy <- make_point_4326(arrow_df$x_shaft_end, arrow_df$y_shaft_end)
tip_xy <- make_point_4326(arrow_df$x_tip, arrow_df$y_tip)
head_left_xy <- make_point_4326(arrow_df$x_head_left, arrow_df$y_head_left)
head_right_xy <- make_point_4326(arrow_df$x_head_right, arrow_df$y_head_right)


# 8-2. 화살표 몸통 데이터 생성 ---------------------------------

arrow_data <- lapply(seq_len(nrow(arrow_df)), function(i) {
  list(
    path = list(
      list(start_xy[i, 1], start_xy[i, 2], arrow_df$z_start[i]),
      list(shaft_end_xy[i, 1], shaft_end_xy[i, 2], arrow_df$z_shaft_end[i])
    ),
    slope = arrow_df$slope[i]
  )
})

arrow_json <- toJSON(arrow_data, auto_unbox = TRUE, digits = 8)


# 8-3. 3D 화살촉 데이터 생성 -----------------------------------

arrow_head_path_data <- list()

for (i in seq_len(nrow(arrow_df))) {
  
  arrow_head_path_data[[length(arrow_head_path_data) + 1]] <- list(
    path = list(
      list(head_left_xy[i, 1], head_left_xy[i, 2], arrow_df$z_head_left[i]),
      list(tip_xy[i, 1], tip_xy[i, 2], arrow_df$z_tip[i])
    ),
    slope = arrow_df$slope[i]
  )
  
  arrow_head_path_data[[length(arrow_head_path_data) + 1]] <- list(
    path = list(
      list(head_right_xy[i, 1], head_right_xy[i, 2], arrow_df$z_head_right[i]),
      list(tip_xy[i, 1], tip_xy[i, 2], arrow_df$z_tip[i])
    ),
    slope = arrow_df$slope[i]
  )
}

arrow_head_json <- toJSON(arrow_head_path_data, auto_unbox = TRUE, digits = 8)


# 9. 구 경계 데이터 --------------------------------------------

gwangju_4326 <- st_transform(gwangju, 4326)

gwangju_boundary <- st_cast(gwangju, "MULTILINESTRING", warn = FALSE)

boundary_data <- list()

for (i in seq_len(nrow(gwangju_boundary))) {
  
  line_coords <- st_coordinates(gwangju_boundary[i, ])
  
  boundary_pts <- st_as_sf(
    data.frame(
      x = line_coords[, "X"],
      y = line_coords[, "Y"]
    ),
    coords = c("x", "y"),
    crs = crs(dem_gwangju)
  )
  
  elev_vals <- terra::extract(dem_gwangju, vect(boundary_pts))[, 2]
  
  z_vals <- elev_vals * z_exaggeration + boundary_lift
  
  mean_elev <- global(dem_gwangju, mean, na.rm = TRUE)[1, 1]
  z_vals[is.na(z_vals)] <- mean_elev * z_exaggeration + boundary_lift
  
  boundary_pts_4326 <- st_transform(boundary_pts, 4326)
  boundary_xy_4326 <- st_coordinates(boundary_pts_4326)
  
  boundary_data[[i]] <- list(
    name = gwangju$SIGUNGU_NM[i],
    path = lapply(seq_len(nrow(boundary_xy_4326)), function(j) {
      list(
        boundary_xy_4326[j, "X"],
        boundary_xy_4326[j, "Y"],
        z_vals[j]
      )
    })
  )
}

boundary_json <- toJSON(boundary_data, auto_unbox = TRUE, digits = 8)


# 지도 중심점 ---------------------------------------------------

center <- st_centroid(st_union(gwangju_4326))
center_xy <- st_coordinates(center)

center_lon <- center_xy[1, 1]
center_lat <- center_xy[1, 2]


# 10. HTML 생성 -------------------------------------------------

html_code <- paste0(
  '<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8"/>
<title>광주광역시 DEM 3D 지도</title>

<script src="https://unpkg.com/deck.gl@8.9.35/dist.min.js"></script>

<style>
  html, body {
    margin: 0;
    padding: 0;
    width: 100%;
    height: 100%;
    overflow: hidden;
    font-family: "Malgun Gothic", "Apple SD Gothic Neo", Arial, sans-serif;
    background: #f5f5f5;
  }

  #title {
    position: absolute;
    top: 12px;
    left: 50%;
    transform: translateX(-50%);
    z-index: 20;
    background: rgba(255, 255, 255, 0.92);
    padding: 12px 28px;
    border-radius: 16px;
    font-size: 28px;
    font-weight: 800;
    color: #111;
    box-shadow: 0 4px 14px rgba(0,0,0,0.18);
    text-align: center;
    white-space: nowrap;
  }

  #subtitle {
    font-size: 14px;
    font-weight: 500;
    color: #444;
    margin-top: 4px;
  }

  #map {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
  }

  #controls {
    position: absolute;
    top: 92px;
    right: 18px;
    z-index: 30;
    background: rgba(255,255,255,0.94);
    border-radius: 14px;
    padding: 12px;
    box-shadow: 0 4px 14px rgba(0,0,0,0.2);
    width: 210px;
  }

  .control-title {
    font-size: 13px;
    font-weight: 800;
    margin: 8px 0 6px 0;
    color: #222;
  }

  button {
    width: 100%;
    margin: 3px 0;
    padding: 8px 10px;
    border: 1px solid #bbb;
    border-radius: 8px;
    background: white;
    cursor: pointer;
    font-family: "Malgun Gothic", "Apple SD Gothic Neo", Arial, sans-serif;
    font-size: 13px;
    font-weight: 600;
  }

  button:hover {
    background: #f0f0f0;
  }

  button.active {
    background: #222;
    color: white;
    border-color: #222;
  }
</style>
</head>

<body>

<div id="map"></div>

<div id="title">
  광주광역시 90m DEM 기반 3D 지형 및 급경사지 분석
  <div id="subtitle">높은 셀 A의 윗면 경계에서 낮은 셀 B의 윗면 중심으로 하향 경사 방향 표시</div>
</div>

<div id="controls">
  <div class="control-title">배경지도</div>
  <button id="base-light" class="active" onclick="setBaseMap(\'light\')">백지도</button>
  <button id="base-satellite" onclick="setBaseMap(\'satellite\')">위성지도</button>
  <button id="base-dark" onclick="setBaseMap(\'dark\')">어두운지도</button>

  <div class="control-title">DEM 표현</div>
  <button id="terrain-color" class="active" onclick="setTerrainMode(\'color\')">다색 지형</button>
  <button id="terrain-gray" onclick="setTerrainMode(\'gray\')">회색 단색</button>

  <div class="control-title">화살표 범위</div>
  <button id="arrow-none" onclick="setArrowDegree(null)">화살표 없음</button>
  <button id="arrow-15" class="active" onclick="setArrowDegree(15)">15도 이상</button>
  <button id="arrow-20" onclick="setArrowDegree(20)">20도 이상</button>
  <button id="arrow-25" onclick="setArrowDegree(25)">25도 이상</button>
  <button id="arrow-30" onclick="setArrowDegree(30)">30도 이상</button>
</div>

<script>

const demGeojson = ', dem_geojson_text, ';

const arrowData = ', arrow_json, ';

const arrowHeadData = ', arrow_head_json, ';

const boundaryData = ', boundary_json, ';

let baseMode = "light";
let terrainMode = "color";

let arrowDegreeMode = 15;

const INITIAL_VIEW_STATE = {
  longitude: ', center_lon, ',
  latitude: ', center_lat, ',
  zoom: 10.3,
  pitch: 58,
  bearing: -18,
  maxPitch: 85,
  minPitch: 0
};

const MAPS = {
  light: {
    url: "https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png",
    attribution: "CARTO"
  },
  dark: {
    url: "https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png",
    attribution: "CARTO"
  },
  satellite: {
    url: "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
    attribution: "Esri"
  }
};

function colorByElevation(elev) {
  if (elev < 50) return [73, 154, 88, 210];
  if (elev < 100) return [130, 180, 85, 215];
  if (elev < 200) return [206, 190, 95, 220];
  if (elev < 350) return [190, 130, 70, 225];
  if (elev < 550) return [150, 95, 70, 230];
  return [245, 245, 245, 235];
}

function setActive(ids, activeId) {
  ids.forEach(id => {
    document.getElementById(id).classList.remove("active");
  });
  document.getElementById(activeId).classList.add("active");
}

function setBaseMap(mode) {
  baseMode = mode;

  if (mode === "light") {
    setActive(["base-light", "base-satellite", "base-dark"], "base-light");
  } else if (mode === "satellite") {
    setActive(["base-light", "base-satellite", "base-dark"], "base-satellite");
  } else {
    setActive(["base-light", "base-satellite", "base-dark"], "base-dark");
  }

  render();
}

function setTerrainMode(mode) {
  terrainMode = mode;

  if (mode === "color") {
    setActive(["terrain-color", "terrain-gray"], "terrain-color");
  } else {
    setActive(["terrain-color", "terrain-gray"], "terrain-gray");
  }

  render();
}

function setArrowDegree(degree) {
  arrowDegreeMode = degree;

  if (degree === null) {
    setActive(["arrow-none", "arrow-15", "arrow-20", "arrow-25", "arrow-30"], "arrow-none");
  } else if (degree === 15) {
    setActive(["arrow-none", "arrow-15", "arrow-20", "arrow-25", "arrow-30"], "arrow-15");
  } else if (degree === 20) {
    setActive(["arrow-none", "arrow-15", "arrow-20", "arrow-25", "arrow-30"], "arrow-20");
  } else if (degree === 25) {
    setActive(["arrow-none", "arrow-15", "arrow-20", "arrow-25", "arrow-30"], "arrow-25");
  } else if (degree === 30) {
    setActive(["arrow-none", "arrow-15", "arrow-20", "arrow-25", "arrow-30"], "arrow-30");
  }

  render();
}

function filteredArrowData() {
  if (arrowDegreeMode === null) {
    return [];
  }

  return arrowData.filter(d => d.slope >= arrowDegreeMode);
}

function filteredArrowHeadData() {
  if (arrowDegreeMode === null) {
    return [];
  }

  return arrowHeadData.filter(d => d.slope >= arrowDegreeMode);
}

function getLayers() {

  const tileLayer = new deck.TileLayer({
    id: "base-map",
    data: MAPS[baseMode].url,
    minZoom: 0,
    maxZoom: 19,
    tileSize: 256,
    renderSubLayers: props => {
      const {
        bbox: {west, south, east, north}
      } = props.tile;

      return new deck.BitmapLayer(props, {
        data: null,
        image: props.data,
        bounds: [west, south, east, north]
      });
    }
  });

  const terrainColorLayer = new deck.GeoJsonLayer({
    id: "terrain-color",
    data: demGeojson,
    pickable: false,
    stroked: false,
    filled: true,
    extruded: true,
    wireframe: false,
    visible: terrainMode === "color",
    getElevation: f => f.properties.height,
    getFillColor: f => colorByElevation(f.properties.elev),
    material: {
      ambient: 0.45,
      diffuse: 0.65,
      shininess: 16,
      specularColor: [60, 60, 60]
    }
  });

  const terrainGrayLayer = new deck.GeoJsonLayer({
    id: "terrain-gray",
    data: demGeojson,
    pickable: false,
    stroked: false,
    filled: true,
    extruded: true,
    wireframe: false,
    visible: terrainMode === "gray",
    getElevation: f => f.properties.height,
    getFillColor: [150, 150, 150, 170],
    material: {
      ambient: 0.55,
      diffuse: 0.55,
      shininess: 8,
      specularColor: [80, 80, 80]
    }
  });

  const boundaryLayer = new deck.PathLayer({
    id: "district-boundary",
    data: boundaryData,
    pickable: false,
    getPath: d => d.path,
    getColor: [0, 0, 0, 255],
    getWidth: 9,
    widthMinPixels: 3,
    widthMaxPixels: 10,
    jointRounded: true,
    capRounded: true,
    parameters: {
      depthTest: false
    }
  });

  const arrowLayer = new deck.PathLayer({
    id: "steep-arrows",
    data: filteredArrowData(),
    pickable: false,
    getPath: d => d.path,
    getColor: [230, 0, 0, 255],
    getWidth: 6,
    widthMinPixels: 2,
    widthMaxPixels: 6,
    jointRounded: true,
    capRounded: true,
    parameters: {
      depthTest: false
    }
  });

  const arrowHeadLayer = new deck.PathLayer({
    id: "steep-arrow-heads-3d",
    data: filteredArrowHeadData(),
    pickable: false,
    getPath: d => d.path,
    getColor: [230, 0, 0, 255],
    getWidth: 6,
    widthMinPixels: 2,
    widthMaxPixels: 6,
    jointRounded: true,
    capRounded: true,
    parameters: {
      depthTest: false
    }
  });

  return [
    tileLayer,
    terrainColorLayer,
    terrainGrayLayer,
    boundaryLayer,
    arrowLayer,
    arrowHeadLayer
  ];
}

const deckgl = new deck.DeckGL({
  container: "map",
  initialViewState: INITIAL_VIEW_STATE,
  controller: {
    dragPan: true,
    dragRotate: true,
    scrollZoom: true,
    touchZoom: true,
    touchRotate: true,
    doubleClickZoom: true,
    keyboard: true,
    inertia: true
  },
  layers: getLayers()
});

function render() {
  deckgl.setProps({
    layers: getLayers()
  });
}

</script>

</body>
</html>'
)


# 11. HTML 저장 -------------------------------------------------

writeLines(
  html_code,
  output_html,
  useBytes = TRUE
)

cat("HTML 저장 완료:\n")
cat(output_html, "\n")

browseURL(normalizePath(output_html, winslash = "/", mustWork = FALSE))