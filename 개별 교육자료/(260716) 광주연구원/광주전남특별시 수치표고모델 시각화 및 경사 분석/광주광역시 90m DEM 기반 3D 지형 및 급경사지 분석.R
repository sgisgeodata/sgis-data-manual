# ============================================================
# 광주광역시 90m DEM 기반 3D 지도 HTML
#
# 목표
# - 배경지도 위에 광주 DEM 3D 지형을 얹는다.
# - 지형은 다색/회색 단색으로 전환 가능하게 한다.
# - 급경사지 방향은 빨간 화살표로 표시하고 켜기/끄기 가능하게 한다.
# - 구 경계선은 표시하되, 구 이름 글씨는 표시하지 않는다.
# - 왼쪽 아래 힌트박스는 표시하지 않는다.
# - 지도는 뒤집히지 않고, 확대·축소·이동·기울임만 가능하게 한다.
# - 최종 결과를 HTML로 저장한다.
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

output_html <- file.path(base_dir, "광주_DEM_3D_배경지도_최종_수정.html")
temp_geojson <- file.path(base_dir, "temp_gwangju_dem_3d.geojson")


# 2. 시각화 옵션 -----------------------------------------------

# 높이 과장값
# 더 입체적으로 보려면 3~5 사이로 조정
z_exaggeration <- 3.5

# DEM 셀 수가 너무 많으면 HTML이 무거워지므로 줄임
# 숫자가 클수록 정밀하지만 무거움
target_cells <- 12000

# 급경사지 기준
# 0.95 = 경사도 상위 5%
steep_prob <- 0.95

# 화살표 최대 개수
max_arrow <- 400

# 화살표 길이
arrow_length_meter <- 180


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

# DEM 좌표계로 변환
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


# 8. 경사도와 사면향 계산 --------------------------------------

slope <- terrain(dem_gwangju, v = "slope", unit = "degrees")
aspect <- terrain(dem_gwangju, v = "aspect", unit = "degrees")

names(slope) <- "slope_deg"
names(aspect) <- "aspect_deg"

slope_threshold <- global(
  slope,
  quantile,
  probs = steep_prob,
  na.rm = TRUE
)[1, 1]

cat("급경사지 기준 경사도:", round(slope_threshold, 2), "도 이상\n")

steep_area <- slope >= slope_threshold

steep_points <- as.points(
  steep_area,
  values = TRUE,
  na.rm = TRUE
)

steep_value_col <- names(steep_points)[1]
steep_points <- steep_points[steep_points[[steep_value_col]] == 1, ]

steep_sf <- st_as_sf(steep_points)

steep_sf$slope_deg <- terra::extract(slope, vect(steep_sf))[, 2]
steep_sf$aspect_deg <- terra::extract(aspect, vect(steep_sf))[, 2]
steep_sf$elev <- terra::extract(dem_gwangju, vect(steep_sf))[, 2]

steep_sf <- steep_sf %>%
  filter(!is.na(slope_deg), !is.na(aspect_deg), !is.na(elev))

set.seed(2026)

if (nrow(steep_sf) > max_arrow) {
  steep_sf <- steep_sf %>%
    slice_sample(n = max_arrow)
}

steep_xy <- st_coordinates(steep_sf)

steep_sf$x1 <- steep_xy[, 1]
steep_sf$y1 <- steep_xy[, 2]

steep_sf <- steep_sf %>%
  mutate(
    aspect_rad = aspect_deg * pi / 180,
    x2 = x1 + sin(aspect_rad) * arrow_length_meter,
    y2 = y1 + cos(aspect_rad) * arrow_length_meter,
    z = elev * z_exaggeration + 80
  )

arrow_start <- st_as_sf(
  steep_sf %>% st_drop_geometry() %>% select(x1, y1, z, slope_deg),
  coords = c("x1", "y1"),
  crs = crs(dem_gwangju),
  remove = FALSE
)

