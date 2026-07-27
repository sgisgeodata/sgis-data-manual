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
#
# R에서 공간자료와 HTML 지도를 다루기 위해 필요한 확장 패키지를 준비한다.
#
# terra
#   - DEM과 같은 래스터 자료를 읽고, 자르고, 마스킹하고, 집계한다.
#   - 주요 함수: rast(), crop(), mask(), aggregate(), as.polygons(), extract()
#
# sf
#   - 시군구 경계와 같은 벡터 공간자료를 읽고 좌표계를 변환한다.
#   - 주요 함수: st_read(), st_transform(), st_make_valid(), st_coordinates()
#
# dplyr
#   - 행과 열을 선택하거나 새 변수를 만들고 자료를 결합한다.
#   - 주요 함수: filter(), mutate(), select(), distinct(), bind_rows()
#
# jsonlite
#   - R의 리스트와 데이터프레임을 JavaScript가 읽을 수 있는 JSON으로 변환한다.
#   - 주요 함수: toJSON()
#
# htmltools
#   - HTML 관련 객체와 문자를 다루는 패키지이다.
#   - 이 코드에서는 직접 호출이 많지는 않지만 HTML 제작 환경을 함께 준비한다.

# 사용할 패키지 이름을 문자 벡터로 만든다.
# c()는 여러 값을 하나의 벡터로 묶는 함수이다.
packages <- c(
  "terra",
  "sf",
  "dplyr",
  "jsonlite",
  "htmltools"
)

# installed.packages()는 현재 컴퓨터에 설치된 패키지 목록을 반환한다.
# %in%은 왼쪽 값이 오른쪽 목록 안에 있는지를 TRUE/FALSE로 확인한다.
# !는 TRUE와 FALSE를 반대로 바꾸므로, 아직 설치되지 않은 패키지만 추출한다.
new_packages <- packages[!(packages %in% installed.packages()[, "Package"])]

# 설치되지 않은 패키지가 하나 이상 있을 때만 설치한다.
# 이미 설치된 패키지를 매번 다시 설치하지 않기 위한 조건문이다.
if (length(new_packages) > 0) {
  install.packages(new_packages)
}

# library()는 설치된 패키지를 현재 R 세션에서 사용할 수 있도록 불러온다.
library(terra)
library(sf)
library(dplyr)
library(jsonlite)
library(htmltools)


# 1. 경로 설정 -------------------------------------------------
#
# 분석에 사용할 입력 파일과 최종 결과 파일의 위치를 지정한다.
# base_dir만 실제 파일이 있는 폴더에 맞게 설정하면 나머지 경로는 file.path()가 만든다.
#
# file.path()
#   - 폴더 경로와 파일명을 운영체제에 맞는 구분자로 안전하게 연결한다.

# 모든 입력·출력 파일이 들어 있는 기본 폴더이다.
base_dir <- "C:/Users/user/Desktop/R/데이터"

# 90m 공간해상도의 수치표고모형(DEM) 파일 경로이다.
# DEM은 각 격자 셀에 지표면 높이 값을 저장한 래스터 자료이다.
dem_file <- file.path(base_dir, "한반도90m_GRS80.img")
# 전국 시군구 행정경계 Shapefile 경로이다.
# 광주광역시의 5개 구를 추출하고 DEM을 광주 경계로 자르는 데 사용한다.
sigungu_file <- file.path(base_dir, "bnd_sigungu_00_2025_2Q.shp")

# 최종적으로 생성할 대화형 3D HTML 지도 경로이다.
output_html <- file.path(base_dir, "광주광역시 DEM Plot 기반 3D 급경사지 시각화.html")
# R에서 만든 DEM 폴리곤을 deck.gl에 전달하기 위한 임시 GeoJSON 파일이다.
# HTML이 완성된 뒤에도 파일은 폴더에 남지만, HTML 내부에는 내용이 직접 포함된다.
temp_geojson <- file.path(base_dir, "temp_gwangju_dem_3d.geojson")


# 2. 시각화 옵션 -----------------------------------------------
#
# 지도 모양과 처리 속도를 조절하는 주요 설정값이다.
# 결과가 너무 느리거나 지형이 지나치게 높게 보일 때 이 부분의 값만 조정하면 된다.

