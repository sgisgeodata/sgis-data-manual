import geopandas as gpd  # 지리정보 파일 읽고 처리
import pandas as pd  # 표 형식 데이터 처리
import matplotlib.pyplot as plt  # 그래프, 지도 등 시각화

plt.rcParams['font.family'] = 'Malgun Gothic'  # 윈도우에서 한글 폰트 설정

prj_dir = 'C:/SGIS/Python/부산시 인구 격자별 분석'

bord_sido = gpd.read_file(prj_dir + '/' + 'bnd_sido_21_2025_2Q.shp')
grid_mara = gpd.read_file(prj_dir + '/' + 'grid_마라_1K.shp')
grid_mama = gpd.read_file(prj_dir + '/' + 'grid_마마_1K.shp')
stat_mara = pd.read_csv(prj_dir + '/' + '2024년_인구_마라_1K.csv', encoding='CP949',
                       names=['BASE_YEAR', 'GRID_CD', 'STAT_CD', 'POP'])
stat_mama = pd.read_csv(prj_dir + '/' + '2024년_인구_마마_1K.csv', encoding='CP949',
                       names=['BASE_YEAR', 'GRID_CD', 'STAT_CD', 'POP'])

grid_merged = pd.concat([grid_mara, grid_mama], ignore_index=True)
stat_merged = pd.concat([stat_mara, stat_mama], ignore_index=True)

print(grid_merged.info())  # 격자 경계 코드(GRID_CD), 지리정보(geometry)로 구성
print(stat_merged.info())  # 기준년도(BASE_YEAR), 격자 경계 코드(GRID_CD), 
                           # 통계 코드(STAT_CD), 인구수(POP)

# STAT_CD 열에 있는 고유 값 확인
unique_stat_cd = stat_merged['STAT_CD'].unique()
print(unique_stat_cd)

# 총인구('to_in_001') 데이터만 필터링
stat_total = stat_merged[stat_merged['STAT_CD'] == 'to_in_001']

# 필터링 후 STAT_CD 고유값 재확인
unique_stat_cd = stat_total['STAT_CD'].unique()
print(unique_stat_cd)

stat_total = stat_total[['GRID_CD', 'POP']]

grid_intersects = grid_merged[grid_merged.geometry.intersects(bord_sido.geometry.union_all())]
grid_intersects = grid_intersects.merge(stat_total, on='GRID_CD', how='left')

# 결합 후 통계값이 없는 구간에 NaN이 들어가 있을 수 있음(결측값 확인)
print(grid_intersects.isna().sum())

# 결측값을 0으로 채우기
grid_intersects['POP'] = grid_intersects['POP'].fillna(0)

# 인구 구간 직접 지정하여 나누기
print(grid_intersects['POP'].min(), grid_intersects['POP'].max())  # 최소값과 최대값 확인

bins = [0, 1000, 5000, 10000, 20000, 32000]  # 적절한 구간 지정
labels = ['0~1000', '1000~5000', '5000~10,000', '10,000~20,000', '20,000~32,000']  # 구간의 라벨

# 각 인구 수에 대해 구간 할당
grid_intersects['POP_BINS'] = pd.cut(grid_intersects['POP'], bins=bins, labels=labels, right=False)
print(grid_intersects.head(100))  # 인구 구간(‘POP_BINS’) 컬럼 추가 확인


# 시각화 설정(그림과 축 설정)
fig, ax = plt.subplots(1, 1, figsize=(12, 12))

# 격자 시각화(격자 경계 선은 연하게 설정)
grid_intersects.plot(column='POP_BINS', ax=ax, legend=True, cmap='OrRd', 
                     edgecolor='black', linewidth=0.5, alpha=0.7)

# 부산시 경계 추가 (경계선만 보이도록 설정, 배경은 투명)
bord_sido.plot(ax=ax, color='none', edgecolor='black', linewidth=2)  

# (추가) 부산시 시군구 경계를 추가하여 명확하게 분석하기
bord_sgg = gpd.read_file(prj_dir + '/' + 'bnd_sigungu_21_2025_2Q.shp')

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
ax.set_title('<부산시 인구 격자별 분석>', fontsize=16) # 지도 제목 설정

# 레이아웃 조정 및 출력
plt.tight_layout()  # 그래프 레이아웃이 겹치지 않도록 자동 조정
plt.savefig(prj_dir + '/' + '부산시 인구 격자별 분석 지도.png')
plt.show()  # 시각화 결과 화면에 출력