arrow_end <- st_as_sf(
  steep_sf %>% st_drop_geometry() %>% select(x2, y2, z, slope_deg),
  coords = c("x2", "y2"),
  crs = crs(dem_gwangju),
  remove = FALSE
)

arrow_start_4326 <- st_transform(arrow_start, 4326)
arrow_end_4326 <- st_transform(arrow_end, 4326)

start_xy <- st_coordinates(arrow_start_4326)
end_xy <- st_coordinates(arrow_end_4326)

arrow_data <- lapply(seq_len(nrow(steep_sf)), function(i) {
  list(
    path = list(
      list(start_xy[i, 1], start_xy[i, 2], steep_sf$z[i]),
      list(end_xy[i, 1], end_xy[i, 2], steep_sf$z[i])
    ),
    slope = round(steep_sf$slope_deg[i], 1)
  )
})

arrow_json <- toJSON(arrow_data, auto_unbox = TRUE, digits = 8)


# 9. 구 경계 데이터 --------------------------------------------

gwangju_4326 <- st_transform(gwangju, 4326)

gwangju_boundary <- st_cast(gwangju_4326, "MULTILINESTRING", warn = FALSE)

boundary_data <- list()

for (i in seq_len(nrow(gwangju_boundary))) {
  
  line_i <- st_coordinates(gwangju_boundary[i, ])
  
  boundary_data[[i]] <- list(
    name = gwangju_4326$SIGUNGU_NM[i],
    path = lapply(seq_len(nrow(line_i)), function(j) {
      list(line_i[j, "X"], line_i[j, "Y"], 120)
    })
  )
}

boundary_json <- toJSON(boundary_data, auto_unbox = TRUE, digits = 8)


# 지도 중심점
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
  <div id="subtitle">배경지도 위에 광주 DEM 지형을 3D로 중첩하고, 급경사지 방향을 표시</div>
</div>

<div id="controls">
  <div class="control-title">배경지도</div>
  <button id="base-light" class="active" onclick="setBaseMap(\'light\')">백지도</button>
  <button id="base-satellite" onclick="setBaseMap(\'satellite\')">위성지도</button>
  <button id="base-dark" onclick="setBaseMap(\'dark\')">어두운지도</button>

  <div class="control-title">DEM 표현</div>
  <button id="terrain-color" class="active" onclick="setTerrainMode(\'color\')">다색 지형</button>
  <button id="terrain-gray" onclick="setTerrainMode(\'gray\')">회색 단색</button>

  <div class="control-title">급경사지</div>
  <button id="arrow-on" class="active" onclick="setArrowMode(true)">화살표 켜기</button>
  <button id="arrow-off" onclick="setArrowMode(false)">화살표 끄기</button>
</div>

<script>

const demGeojson = ', dem_geojson_text, ';

const arrowData = ', arrow_json, ';

const boundaryData = ', boundary_json, ';

let baseMode = "light";
let terrainMode = "color";
let arrowVisible = true;

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

function setArrowMode(show) {
  arrowVisible = show;

  if (show) {
    setActive(["arrow-on", "arrow-off"], "arrow-on");
  } else {
    setActive(["arrow-on", "arrow-off"], "arrow-off");
  }

  render();
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
    getWidth: 8,
    widthMinPixels: 2,
    widthMaxPixels: 8,
    jointRounded: true,
    capRounded: true
  });

  const arrowLayer = new deck.PathLayer({
    id: "steep-arrows",
    data: arrowData,
    visible: arrowVisible,
    pickable: false,
    getPath: d => d.path,
    getColor: [230, 0, 0, 255],
    getWidth: 7,
    widthMinPixels: 2,
    widthMaxPixels: 7,
    jointRounded: true,
    capRounded: true
  });

  return [
    tileLayer,
    terrainColorLayer,
    terrainGrayLayer,
    boundaryLayer,
    arrowLayer
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