# z_exaggeration은 실제 표고값을 3D 높이로 얼마나 과장할지 정한다.
# 예를 들어 표고 100m 셀은 100 × 3.5 = 350의 시각적 높이로 표현된다.
# 값이 크면 산지가 더 높고 입체적으로 보이지만 실제 고도 자체가 바뀌는 것은 아니다.
z_exaggeration <- 3.5

# target_cells는 3D로 표시할 목표 셀 수이다.
# 원본 셀이 너무 많으면 브라우저 렌더링이 느려지므로 평균 집계하여 셀 수를 줄인다.
# 값이 작을수록 빠르지만 지형이 거칠어지고, 값이 클수록 정밀하지만 느려진다.
target_cells <- 12000

# arrow_min_degree는 R에서 미리 생성할 화살표 후보의 최소 경사각이다.
# HTML 버튼에서 15·20·25·30도를 선택하므로 가장 낮은 15도 이상을 모두 만들어 둔다.
# 이후 브라우저에서 선택한 각도보다 낮은 화살표를 화면에서 제외한다.
arrow_min_degree <- 15

# 화살촉의 길이와 폭을 미터 단위로 설정한다.
# 화살표가 너무 크거나 작게 보이면 이 값을 조정한다.
arrow_head_length_meter <- 32
arrow_head_width_meter <- 22

# DEM 윗면과 화살표의 높이가 완전히 같으면 화면에서 겹쳐 깜빡일 수 있다.
# arrow_lift만큼 화살표를 지형 위로 살짝 띄워 안정적으로 보이게 한다.
arrow_lift <- 4

# 구 경계선이 3D 지형 내부에 가려지지 않도록 위로 띄우는 보정값이다.
# 이 값은 실제 고도가 아니라 시각화를 위한 높이 보정이다.
boundary_lift <- 220


# 3. 데이터 불러오기 -------------------------------------------
#
# DEM 래스터와 전국 시군구 경계를 메모리로 불러온다.

# rast()는 terra 패키지에서 래스터 파일을 SpatRaster 객체로 읽는 함수이다.
dem <- rast(dem_file)

# st_read()는 Shapefile 등 벡터 공간자료를 sf 객체로 읽는다.
# options = "ENCODING=CP949"는 한글 속성값이 깨지는 것을 줄이기 위한 인코딩 설정이다.
# quiet = TRUE는 파일을 읽을 때 긴 안내 메시지를 생략한다.
sigungu <- st_read(
  sigungu_file,
  options = "ENCODING=CP949",
  quiet = TRUE
)

# cat()과 print()로 입력 자료의 좌표계와 열 이름을 확인한다.
# 좌표계와 열 이름이 예상과 다르면 이후 필터링이나 공간 연산이 실패할 수 있다.
cat("DEM CRS:\n")
print(crs(dem))

cat("시군구 컬럼명:\n")
print(names(sigungu))


# 4. 광주광역시 5개 구 추출 ------------------------------------
#
# 전국 시군구 경계에서 행정구역 코드가 광주광역시에 해당하는 5개 구만 선택한다.
#
# SIGUNGU_CD
#   - 시군구를 구분하는 행정구역 코드
#
# SIGUNGU_NM
#   - 동구, 서구, 남구, 북구, 광산구와 같은 시군구 이름

# bnd_sigungu_00_2025_2Q 기준
# 24010 동구, 24020 서구, 24030 남구, 24040 북구, 24050 광산구

# %>%는 앞 단계의 결과를 다음 함수로 전달하는 파이프 연산자이다.
# mutate()로 코드를 문자형으로 바꾸고 filter()로 5개 코드만 남긴다.
gwangju <- sigungu %>%
  mutate(SIGUNGU_CD = as.character(SIGUNGU_CD)) %>%
  filter(SIGUNGU_CD %in% c("24010", "24020", "24030", "24040", "24050"))

# 선택된 행이 0개이면 열 이름이나 코드가 맞지 않는 것이므로 실행을 중단한다.
if (nrow(gwangju) == 0) {
  stop("SIGUNGU_CD 기준으로 광주광역시 경계를 찾지 못했습니다.")
}

