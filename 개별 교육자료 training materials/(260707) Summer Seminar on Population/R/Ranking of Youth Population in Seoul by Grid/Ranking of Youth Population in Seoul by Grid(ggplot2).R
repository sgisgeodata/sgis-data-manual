
# 1. Install and prepare the analysis package (ggplot2 version)

# install.packages("dplyr")   # Install once and comment out(#)
# install.packages("sf")      # Install once and comment out(#)
# install.packages("ggplot2") # Install once and comment out(#)

library(dplyr)        # Data processing: mutate(), etc.
library(sf)           # Spatial data processing: st_read(), etc.
library(ggplot2)      # ggplot2 visualization: ggplot(), etc

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
map_intersects <- ggplot() + 
  geom_sf(data=bord_sido, color="black", fill=NA, linewidth=1.0) +
  geom_sf(data=bord_intersects, color="blue", fill=NA, linetype="dotted") + 
  theme_bw() + theme(axis.title = element_blank()) # deleting axis title(x, y)

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
map_topN <- ggplot() +
  # 1. Grid boundaries(overall rank)
  geom_sf(data=join_rank, color="red", fill=NA, linetype="dotted") +
  # 2. Seoul Metropolitan city boundary
  geom_sf(data=bord_sido, color="black", fill=NA, linewidth=1.0) +
  # 3. Grid boundaries(Top N rank)
  geom_sf(data = join_topN, color="blue", linewidth = 1) +
  geom_sf_text(data = join_topN, mapping = aes(label = RANK)) +
  theme_bw() + theme(axis.title = element_blank())

map_topN # Check the intermediate results of the map


# 6. Visualize Choropleth Maps and Grid Rankings of Youth Population 

# Create an interval range column
join_rank$BREAKS <- 
  cut(join_rank$STAT_VAL, breaks = c(1, 5000, 10000, 15000, 20000, 24000),
    labels = c("1~5,000","5,000~10,000","10,000~15,000","15,000~20,000","20,000~24,000"))

map_all <- ggplot() +
  # 1. Grid boundaries(overall ranking)
  geom_sf(data=join_rank, mapping=aes(fill=BREAKS), linetype = "dotted") +
  scale_fill_manual(values=c("#FFFFB2","#FECC5C","#FD8D3C","#F03B20","#BD0026"),
    na.value="white", na.translate=FALSE, name="Youth Population(Pers.)") +
  # 2. Seoul metropolitan city boundary
  geom_sf(data=bord_sido, color="black", fill=NA, linewidth=1) + 
  # 3. Seoul city/county/district boundaries
  geom_sf(data=bord_sigungu, color="black", fill=NA, linewidth=0.5) +
  geom_sf_text(data=bord_sigungu, mapping=aes(label=SIGUNGU_NM), alpha=0.7, size=3.2) +
  # 4. Grid boundaries(Top N rank)
  geom_sf(data=join_topN, color="blue", fill= NA, linewidth = 1.0) +
  geom_sf_text(data=join_topN, mapping=aes(label = RANK), color="white", size=2.5) +
  # 5. Title and Layout
  ggtitle("Ranking of Youth Population in Seoul by Grid(2024)") +
  theme_bw() + #  deleting axis title, axis text, etc.
  theme(axis.title=element_blank(), axis.text=element_blank(),
        axis.ticks=element_blank(), panel.grid=element_blank())
 
map_all  # Check the entire map in the 'Plots' tab


# 7. Save the map as an image file

# Save the map as an image file
file_path <- paste(prj_dir, "Rank of Youth Pop in Seoul by Grid(2024).png", sep="/")
ggsave(map_all, filename=file_path, width=2100, height=1500, units="px", dpi=300)
# Specify width, height(in pixels), if necessary

# Save boundaries as SHP files(overall rank, top N rank)
file_path <- paste(prj_dir, "Rank of Youth Pop in Seoul by Grid(2024).shp", sep="/")
st_write(join_rank, dsn=file_path, append=FALSE, layer_options="ENCODING=UTF-8")
# Specify the appropriate encoding for Korean characters(e.g., “UTF-8” or “CP949”)

file_path <- paste(prj_dir, "Rank of Youth Pop in Seoul by Grid(2024) TopN.shp", sep="/")
st_write(join_topN, dsn=file_path, append=FALSE, layer_options="ENCODING=UTF-8")

