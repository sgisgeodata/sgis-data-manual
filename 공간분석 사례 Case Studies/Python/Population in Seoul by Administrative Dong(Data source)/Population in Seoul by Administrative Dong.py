import geopandas as gpd  # Reading and processing geographic information files
import pandas as pd  # Processing tabular data
import matplotlib.pyplot as plt  # Visualizations such as graphs and maps

plt.rcParams['font.family'] = 'Malgun Gothic'  # Setting Korean fonts in Windows

prj_dir = 'C:/SGIS/Python/Population in Seoul by Administrative Dong'
bord_sido = gpd.read_file(prj_dir + '/' + 'bnd_dong_11_2025_2Q.shp')

stat = pd.read_csv(prj_dir + '/' + 'Total_Population_11_2024.csv',
                   names=['BASE_YEAR', 'ADM_CD', 'STAT_CD', 'POP'])

print(bord_sido.head())  # base date(BASE_DATE), administrative dong code(ADM_CD),
                                 # administrative dong name(ADM_NM), geographic info(geometry)

print(stat.head())  # base year(BASE_YEAR), administrative dong code(ADM_CD)
                         # statistical code(STAT_CD), population(POP)

# Check the unique values in the 'STAT_CD' column
unique_stat_cd = stat['STAT_CD'].unique()
print(unique_stat_cd)

# Filter only total population('to_in_001') data
stat_total = stat[stat['STAT_CD'] == 'to_in_001']

# Check the unique values in the 'STAT_CD' column after filtering
unique_stat_cd = stat_total['STAT_CD'].unique()
print(unique_stat_cd)

stat_total = stat_total[['ADM_CD', 'POP']]

print(bord_sido.dtypes)  # Check data type of each column in bord_sido

print(stat_total.dtypes)  # Check data type of each column in stat_total

stat_total['ADM_CD'] = stat_total['ADM_CD'].astype(str)  # Convert to string

bord_sido = bord_sido.merge(stat_total, on='ADM_CD', how='left')

print(bord_sido.isna().sum())  # Check if there are missing values
print(bord_sido.head())  # Preview merged data

print(bord_sido['POP'].min(), bord_sido['POP'].max())  # Check the minimum, maximum values

bins = [25, 10000, 20000, 30000, 40000, 53000]  # Specify appropriate intervals and labels
labels = ['25~10,000', '10,000~20,000', '20,000~30,000', '30,000~40,000', '40,000~53,000']

bord_sido['POP_BINS'] = pd.cut(bord_sido['POP'], bins=bins, labels=labels, right=False)
print(bord_sido.head())  # Check the addition of the population interval('POP_BINS') column

# Visualization settings(figure and axis)
fig, ax = plt.subplots(1, 1, figsize=(12, 12))

# Map visualization(Use 'OrRd' color map based on 'POP_BINS' column)
bord_sido.plot(column='POP_BINS', ax=ax, legend=True, cmap='OrRd')

# Overlaying administrative dong boundaries(Borders only, no fill)
bord_sido.plot(ax=ax, color='none', edgecolor='black', linewidth=0.5) 

# (Optional) Overlaying Municipality(Sigungu) boundaries of Seoul
bord_sgg = gpd.read_file(prj_dir + '/' + 'bnd_sigungu_11_2025_2Q.shp')

bord_sgg.plot(ax=ax, color='none', edgecolor='black', linewidth=2) 
  
bord_sgg['centroid'] = bord_sgg.geometry.centroid  # Calculate the center point
for idx, row in bord_sgg.iterrows():
    ax.text(row['centroid'].x, row['centroid'].y, row['SIGUNGU_NM'],
        fontsize=15, ha='center', color='black',
        bbox=dict(facecolor='white', alpha=0.7, edgecolor='none', boxstyle='round,pad=0.1'))

# Setting the legend title and position
ax.get_legend().set_bbox_to_anchor((0.5, -0.05))  # Adjust legend position
ax.get_legend().set_title('Population (Persons)')  # Set legend title
ax.set_title('Population in Seoul by Administrative Dong', fontsize=24)  # Set map title
ax.set_xtick([]) # Remove x-axis number and ticks
ax.set_ytick([]) # Remove y-axis number and ticks

# Layout adjustment and Display
plt.tight_layout()  # Automatically adjusts the layout of graphs to avoid overlapping
plt.savefig(prj_dir + '/' + 'Population in Seoul by Administrative Dong.png')
plt.show()  # Displays the final map

