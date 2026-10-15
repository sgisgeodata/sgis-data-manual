# 필요 패키지 로드
library(leaflet)
library(sf)
library(htmlwidgets)

lat_mulgeum <- 35.309
lng_mulgeum <- 129.006

# 1. 데이터 준비

# 1-1. 양산시 행정동 경계
yangsan_boundary <- st_read("행정구역/bnd_dong_양산시.shp")
yangsan_boundary_4326 <- st_transform(yangsan_boundary, crs = 4326) # 좌표 변환 (EPSG:5179 -> EPSG:4326)

# 1-2. 물금읍 경계
mulgeum_boundary <- st_read("행정구역/bnd_dong_물금읍.shp")
mulgeum_boundary_4326 <- st_transform(mulgeum_boundary, crs = 4326) # 좌표 변환 (EPSG:5179 -> EPSG:4326)

# 1-3. 초중등학교 위치
school_location <- st_read("초중등학교/초중등학교 위치_물금읍.shp")
school_location

# 1-4. 초중등학교 도보5분 영역
school_5min_walk <- st_read("초중등학교/초중등학교로부터 도보5분_물금읍.shp")
school_5min_walk_4326 <- st_transform(school_5min_walk, crs = 4326) # 좌표 변환 (EPSG:5179 -> EPSG:4326)
school_5min_walk_4326

# 1-5. 학원교습소 위치
academy_location <- st_read("학원교습소/학원교습소_물금읍.shp")
academy_location_4326 <- st_transform(academy_location, crs = 4326) # 좌표 변환 (EPSG:5179 -> EPSG:4326)
academy_location_4326

# 1-6. 격자별 학령인구
school_pop <- st_read("학령인구/2024년 격자별 학령인구 추정_물금읍.shp")
school_pop_4326 <- st_transform(school_pop, crs = 4326) # 좌표 변환 (EPSG:5179 -> EPSG:4326)
# 단계구분도 계급 범위와 색상 지정
bin_school_pop <- colorBin(
  palette = c("transparent", "#ffffb2", "#fecc5c", "#fd8d3c", "#f03b20", "#bd0026"),
  domain = school_pop_4326$SCH_POP,
  bins = c(0, 5, 30, 60, 90, 120, 170)
)

# 2. Leaflet 지도 생성 및 객체 저장
map <- leaflet() %>%

  # 1-0. 배경지도(OpenStreetMap, Esri)
  addTiles(group = "OpenStreetMap") %>%
  # Esri WorldImagery 배경지도
  addProviderTiles(
    providers$Esri.WorldImagery,
    group = "Esri 위성지도"
  ) %>%

  # 1-1. 양산시 경계
  addPolygons(
    data = yangsan_boundary_4326,
    group = "양산시 행정동 경계",
    fill = FALSE,
    color = "blue",
    weight = 3,
    opacity = 0.5,  # 선 투명도 50% 지정
    label = ~ADM_NM,  # 마우스 호버 시 툴팁
    labelOptions = labelOptions(
      noHide = TRUE,          # 마우스를 치워도 라벨이 항상 유지됨
      direction = "center",   # <--- 폴리곤 중앙에 텍스트 위치
      textOnly = TRUE,        # <--- 말풍선 상자 없이 글자만 깔끔하게 표시 (선택사항)
      style = list(           # <--- 가독성을 위한 글자 스타일 (선택사항)
        "color" = "gray",
        "font-weight" = "bold",
        "font-size" = "15px"
      )
    )
  ) %>%

  # 1-2. 물금읍 경계
  addPolygons(
    data = mulgeum_boundary_4326,
    group = "물금읍 경계",
    fill = FALSE,
    color = "blue",
    weight = 5
  ) %>%

  # 1-3. 초중등학교 위치
  addMarkers(
    data = school_location,
    group = "초중등학교",
    label = ~학교명  # 마우스 호버 시 툴팁
  ) %>%
  
  # 1-4. 초중등학교에서 도보5분
  addPolygons(
    data = school_5min_walk_4326,
    group = "학교에서 도보5분",
    fill = TRUE,
    color = "blue",
    weight = 1
  ) %>%
  
  # 1-5. 학원교습소 위치
  addCircleMarkers(
    data = academy_location_4326,
    group = "학원교습소",
    radius = 3,            # <--- 크기(반지름 픽셀) 조절
    color = "#FF0000",     # 테두리 색상
    fillColor = "#FF3333", # 내부 채우기 색상
    fillOpacity = 0.8,
    weight = 1,            # 테두리 두께
    popup = ~학원명,
    label = ~학원명,
    # 줌 레벨 14 이상으로 확대되면 클러스터를 무조건 해제하고 개별 마커 표시
    clusterOptions = markerClusterOptions(
      disableClusteringAtZoom = 14
    )
  ) %>%
  
  # 1-6. 격자별 학령인구
  addPolygons(
    data = school_pop_4326,
    group = "격자별 학령인구",
    # --- 면 색상 설정 ---
    fill = TRUE,
    fillColor = ~bin_school_pop(SCH_POP), # SCH_POP 변수에 따라 색상 매핑
    # fillOpacity = 0.3,                           # 채우기 투명도
    fillOpacity = ~ifelse(SCH_POP < 5, 0, 0.5), # 채우기 투명도(학령인구 0이면 투명도 0으로)
    # --- 경계 테두리 연하게 설정 ---
    color = "#888888",             # 연한 회색/테두리 색상
    weight = 0.2,                  # 매우 얇은 테두리 두께
    opacity = 0.5,                 # 테두리 투명도
    # --- 마우스 오버 및 팝업 설정 ---
    label = ~paste0("학령인구: ", round(SCH_POP), "명"), # 추정한 학령인구 정수로 표시
    highlightOptions = highlightOptions(
      weight = 1,
      color = "#000000",
      # fillOpacity = 0.5,
      bringToFront = FALSE
    )
  ) %>%

  # 2-1. 레이어 컨트롤 추가
  addLayersControl(
    baseGroups = c("OpenStreetMap", "Esri 위성지도"),
    overlayGroups = 
      c("양산시 행정동 경계", "물금읍 경계", "초중등학교", "학교에서 도보5분", "학원교습소", "격자별 학령인구"),
    options = layersControlOptions(collapsed = FALSE)
  ) %>%
  hideGroup(c("Esri 위성지도", "격자별 학령인구")) %>%
  
  # 2-2. 격자별 학령인구 범례
  addLegend(
    pal = bin_school_pop,
    values = school_pop_4326$SCH_POP,
    group = "격자별 학령인구",
    title = "학령인구 (명)",
    position = "bottomright",
    opacity = 0.5
  ) %>%
  setView(lng_mulgeum, lat_mulgeum, zoom = 13)
map


# 3. HTML 파일 최소화 및 자원 외부 폴더 분리 저장
saveWidget(
  widget = map, 
  file = "index.html",   
  selfcontained = FALSE,
  libdir = "lib"  # JS, CSS 자원이 저장될 폴더 이름
)