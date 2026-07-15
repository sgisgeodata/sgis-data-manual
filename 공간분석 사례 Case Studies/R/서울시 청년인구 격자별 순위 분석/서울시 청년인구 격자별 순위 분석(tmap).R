
# 1. 분석 패키지 설치 및 사용준비(tmap 버전)

# install.packages("dplyr")   # 한번 설치하고 주석처리(#) 하기
# install.packages("sf")      # 한번 설치하고 주석처리(#) 하기
# install.packages("tmap")    # 한번 설치하고 주석처리(#) 하기

library(dplyr)        # 데이터 처리: mutate() 등
library(sf)           # 공간 데이터 처리: st_read() 등
library(tmap)         # tmap 시각화: tm_shape() 등

# 프로젝트 폴더 지정
prj_dir <- "C:/SGIS/R/서울시 청년인구 격자별 순위 분석"


# 2. 서울시 경계와 겹치는 격자 경계 만들기

# 서울시 시도 경계
file_path <- paste(prj_dir, "bnd_sido_11_2025_2Q.shp", sep="/")
bord_sido <- st_read(file_path) # 경계 읽어들이기, geometry 컬럼에 공간정보 포함

# 서울시 시군구 경계
file_path <- paste(prj_dir, "bnd_sigungu_11_2025_2Q.shp", sep="/")
bord_sigungu <- st_read(file_path)

# 서울시를 포함하는 1km 격자 경계('다사')
file_path <- paste(prj_dir, "grid_다사_1K.shp", sep="/")
bord_grid <- st_read(file_path)

# 서울시 경계와 겹치는 격자 경계만 저장
bord_intersects <- 
  st_join(bord_grid, bord_sido, join=st_intersects, left=FALSE)      

# 서울시와 겹치는 격자 경계를 지도에서 확인
map_intersects <- 
  tm_shape(bord_sido) + tm_borders(lwd=2.0, col="black") +
  tm_shape(bord_intersects) + tm_borders(lty="dotted", lwd=0.8, col="blue")
# 선종류(lty), 너비(lwd), 색상 지정

map_intersects # 지도를 'Plots' 탭에서 확인


# 3. 청년인구 통계 선별하기

file_path <- paste(prj_dir, "2024년_인구_다사_1K.csv", sep="/")
stat <- read.csv(file=file_path, header=FALSE, fileEncoding="CP949")
# 한글을 포함한 통계 파일의 인코딩을 'CP949'로 지정

colnames(stat) <- c("BASE_YEAR", "GRID_CODE", "STAT_CODE", "STAT_VAL")
# 통계파일의 컬럼명 지정

head(stat) # 통계파일의 컬럼명과 데이터 확인

sort(unique(stat[ , "STAT_CODE"]))
# 통계코드 종류 확인(5세연령 인구, 연령그룹 인구, 총인구 등)

stat_young <- stat[stat$STAT_CODE=="in_age_005", ] # in_grp_005 또는 in_age_005 
# 청년인구 통계를 별도로 저장

sort(unique(stat_young[ , "STAT_CODE"]))
# 컬럼 저장 확인


# 4. 경계와 통계 조인하고 순위 계산하기

# 경계와 통계 데이터셋과 key 컬럼 지정
join <- merge(x=bord_intersects, y=stat_young,
                by.x="GRID_CD", by.y="GRID_CODE", all.x=TRUE)
# all.x=TRUE: 통계값(y)이 매칭되지 않아도 경계(x)는 남기기

join # 조인 결과 확인

# 불필요한 컬럼 정리, 기준연도(BASE_YEAR) NULL값 채우기
join <- join %>% select(-BASE_DATE, -SIDO_CD, -SIDO_NM, -STAT_CODE)
join$BASE_YEAR <- "2024"

# RANK(순위) 컬럼 추가
join_rank <- join %>% mutate(RANK = min_rank(desc(STAT_VAL)))

# RANK 컬럼 추가 확인
join_rank


# 5. 상위 순위 계산하기

# Top N 순위 계산
topN <- 5 # 상위 순위 N

# 상위 순위 저장
join_topN <-  
  join_rank[join_rank$RANK <= topN & ! is.na(join_rank$RANK), ]

# Top N 순위 포함한 지도
map_topN <-
  # 1. 격자 경계(전체 순위)
  tm_shape(join_rank) + tm_borders(lty="dotted", lwd=0.8, col="red") +
  # 2. 서울시 시도 경계
  tm_shape(bord_sido) + tm_borders(lty="solid", lwd=2.0, col="black") +
  # 3. 격자 경계(상위 순위)
  tm_shape(join_topN) + tm_borders(lty="solid", lwd=2.0, col="blue") + 
    tm_text(text="RANK", col="black")


map_topN # 지도 중간 결과 확인


# 6. 청년인구 단계구분도와 격자순위 시각화

map_all <-   
  # 1. 격자 경계(전체 순위)
  tm_shape(join_rank) +
  tm_polygons(fill="STAT_VAL", lty="dotted", 
    fill.legend=tm_legend(title="격자별 청년인구(명)", position=c("left", "top")), 
    fill.scale=tm_scale_intervals(breaks=c(1, 500, 1000, 3000, 5000, 7000),    # 수정
      labels=c("1~500","500~1,000","1,000~3,000","3,000~5,000","5,000~7,000"), # 수정
      values=c("#FFFFB2","#FECC5C","#FD8D3C","#F03B20","#BD0026"), # 색상 코드 열거
      # values="brewer.yl_or_rd", # 또는 색상 파레트 지정
      value.na="white", label.na="")) +
  # 2. 서울시 시도 경계
  tm_shape(bord_sido) + tm_borders(lwd=2.0, col="black") +       
  # 3. 서울시 시군구 경계
  tm_shape(bord_sigungu) + tm_borders(lwd=1.0, col="black") +
    tm_text(text="SIGUNGU_NM", col="black", size=1.0, col_alpha=0.7) +
  # 4. 격자 경계(상위 순위)
  tm_shape(join_topN) + tm_borders(lwd=2.0, col="blue") +
    tm_text(text="RANK", col="white", size=0.6) +
  # 5. 제목과 레이아웃
  tm_title(text="2024년 서울시 청년인구 격자 순위") +
  tm_layout(inner.margins=0.1, text.fontfamily = "Malgun Gothic")
  

map_all  # 전체 맵을 'Plots' 탭에서 확인


# 7. 지도 그림과 경계파일 저장하기

# 지도를 그림파일로 저장
file_path <- paste(prj_dir, "2024년 서울시 청년인구 격자별 순위.png", sep="/")
tmap_save(tm=map_all, filename=file_path, width=1800, height=1500, dpi=300)
# 너비, 높이(픽셀 단위), 해상도 지정

# 경계를 SHP 파일로 저장(전체 격자, 상위순위 격자)
file_path <- paste(prj_dir, "2024년 서울시 청년인구 격자별 순위.shp", sep="/")
st_write(join_rank, dsn=file_path, append=FALSE, layer_options="ENCODING=UTF-8")
# 한글을 포함한 파일을 저장할 때 적절한 인코딩 지정('UTF-8' 또는 'CP949' 등)

file_path <- paste(prj_dir, "2024년 서울시 청년인구 격자별 순위 TopN.shp", sep="/")
st_write(join_topN, dsn=file_path, append=FALSE, layer_options="ENCODING=UTF-8")

