
# 1. Install and prepare the analysis package (tmap version)

# install.packages("dplyr")   # Install once and comment out(#)
# install.packages("sf")      # Install once and comment out(#)
# install.packages("tmap")    # Install once and comment out(#)

library(dplyr)        # Data processing: mutate(), etc.
library(sf)           # Spatial data processing: st_read(), etc.
library(tmap)         # tmap visualization: tm_shape(), etc.

# Specify the project folder
prj_dir <- "C:/SGIS/R/Ranking of Youth Population in Seoul by Grid"


# 2. Create grid boundaries that overlap the Seoul city boundary.

# Seoul metropolitan city boundary
file_path <- paste(prj_dir, "bnd_sido_11_2025_2Q.shp", sep="/")
bord_sido <- st_read(file_path)
# Read boundaries, including spatial information in geometry columns

# Seoul's cities, counties, and districts boundaries
file_path <- paste(prj_dir, "bnd_sigungu_11_2025_2Q.shp", sep="/")
bord_sigungu <- st_read(file_path)

# 1km grid boundaries(‘Dasa’) including Seoul
file_path <- paste(prj_dir, "grid_Dasa_1K.shp", sep="/")
bord_grid <- st_read(file_path)

# Save only grid boundaries that overlap with the Seoul boundary
bord_intersects <- 
  st_join(bord_grid, bord_sido, join=st_intersects, left=FALSE)      

# Check grid boundaries that overlap with the Seoul boundary on the map.
map_intersects <- 
  tm_shape(bord_sido) + tm_borders(lwd=2.0, col="black") +
  tm_shape(bord_intersects) + tm_borders(lty="dotted", lwd=0.8, col="blue")
# Specify line type (lty), width (lwd), and color

map_intersects # Check the map in the 'Plots' tap


# 3. Extract youth population statistics

file_path <- paste(prj_dir, "Population_Dasa_1K_2024.csv", sep="/")
stat <- read.csv(file=file_path, header=FALSE, fileEncoding="CP949")
# Specify the encoding of the statistics file including Korean as 'CP949’

colnames(stat) <- c("BASE_YEAR", "GRID_CODE", "STAT_CODE", "STAT_VAL")
# Specify the column names in the statistics file

head(stat) # Check the column names and data in the statistics file

sort(unique(stat[ , "STAT_CODE"]))
# Check the statistical code (5-year-old, age group, total population, etc.)

stat_young <- stat[stat$STAT_CODE=="in_grp_005", ] # in_grp_005 or in_age_005
# Separately save youth population statistics

sort(unique(stat_young[ , "STAT_CODE"]))
# Check the youth population column save


# 4. Join boundaries and statistics and calculate overall ranking

# Set data for boundaries and statistics and specify key columns
join <- merge(x=bord_intersects, y=stat_young,
                by.x="GRID_CD", by.y="GRID_CODE", all.x=TRUE)
# all.x=TRUE: Leave the boundary(x) even if the statistics(y) does not match

join # Check the joined results

# Clean up unnecessary columns and fill in BASE_YEAR for the NULL values.
join <- join %>% select(-BASE_DATE, -SIDO_CD, -SIDO_NM, -STAT_CODE)
join$BASE_YEAR <- "2024"

# Add a rank column
join_rank <- join %>% mutate(RANK = min_rank(desc(STAT_VAL)))

# Check that the rank column has been added
join_rank


# 5. Calculate top rankings

# Top N ranking calculation
topN <- 5 # Top N rank variable

# Save top rankings
join_topN <-  
  join_rank[join_rank$RANK <= topN & ! is.na(join_rank$RANK), ]

# Map including top N rankings
map_topN <-
  # 1. Grid boundaries(overall rank)
  tm_shape(join_rank) + tm_borders(lty="dotted", lwd=0.8, col="red") +
  # 2. Seoul Metropolitan city boundary
  tm_shape(bord_sido) + tm_borders(lty="solid", lwd=2.0, col="black") +
  # 3. Grid boundaries(Top N rank)
  tm_shape(join_topN) + tm_borders(lty="solid", lwd=2.0, col="blue") + 
    tm_text(text="RANK", col="black")


map_topN # Check the intermediate results of the map


# 6. Visualize Choropleth Maps and Grid Rankings of Youth Population 

map_all <-   
  # 1. Grid boundaries(overall ranking)
  tm_shape(join_rank) +
  tm_polygons(fill="STAT_VAL", lty="dotted", 
    fill.legend=tm_legend(title="Youth Population(Pers.)", position=c("left", "top"),
                          text.size=0.6, title.size=0.8), 
    fill.scale=tm_scale_intervals(breaks=c(1, 5000, 10000, 15000, 20000, 24000),
      labels=c("1~5,000","5,000~10,000","10,000~15,000","15,000~20,000","20,000~24,000"),
      values=c("#FFFFB2","#FECC5C","#FD8D3C","#F03B20","#BD0026"),
      # values="brewer.yl_or_rd", # list of color codes or pre-defined palette
      value.na="white", label.na="")) +
  # 2. Seoul metropolitan city boundary
  tm_shape(bord_sido) + tm_borders(lwd=2.0, col="black") +       
  # 3. Seoul city/county/district boundaries
  tm_shape(bord_sigungu) + tm_borders(lwd=1.0, col="black") +
    tm_text(text="SIGUNGU_NM", col="black", size=0.8, col_alpha=0.7) +
  # 4. Grid boundaries(Top N rank)
  tm_shape(join_topN) + tm_borders(lwd=2.0, col="blue") +
    tm_text(text="RANK", col="white", size=0.6) +
  # 5. Title and Layout
  tm_title(text="Ranking of Youth Population in Seoul by Grid(2024)") +
  tm_layout(inner.margins=0.1)
  

map_all  # Check the entire map in the 'Plots' tab


# 7. Save the map as an image file

# Save the map as an image file
file_path <- paste(prj_dir, "Rank of Youth Pop in Seoul by Grid(2024).png", sep="/")
tmap_save(tm=map_all, filename=file_path, width=1800, height=1500, dpi=300)
# Specify width, height(in pixels), and resolution

# Save boundaries as SHP files(overall rank, top N rank)
file_path <- paste(prj_dir, "Rank of Youth Pop in Seoul by Grid(2024).shp", sep="/")
st_write(join_rank, dsn=file_path, append=FALSE, layer_options="ENCODING=UTF-8")
# Specify the appropriate encoding for Korean characters(e.g., “UTF-8” or “CP949”)

file_path <- paste(prj_dir, "Rank of Youth Pop in Seoul by Grid(2024) TopN.shp", sep="/")
st_write(join_topN, dsn=file_path, append=FALSE, layer_options="ENCODING=UTF-8")