cat("선택된 광주광역시 구 목록:\n")
print(gwangju %>% st_drop_geometry() %>% select(SIGUNGU_CD, SIGUNGU_NM))

# st_make_valid()는 깨지거나 자기 교차가 있는 행정경계 도형을 가능한 한 유효하게 만든다.
# st_transform(crs(dem))은 경계 좌표계를 DEM 좌표계와 동일하게 변환한다.
# crop(), mask(), extract() 같은 공간 연산은 두 자료의 좌표계가 같아야 정확하다.
gwangju <- gwangju %>%
  st_make_valid() %>%
  st_transform(crs(dem))

# vect()는 sf 경계를 terra가 사용하는 SpatVector 형식으로 변환한다.
gwangju_vect <- vect(gwangju)


# 5. DEM 자르기 -------------------------------------------------
#
# 전국 범위 DEM에서 광주광역시 영역만 남긴다.
#
# crop()
#   - 광주 경계의 최소 사각 범위까지만 먼저 잘라 자료량을 줄인다.
#
# mask()
#   - 사각 범위 안에서도 광주 경계 바깥에 있는 셀을 NA로 제거한다.

# crop()과 mask()를 연속 적용해 광주 경계 모양의 DEM을 만든다.
dem_gwangju <- dem %>%
  crop(gwangju_vect) %>%
  mask(gwangju_vect)

# -100m보다 낮은 값은 비정상값이나 분석에 불필요한 값으로 보고 NA 처리한다.
# NA 셀은 이후 3D 폴리곤과 경사 화살표 생성에서 제외된다.
dem_gwangju[dem_gwangju < -100] <- NA


# 6. DEM 해상도 조정 -------------------------------------------
#
# 원본 DEM 셀 수가 target_cells보다 많으면 여러 셀을 하나로 평균 집계한다.
# 3D 폴리곤이 지나치게 많아 브라우저가 느려지는 것을 방지하기 위한 단계이다.
#
# 중요한 점은 화면에 표시하는 dem_plot을 기준으로 화살표도 계산한다는 것이다.
# 따라서 3D 블록의 크기와 화살표가 이동하는 셀 단위가 서로 일치한다.

# 중요:
# 화면에 보이는 3D 블록과 화살표 기준을 일치시키기 위해
# dem_plot 기준으로 화살표도 계산한다.

# ncell()은 래스터의 전체 셀 개수를 반환한다.
if (ncell(dem_gwangju) > target_cells) {
  # 집계 후 셀 수가 목표값에 가까워지도록 가로·세로 집계 배수를 계산한다.
  # sqrt()를 사용하는 이유는 셀 수가 가로와 세로 두 방향의 곱으로 줄어들기 때문이다.
  # ceiling()은 소수점을 올림하여 목표 셀 수를 넘지 않도록 한다.
  fact_value <- ceiling(sqrt(ncell(dem_gwangju) / target_cells))

  cat("원본 DEM 셀 수:", ncell(dem_gwangju), "\n")
  cat("목표 DEM Plot 셀 수:", target_cells, "\n")
  cat("집계 계수 fact_value:", fact_value, "\n")
  cat("DEM Plot 1칸 = 원본 90m 격자", fact_value, "x", fact_value, "개\n")
  cat("DEM Plot 1칸 실제 크기 약:", fact_value * 90, "m x", fact_value * 90, "m\n")
  
  # aggregate()는 fact_value × fact_value 크기의 원본 셀을 하나로 묶는다.
  # fun = mean은 묶인 셀들의 평균 표고를 새 셀 값으로 사용한다.
  # na.rm = TRUE는 NA가 섞여 있어도 유효한 값으로 평균을 계산한다.
  dem_plot <- aggregate(
    dem_gwangju,
    fact = fact_value,
    fun = mean,
    na.rm = TRUE
  )
} else {
  # 원본 셀 수가 목표값 이하이면 집계하지 않고 그대로 사용한다.
  dem_plot <- dem_gwangju
}

# 래스터 레이어 이름을 고도(elevation)의 줄임말인 elev로 지정한다.
names(dem_plot) <- "elev"

cat("3D 표시용 DEM 셀 수:", ncell(dem_plot), "\n")


