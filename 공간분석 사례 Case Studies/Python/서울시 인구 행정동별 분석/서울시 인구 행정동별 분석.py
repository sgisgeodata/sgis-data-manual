import geopandas as gpd  # 지리정보 파일 읽고 처리
import pandas as pd  # 표 형식 데이터 처리
import matplotlib.pyplot as plt  # 그래프, 지도 등 시각화

plt.rcParams['font.family'] = 'Malgun Gothic'  # 윈도우에서 한글 폰트 설정

prj_dir = 'C:/SGIS/Python/서울시 인구 행정동별 분석'
bord_sido = gpd.read_file(prj_dir + '/' + 'bnd_dong_11_2025_2Q.shp')

stat = pd.read_csv(prj_dir + '/' + '11_2024년_인구총괄(총인구).csv',
                   names=['BASE_YEAR', 'ADM_CD', 'STAT_CD', 'POP'])

print(bord_sido.head())  # 기준날짜(BASE_DATE), 행정구역 이름(ADM_NM), 
                         # 행정구역 코드(ADM_CD), 지리정보(geometry)로 구성

print(stat.head())  # 기준년도(BASE_YEAR), 행정구역 코드(ADM_CD), 
                    # 통계 코드(STAT_CD), 인구수(POP)

# STAT_CD 열에 있는 고유 값 확인
unique_stat_cd = stat['STAT_CD'].unique()
print(unique_stat_cd)

# 총인구('to_in_001') 데이터만 필터링 
stat_total = stat[stat['STAT_CD'] == 'to_in_001']

# 필터링 후 STAT_CD 고유값 재확인
unique_stat_cd = stat_total['STAT_CD'].unique()
print(unique_stat_cd)

stat_total = stat_total[['ADM_CD', 'POP']]

print(bord_sido.dtypes)  # 경계(bord_sido) 각 열의 데이터 타입 확인

print(stat_total.dtypes)  # 통계(stat_total) 각 열의 데이터 타입 확인

stat_total['ADM_CD'] = stat_total['ADM_CD'].astype(str)  # 문자열로 변환

bord_sido = bord_sido.merge(stat_total, on='ADM_CD', how='left')

print(bord_sido.isna().sum())  # 결측값이 있는지 확인
print(bord_sido.head()) # 병합 데이터 미리보기

print(bord_sido['POP'].min(), bord_sido['POP'].max())  # 최소값과 최대값 확인하기

bins = [10, 10000, 20000, 30000, 40000, 52000]  # 적절한 구간 지정
labels = ['10~10,000', '10,000~20,000', '20,000~30,000', '30,000~40,000', '40,000~52,000']  # 구간의 라벨

bord_sido['POP_BINS'] = pd.cut(bord_sido['POP'], bins=bins, labels=labels, right=False)
print(bord_sido.head())  # 인구 구간(‘POP_BINS’) 컬럼 추가 확인

# 시각화 설정(그림과 축 설정)
fig, ax = plt.subplots(1, 1, figsize=(12, 12))

# 지도 시각화(‘POP_BINS’ 컬럼을 기준으로 'OrRd' 색상 맵 사용)
bord_sido.plot(column='POP_BINS', ax=ax, legend=True, cmap='OrRd')

# 서울시 행정동 경계 추가 (경계선만 보이도록 설정, 배경은 투명)
bord_sido.plot(ax=ax, color='none', edgecolor='black', linewidth=0.5) 

# (추가) 서울시 시군구 경계를 추가하여 명확하게 분석하기
bord_sgg = gpd.read_file(prj_dir + '/' + 'bnd_sigungu_11_2025_2Q.shp')

bord_sgg.plot(ax=ax, color='none', edgecolor='black', linewidth=2) 
  
bord_sgg['centroid'] = bord_sgg.geometry.centroid  # 중심점 계산
for idx, row in bord_sgg.iterrows():
    ax.text(row['centroid'].x, row['centroid'].y, row['SIGUNGU_NM'],
            fontsize=15, ha='center', color='black',
            bbox=dict(facecolor='white', alpha=0.7, edgecolor='none', boxstyle='round,pad=0.1'))
# (추가 끝)

# 범례 위치 및 제목 설정
ax.get_legend().set_bbox_to_anchor((0.5, -0.05))  # 범례 위치 조정
ax.get_legend().set_title("<인구 범위>")  # 범례 제목 설정
ax.set_title('<서울시 인구 행정동별 분석>', fontsize=24) # 지도 제목 설정

# 레이아웃 조정 및 출력
plt.tight_layout()  # 그래프 레이아웃이 겹치지 않도록 자동 조정
plt.savefig(prj_dir + '/' + '서울시 인구 행정동별 분석 지도.png')
plt.show()  # 시각화 결과 화면에 출력

