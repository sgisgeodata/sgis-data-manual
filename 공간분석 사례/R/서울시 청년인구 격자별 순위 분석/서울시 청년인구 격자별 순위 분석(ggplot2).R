
# 1. 분석 패키지 설치 및 사용준비(ggplot2 버전)

# install.packages("dplyr")   # 한번 설치하고 주석처리(#) 하기
# install.packages("sf")      # 한번 설치하고 주석처리(#) 하기
# install.packages("ggplot2") # 한번 설치하고 주석처리(#) 하기

library(dplyr)        # 데이터 처리: mutate() 등
library(sf)           # 공간 데이터 처리: st_read() 등
library(ggplot2)      # ggplot2 시각화: ggplot() 등

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
map_intersects <- ggplot() + 
  geom_sf(data=bord_sido, color="black", fill=NA, linewidth=1.0) +
  geom_sf(data=bord_intersects, color="blue", fill=NA, linetype="dotted") + 
  theme_bw() + theme(axis.title = element_blank()) # 축 제목(x, y) 제거

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
# 청년인구('in_grp_005' 컬럼) 저장 확인


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
map_topN <- ggplot() +
  # 1. 격자 경계(전체 순위)
  geom_sf(data=join_rank, color="red", fill=NA, linetype="dotted") +
  # 2. 서울시 시도 경계
  geom_sf(data=bord_sido, color="black", fill=NA, linewidth=1.0) +
  # 3. 격자 경계(상위 순위)
  geom_sf(data = join_topN, color="blue", linewidth = 1) +
  geom_sf_text(data = join_topN, mapping = aes(label = RANK)) +
  theme_bw() + theme(axis.title = element_blank())

map_topN # 지도 중간 결과 확인


# 6. 청년인구 단계구분도와 격자순위 시각화

# 통계값의 구간 범위 컬럼 만들기
join_rank$BREAKS <- 
  cut(join_rank$STAT_VAL, breaks = c(1, 500, 1000, 3000, 5000, 7000),          # 수정
    labels = c("1~500","500~1,000","1,000~3,000","3,000~5,000","5,000~7,000")) # 수정

map_all <- ggplot() +
  # 1. 격자 경계(전체 순위)
  geom_sf(data=join_rank, mapping=aes(fill=BREAKS), linetype = "dotted") +
  scale_fill_manual(values=c("#FFFFB2","#FECC5C","#FD8D3C","#F03B20","#BD0026"),
    na.value="white", na.translate=FALSE, name="격자별 청년인구(명)") +
  # 2. 서울시 시도 경계
  geom_sf(data=bord_sido, color="black", fill=NA, linewidth=1) + 
  # 3. 서울시 시군구 경계와 이름
  geom_sf(data=bord_sigungu, color="black", fill=NA, linewidth=0.5) +
  geom_sf_text(data=bord_sigungu, mapping=aes(label=SIGUNGU_NM), alpha=0.7, size=5) +
  # 4. 격자 경계(상위 순위)
  geom_sf(data=join_topN, color="blue", fill= NA, linewidth = 1.0) +
  geom_sf_text(data=join_topN, mapping=aes(label = RANK), color="white") +
  # 5. 제목과 테마 지정
  ggtitle("2024년 서울시 청년인구 격자 순위") +
  theme_bw() + # 축 제목, 축 텍스트 등 제거
  theme(axis.title=element_blank(), axis.text=element_blank(), axis.ticks=element_blank())
 
map_all  # 전체 맵을 'Plots' 탭에서 확인


# 7. 지도 그림과 경계파일 저장하기

# 지도를 그림파일로 저장
file_path <- paste(prj_dir, "2024년 서울시 청년인구 격자별 순위 맵.png", sep="/")
ggsave(map_all, filename=file_path)
# 너비, 높이는 인치 단위로 지정 가능

# 경계를 SHP 파일로 저장(전체 격자, 상위순위 격자)
file_path <- paste(prj_dir, "2024년 서울시 청년인구 격자별 순위.shp", sep="/")
st_write(join_rank, dsn=file_path, append=FALSE, layer_options="ENCODING=UTF-8")
# 한글을 포함한 파일을 저장할 때 적절한 인코딩 지정('UTF-8' 또는 'CP949' 등)

file_path <- paste(prj_dir, "2024년 서울시 청년인구 격자별 순위 TopN.shp", sep="/")
st_write(join_topN, dsn=file_path, append=FALSE, layer_options="ENCODING=UTF-8")