# 7. DEM을 3D 폴리곤 GeoJSON으로 변환 --------------------------
#
# deck.gl의 GeoJsonLayer에서 셀별 3D 기둥을 만들 수 있도록
# 래스터의 각 셀을 사각형 폴리곤으로 변환한다.

# as.polygons()는 각 래스터 셀을 벡터 사각형으로 변환한다.
# dissolve = FALSE는 같은 고도값을 가진 인접 셀을 합치지 않고 개별 셀로 유지한다.
# na.rm = TRUE는 NA 셀을 폴리곤으로 만들지 않는다.
dem_poly <- as.polygons(
  dem_plot,
  dissolve = FALSE,
  na.rm = TRUE
)

names(dem_poly) <- "elev"

# st_as_sf()는 terra의 SpatVector를 sf 객체로 변환한다.
dem_poly_sf <- st_as_sf(dem_poly)

# elev는 실제 평균 표고이고, height는 z_exaggeration을 적용한 3D 표시 높이이다.
# st_transform(4326)은 웹 지도에서 사용하는 경도·위도 좌표계로 변환한다.
dem_poly_sf <- dem_poly_sf %>%
  filter(!is.na(elev)) %>%
  mutate(
    elev = round(elev, 1),
    height = round(elev * z_exaggeration, 1)
  ) %>%
  st_transform(4326)

# 같은 이름의 임시 GeoJSON이 있으면 덮어쓰기 충돌을 피하기 위해 먼저 삭제한다.
if (file.exists(temp_geojson)) {
  file.remove(temp_geojson)
}

# st_write()는 DEM 셀 폴리곤을 GeoJSON 파일로 저장한다.
st_write(
  dem_poly_sf,
  temp_geojson,
  driver = "GeoJSON",
  quiet = TRUE
)

# readLines()로 GeoJSON 파일을 한 줄씩 읽고 paste(..., collapse = "\n")로 하나의 문자열로 합친다.
# 이 문자열은 뒤에서 HTML의 JavaScript 변수 demGeojson에 직접 삽입된다.
dem_geojson_text <- paste(readLines(temp_geojson, encoding = "UTF-8"), collapse = "\n")


# 8. 셀 기반 급경사 화살표 계산 --------------------------------
#
# 각 DEM 셀 A를 기준으로 주변 8개 셀을 비교한다.
# A보다 낮은 이웃 셀 중 경사각이 가장 큰 셀 B를 선택하고,
# A에서 B로 내려가는 방향을 하나의 화살표로 만든다.
#
# 따라서 한 셀에서 여러 방향의 화살표를 만드는 것이 아니라
# 가장 급하게 낮아지는 한 방향만 남긴다.

# as.matrix(..., wide = TRUE)는 래스터를 행·열 구조의 행렬로 변환한다.
# 반복문에서 [행, 열] 방식으로 주변 셀을 조회하기 위해 필요하다.
dem_matrix <- as.matrix(dem_plot, wide = TRUE)

# nr은 행 개수, nc는 열 개수이다.
nr <- nrow(dem_matrix)
nc <- ncol(dem_matrix)

# res()는 래스터 한 셀의 X방향·Y방향 실제 크기를 반환한다.
# 집계된 DEM이면 원래 90m보다 큰 값이 된다.
res_x <- res(dem_plot)[1]
res_y <- res(dem_plot)[2]

# xmin_dem과 ymax_dem은 행·열 번호를 실제 공간좌표로 바꿀 때 기준점이 된다.
xmin_dem <- xmin(dem_plot)
ymax_dem <- ymax(dem_plot)

# 열 번호를 해당 셀 중심의 X좌표로 변환하는 사용자 정의 함수이다.
# 첫 셀의 중심은 최소 X좌표에서 셀 너비의 절반만큼 안쪽에 있다.
cell_center_x <- function(col) {
  xmin_dem + (col - 0.5) * res_x
}

# 행 번호를 해당 셀 중심의 Y좌표로 변환한다.
# 래스터 행은 위에서 아래로 증가하므로 ymax에서 값을 빼는 방식으로 계산한다.
cell_center_y <- function(row) {
  ymax_dem - (row - 0.5) * res_y
}

