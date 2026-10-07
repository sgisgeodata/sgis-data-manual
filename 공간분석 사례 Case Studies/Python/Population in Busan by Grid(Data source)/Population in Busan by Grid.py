import geopandas as gpd  # Reading and processing geographic information files
import pandas as pd  # Processing tabular data
import matplotlib.pyplot as plt  # Visualizations such as graphs and maps

plt.rcParams['font.family'] = 'Malgun Gothic'  # Setting Korean fonts in Windows

prj_dir = 'C:/SGIS/Python/Population in Busan by Grid'

bord_sido = gpd.read_file(prj_dir + '/' + 'bnd_sido_21_2025_2Q.shp')
grid_Mara = gpd.read_file(prj_dir + '/' + 'grid_Mara_1K.shp')
grid_Mama = gpd.read_file(prj_dir + '/' + 'grid_Mama_1K.shp')
stat_Mara = pd.read_csv(prj_dir + '/' + 'Population_Mara_1K_2024.csv', encoding='CP949',
                       names=['BASE_YEAR', 'GRID_CD', 'STAT_CD', 'POP'])
stat_Mama = pd.read_csv(prj_dir + '/' + 'Population_Mama_1K_2024.csv', encoding='CP949',
                       names=['BASE_YEAR', 'GRID_CD', 'STAT_CD', 'POP'])

grid_merged = pd.concat([grid_Mara, grid_Mama], ignore_index=True)
stat_merged = pd.concat([stat_Mara, stat_Mama], ignore_index=True)

print(grid_merged.info())  # grid code(GRID_CD) and geographic info(geometry)
print(stat_merged.info())  # base year(BASE_YEAR), grid code(GRID_CD),
                                   # statistical code(STAT_CD), population(POP)

# Check the unique values ​​in the STAT_CD column
unique_stat_cd = stat_merged['STAT_CD'].unique()
print(unique_stat_cd)

stat_total = stat_total[['GRID_CD', 'POP']]

grid_intersects = grid_merged[grid_merged.geometry.intersects(bord_sido.geometry.union_all())]
grid_intersects = grid_intersects.merge(stat_total, on='GRID_CD', how='left')

# After combining, check for missing values(there may be NaNs in the merged data)
print(grid_intersects.isna().sum())

# Fill missing values ​​with 0
grid_intersects['POP'] = grid_intersects['POP'].fillna(0)

# Dividing by directly specifying population segments
print(grid_intersects['POP'].min(), grid_intersects['POP'].max())  # Minimum, maximum values

bins = [0, 1000, 5000, 10000, 20000, 32000]  # Specify appropriate intervals and labels
labels = ['0~1,000', '1,000~5,000', '5,000~10,000', '10,000~20,000', '20,000~32,000']

# allocating population brackets
grid_intersects['POP_BINS'] = pd.cut(grid_intersects['POP'], bins=bins, labels=labels, right=False)
print(grid_intersects.head())  # Check the population interval ('POP_BINS') column


# Visualization settings(figure and axis)
fig, ax = plt.subplots(1, 1, figsize=(12, 12))

# Grid visualization(Set the grid border to light)
grid_intersects.plot(column='POP_BINS', ax=ax, legend=True, 
                     cmap='OrRd', edgecolor='black', linewidth=0.5, alpha=0.7)

# Overlaying Busan city boundary(Borders only, no fill)
bord_sido.plot(ax=ax, color='none', edgecolor='black', linewidth=2)  

# (Optional) Overlaying Municipality(Sigungu) boundaries of Busan
bord_sgg = gpd.read_file(prj_dir + '/' + 'bnd_sigungu_21_2025_2Q.shp')

bord_sgg.plot(ax=ax, color='none', edgecolor='black', linewidth=2) 
  
bord_sgg['centroid'] = bord_sgg.geometry.centroid  # Calculate the center point
for idx, row in bord_sgg.iterrows():
    ax.text(row['centroid'].x, row['centroid'].y, row['SIGUNGU_NM'], fontsize=15, ha='center', 
        color='black', bbox=dict(facecolor='white', alpha=0.7, edgecolor='none', 
        boxstyle='round,pad=0.1'))

# Calculate the center point
ax.get_legend().set_bbox_to_anchor((0.5, -0.05))  # Adjust legend position
ax.get_legend().set_title('Population (Persons)')  # Set legend title
ax.set_title('Population in Busan by Grid', fontsize=16)  # Set map title
ax.set_xtick([]) # Remove x-axis number and ticks
ax.set_ytick([]) # Remove y-axis number and ticks

# Layout adjustment and Display
plt.tight_layout()  # Automatically adjusts the layout of graphs to avoid overlapping
plt.savefig(prj_dir + '/' + 'Population in Busan by Grid.png')
plt.show()  # Displays the final map