# expand.grid()로 행 변화량 dr과 열 변화량 dc의 모든 조합을 만든다.
# 중심 셀인 dr = 0, dc = 0은 제외하여 상·하·좌·우와 대각선의 총 8방향만 남긴다.
neighbor_dirs <- expand.grid(
  dr = c(-1, 0, 1),
  dc = c(-1, 0, 1)
) %>%
  filter(!(dr == 0 & dc == 0))

# 각 화살표의 계산 결과를 순서대로 저장할 빈 리스트이다.
arrow_records <- list()

# 모든 DEM 행과 열을 순회한다.
# seq_len(nr)은 1부터 nr까지 안전한 정수 순서를 만든다.
for (r in seq_len(nr)) {
  
  for (c in seq_len(nc)) {
    
    # 현재 기준 셀 A의 표고를 가져온다.
    elev_a <- dem_matrix[r, c]
    
    # 광주 경계 밖이나 값이 없는 셀은 계산하지 않고 다음 셀로 이동한다.
    if (is.na(elev_a)) {
      next
    }
    
    x_a <- cell_center_x(c)
    y_a <- cell_center_y(r)
    
    # best_slope에는 지금까지 찾은 가장 큰 하향 경사각을 저장한다.
    # -Inf로 시작하면 처음 계산된 유효 경사각이 반드시 선택된다.
    # best_info에는 선택된 이웃 셀 B의 위치·표고·경사각을 저장한다.
    best_slope <- -Inf
    best_info <- NULL
    
    # 현재 셀 주변의 8개 이웃 방향을 하나씩 검사한다.
    for (k in seq_len(nrow(neighbor_dirs))) {
      
      dr <- neighbor_dirs$dr[k]
      dc <- neighbor_dirs$dc[k]
      
      # rb와 cb는 후보 이웃 셀 B의 행·열 번호이다.
      rb <- r + dr
      cb <- c + dc
      
      # 이웃 위치가 행렬 범위를 벗어나면 다음 방향으로 넘어간다.
      if (rb < 1 || rb > nr || cb < 1 || cb > nc) {
        next
      }
      
      elev_b <- dem_matrix[rb, cb]
      
      if (is.na(elev_b)) {
        next
      }
      
      # A와 B의 표고 차이를 계산한다.
      # 양수이면 A가 B보다 높아 하향 이동이 가능하다.
      elev_diff <- elev_a - elev_b
      
      if (elev_diff <= 0) {
        next
      }
      
      # 두 셀 중심 사이의 평면거리를 피타고라스식으로 계산한다.
      # 대각선 이웃은 직선 이웃보다 거리가 더 길게 계산된다.
      dist_xy <- sqrt((dc * res_x)^2 + (dr * res_y)^2)

      # 경사각 = arctan(표고차 / 수평거리)이며 라디안을 도(degree)로 변환한다.
      slope_deg <- atan(elev_diff / dist_xy) * 180 / pi
      
      # 현재 후보가 기존 후보보다 더 급하면 최적 방향을 갱신한다.
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
    
    # 주변에 더 낮은 셀이 하나도 없으면 화살표를 만들지 않는다.
    if (is.null(best_info)) {
      next
    }
    
    # 가장 급한 방향도 최소 기준각보다 작으면 후보에서 제외한다.
    if (best_info$slope_deg < arrow_min_degree) {
      next
    }
    
    dr_best <- best_info$dr
    dc_best <- best_info$dc
    
    # sign()은 양수면 1, 음수면 -1, 0이면 0을 반환한다.
    # 이를 이용해 화살표가 셀의 어느 모서리 또는 꼭짓점에서 시작할지 정한다.
    # 행 번호는 아래로 증가하므로 Y방향 부호는 반대로 적용한다.
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
    
    # 시작점과 끝점의 Z값은 각 셀 표고에 높이 과장값을 곱하고
    # 지형 표면과 겹치지 않도록 arrow_lift를 더한다.
    z_start <- elev_a * z_exaggeration + arrow_lift
    z_tip <- best_info$elev_b * z_exaggeration + arrow_lift
    
    dx <- x_tip - x_start
    dy <- y_tip - y_start
    
    # 시작점부터 화살표 끝점까지의 평면 길이를 계산한다.
    len_xy <- sqrt(dx^2 + dy^2)
    
    if (len_xy == 0) {
      next
    }
    
    # 방향벡터를 길이 1인 단위벡터로 바꾼다.
    # 단위벡터는 화살촉 밑변 위치와 좌우 방향을 계산할 때 사용한다.
    unit_x <- dx / len_xy
    unit_y <- dy / len_xy
    
    # 화살표 길이가 짧을 때 화살촉이 몸통보다 커지는 것을 방지하기 위해
    # 설정값과 전체 길이의 일정 비율 중 작은 값을 사용한다.
    head_len <- min(arrow_head_length_meter, len_xy * 0.35)
    head_wid <- min(arrow_head_width_meter, len_xy * 0.28)
    
    x_head_base <- x_tip - unit_x * head_len
    y_head_base <- y_tip - unit_y * head_len
    
    # 화살촉 밑변이 전체 화살표 중 어느 지점에 있는지 비율을 계산한다.
    # 이 비율로 시작 고도와 끝 고도 사이를 선형 보간하여 화살촉 밑변의 Z값을 구한다.
    base_ratio <- sqrt((x_head_base - x_start)^2 + (y_head_base - y_start)^2) / len_xy
    z_head_base <- z_start + (z_tip - z_start) * base_ratio
    
    x_shaft_end <- x_head_base
    y_shaft_end <- y_head_base
    z_shaft_end <- z_head_base
    
    # 진행 방향에 수직인 벡터를 만들어 화살촉의 좌우 끝점을 계산한다.
    perp_x <- -unit_y
    perp_y <- unit_x
    
    x_head_left <- x_head_base + perp_x * head_wid / 2
    y_head_left <- y_head_base + perp_y * head_wid / 2
    
    x_head_right <- x_head_base - perp_x * head_wid / 2
    y_head_right <- y_head_base - perp_y * head_wid / 2
    
    # 계산된 화살표의 셀 위치, 경사각, 몸통 좌표, 화살촉 좌표를 한 행으로 저장한다.
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

# bind_rows()는 리스트에 저장된 여러 data.frame을 하나의 표로 합친다.
arrow_df <- bind_rows(arrow_records)

# 정확한 중복 제거:
# 시작점과 도착점이 완전히 같은 동일 화살표만 제거
# 좌표를 소수점 셋째 자리까지 반올림하여 시작점과 끝점이 같은 화살표 키를 만든다.
# distinct()는 같은 키가 반복될 경우 첫 번째 화살표만 남긴다.
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
#
# 화살표 계산은 DEM의 투영좌표계와 미터 단위로 수행했지만,
# deck.gl 웹 지도에는 경도·위도 좌표가 필요하다.

# X·Y 좌표 벡터를 sf 점 객체로 만들고 EPSG:4326으로 변환하는 함수이다.
make_point_4326 <- function(x, y) {
  # coords에 지정한 x와 y 열을 실제 점 geometry로 변환한다.
  # crs에는 현재 DEM의 좌표계를 지정한다.
  temp_sf <- st_as_sf(
    data.frame(x = x, y = y),
    coords = c("x", "y"),
    crs = crs(dem_plot)
  )
  
  # EPSG:4326은 웹 지도에서 사용하는 WGS84 경도·위도 좌표계이다.
  temp_4326 <- st_transform(temp_sf, 4326)
  st_coordinates(temp_4326)
}

start_xy <- make_point_4326(arrow_df$x_start, arrow_df$y_start)
shaft_end_xy <- make_point_4326(arrow_df$x_shaft_end, arrow_df$y_shaft_end)
tip_xy <- make_point_4326(arrow_df$x_tip, arrow_df$y_tip)
head_left_xy <- make_point_4326(arrow_df$x_head_left, arrow_df$y_head_left)
head_right_xy <- make_point_4326(arrow_df$x_head_right, arrow_df$y_head_right)


# 8-2. 화살표 몸통 데이터 생성 ---------------------------------
#
# deck.gl PathLayer가 읽을 수 있도록 각 화살표 몸통을
# 시작점과 화살촉 밑변점으로 구성된 path 리스트로 만든다.

# lapply()는 모든 화살표 행에 같은 변환 함수를 반복 적용하고 결과를 리스트로 반환한다.
arrow_data <- lapply(seq_len(nrow(arrow_df)), function(i) {
  list(
    path = list(
      list(start_xy[i, 1], start_xy[i, 2], arrow_df$z_start[i]),
      list(shaft_end_xy[i, 1], shaft_end_xy[i, 2], arrow_df$z_shaft_end[i])
    ),
    slope = arrow_df$slope[i]
  )
})

# toJSON()은 R 리스트를 JavaScript에서 사용할 JSON 문자열로 변환한다.
# auto_unbox = TRUE는 길이 1짜리 값이 불필요한 배열로 감싸지는 것을 줄인다.
# digits = 8은 좌표 정밀도를 소수점 유효 8자리 수준으로 유지한다.
arrow_json <- toJSON(arrow_data, auto_unbox = TRUE, digits = 8)


# 8-3. 3D 화살촉 데이터 생성 -----------------------------------
#
# 화살촉은 왼쪽 끝점→끝점과 오른쪽 끝점→끝점의 두 선으로 표현한다.
# 한 화살표마다 PathLayer용 경로가 2개씩 만들어진다.

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
#
# 광주광역시 5개 구의 외곽선을 3D 지형 위에 표시하기 위한 경로를 만든다.
# 경계점마다 DEM 표고를 추출하고 boundary_lift를 더해 지형 위로 띄운다.

# 지도 중심점 계산에 사용할 광주 경계를 경도·위도 좌표계로 변환한다.
gwangju_4326 <- st_transform(gwangju, 4326)

# st_cast()는 면 형태의 행정구역 경계를 선 형태로 변환한다.
gwangju_boundary <- st_cast(gwangju, "MULTILINESTRING", warn = FALSE)

# 구별 3D 경계 경로를 저장할 리스트이다.
boundary_data <- list()

for (i in seq_len(nrow(gwangju_boundary))) {
  
  # 현재 구 경계선의 모든 꼭짓점 X·Y 좌표를 추출한다.
  line_coords <- st_coordinates(gwangju_boundary[i, ])
  
  boundary_pts <- st_as_sf(
    data.frame(
      x = line_coords[, "X"],
      y = line_coords[, "Y"]
    ),
    coords = c("x", "y"),
    crs = crs(dem_gwangju)
  )
  
  # terra::extract()로 각 경계점 위치의 DEM 표고를 추출한다.
  # 첫 번째 열은 객체 ID이고 두 번째 열이 실제 표고값이므로 [, 2]를 선택한다.
  elev_vals <- terra::extract(dem_gwangju, vect(boundary_pts))[, 2]
  
  # 경계선의 3D 높이는 표고 과장값과 경계 띄우기 값을 함께 적용한다.
  z_vals <- elev_vals * z_exaggeration + boundary_lift
  
  # 경계점에서 DEM 값이 추출되지 않은 경우를 대비해 광주 전체 평균 표고를 계산한다.
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

# 구 경계 경로를 JavaScript용 JSON 문자열로 변환한다.
boundary_json <- toJSON(boundary_data, auto_unbox = TRUE, digits = 8)


# 지도 중심점 ---------------------------------------------------
#
# 광주 5개 구를 하나의 도형으로 합친 뒤 중심점을 구한다.
# 이 경도·위도는 HTML 지도를 처음 열었을 때의 중심 위치로 사용된다.

# st_union()은 5개 구 경계를 하나로 합치고 st_centroid()는 그 중심점을 계산한다.
center <- st_centroid(st_union(gwangju_4326))
center_xy <- st_coordinates(center)

center_lon <- center_xy[1, 1]
center_lat <- center_xy[1, 2]


# 10. HTML 생성 -------------------------------------------------
#
# paste0()로 HTML, CSS, JavaScript 코드와 R에서 만든 GeoJSON·JSON 문자열을 결합한다.
#
# deck.gl
#   - 웹 브라우저에서 대용량 공간자료와 3D 레이어를 렌더링하는 JavaScript 라이브러리
#
# HTML 안에 DEM, 화살표, 경계 데이터를 직접 넣기 때문에
# 최종 HTML은 입력 공간파일 없이도 지형 데이터를 표시할 수 있다.
# 다만 배경지도와 deck.gl 라이브러리는 인터넷에서 불러오므로 인터넷 연결이 필요하다.

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

// R에서 만든 DEM 셀 GeoJSON을 JavaScript 객체로 삽입한다.
const demGeojson = ', dem_geojson_text, ';

const arrowData = ', arrow_json, ';

const arrowHeadData = ', arrow_head_json, ';

const boundaryData = ', boundary_json, ';

// 현재 선택된 배경지도와 지형 표현 방식을 저장하는 상태 변수이다.
let baseMode = "light";
let terrainMode = "color";

let arrowDegreeMode = 15;

// 지도를 처음 열었을 때의 중심, 확대 수준, 기울기, 회전각을 설정한다.
const INITIAL_VIEW_STATE = {
  longitude: ', center_lon, ',
  latitude: ', center_lat, ',
  zoom: 10.3,
  pitch: 58,
  bearing: -18,
  maxPitch: 85,
  minPitch: 0
};

// 선택 가능한 배경지도 타일 주소를 정의한다.
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

// 실제 표고값에 따라 DEM 기둥의 색상을 구간별로 반환한다.
function colorByElevation(elev) {
  if (elev < 50) return [73, 154, 88, 210];
  if (elev < 100) return [130, 180, 85, 215];
  if (elev < 200) return [206, 190, 95, 220];
  if (elev < 350) return [190, 130, 70, 225];
  if (elev < 550) return [150, 95, 70, 230];
  return [245, 245, 245, 235];
}

// 같은 종류의 버튼에서 기존 active 표시를 지우고 선택 버튼만 활성화한다.
function setActive(ids, activeId) {
  ids.forEach(id => {
    document.getElementById(id).classList.remove("active");
  });
  document.getElementById(activeId).classList.add("active");
}

// 배경지도 버튼을 누르면 모드를 바꾸고 전체 레이어를 다시 그린다.
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

// 다색 지형과 회색 단색 지형 중 표시할 방식을 선택한다.
function setTerrainMode(mode) {
  terrainMode = mode;

  if (mode === "color") {
    setActive(["terrain-color", "terrain-gray"], "terrain-color");
  } else {
    setActive(["terrain-color", "terrain-gray"], "terrain-gray");
  }

  render();
}

// 선택된 최소 경사각을 저장하고 해당 버튼을 활성화한다.
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

// 현재 선택된 경사각 이상인 화살표 몸통만 남긴다.
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

// 현재 상태에 맞는 배경지도·DEM·경계·화살표 레이어를 생성한다.
function getLayers() {

  // 배경지도 타일을 화면에 표시하는 레이어이다.
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

  // 표고 구간별 색상을 적용한 3D DEM 기둥 레이어이다.
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

  // 모든 셀을 같은 회색 계열로 표현하는 3D DEM 레이어이다.
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

  // 광주광역시 5개 구 경계를 검은색 3D 선으로 표시한다.
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

  // 급경사 하향 방향 화살표의 몸통을 표시한다.
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

  // 급경사 화살표의 좌우 화살촉 선을 표시한다.
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

// DeckGL 지도 객체를 만들고 마우스 이동·회전·확대 기능을 활성화한다.
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

// 버튼 상태가 바뀔 때 레이어를 다시 계산해 지도에 반영한다.
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
#
# 완성한 HTML 문자열을 파일로 저장하고 기본 웹 브라우저에서 연다.

# writeLines()는 html_code 문자열을 실제 .html 파일로 기록한다.
# useBytes = TRUE는 한글을 포함한 문자열을 가능한 그대로 저장한다.
writeLines(
  html_code,
  output_html,
  useBytes = TRUE
)

cat("HTML 저장 완료:\n")
cat(output_html, "\n")

# normalizePath()로 Windows 경로를 브라우저가 읽기 쉬운 형태로 정리하고,
# browseURL()로 완성된 HTML 파일을 기본 웹 브라우저에서 연다.
browseURL(normalizePath(output_html, winslash = "/", mustWork = FALSE))
