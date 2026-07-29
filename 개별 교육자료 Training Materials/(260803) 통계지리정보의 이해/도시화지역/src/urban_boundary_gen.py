from urban_lib import *

#GPKG 형식 경계 사용 
bordDir = "C:/SGIS/도시화지역/OUTPUT/격자경계_GPKG"
statDir = "C:/SGIS/도시화지역/src/격자인구통계"
grdBrdrHomeDir = "C:/SGIS/도시화지역/src/격자경계_SHP"
outputDir = "C:/SGIS/도시화지역/OUTPUT"
gridLvlList = ['1K']

popGridPath = "pop_grid" 
urbanCenterPath = "urban_center" 
urbanClusterPath = "urban_cluster" 

# baseYearList = ['2024','2023','2022','2021','2020','2019','2018','2017','2016','2015','2010','2005','2000']
baseYearList = ['2024']

# gridLiterals = ['가다','가라','가사','가아','나나','나다','나라','나마','나바','나사'       #가X(4) #나X(6)
# ,'다나','다다','다라','다마','다바','다사','다아','라다','라라','라마','라바','라사','라아'   #다X(7) #라X(6) 
# ,'마라','마마','마바','마사','마아','바사','사사']                                         #마X(5) #바X(1), 사X(1)
gridLiterals = ['다라']
# gridLiterals = ['다라', '다마']

DEBUGGING = True # 세부사항 디버깅할 때만 True
# DEBUGGING = False

#BN for Base Name
pop_grid_BN             = 'pop_grid'
pop1500_BN              = 'pop1500'
pop1500_gid_BN          = 'pop1500_gid'
pop1500_group_BN        = 'pop1500_group'
pop1500_group_sum_BN    = 'pop1500_group_sum'
urban_center_group_BN   = 'urban_center_group'
urban_center_cell_BN    = 'urban_center_cell'

touch_cell_BN           = 'touch_cell'
touch_cell_tmp_BN       = 'touch_cell_tmp'  #빼기(difference) 과정에서 만들어지는 임시 레이어
gap_fill_BN             = 'gap_fill'

#준도시용 레이어
pop300_BN               = 'pop300'
pop300_group_BN         = 'pop300_group'
pop300_gid_BN           = 'pop300_gid'
urban_cluster_candi_BN  = 'urban_cluster_candi' #urban_cluster_group 후보
urban_cluster_group_BN  = 'urban_cluster_group'

#과정 참고용 레이어 만들고 보여줄지 여부
SHOWLAYER = True
# SHOWLAYER = False

#테스트용으로 진행해보고 싶은 횟수, 20 이상이면 최종 phase까지 진행
PHASEMAX = 30

ID_WIDTH = 4


#도시(urban_center) 만들기
for baseYear in baseYearList:
    popGridDir = getPopGridDir(outputDir, popGridPath)
    urbanCenterDir = getUrbanCenterDir(outputDir, urbanCenterPath, baseYear)
    urbanClusterDir = getUrbanClusterDir(outputDir, urbanClusterPath, baseYear)
    
    logger.debug("baseYear: %s", baseYear)
    print('baseYear: ' + baseYear)
    logger.debug("popGridDir: %s", popGridDir)
    logger.debug("urbanCenterDir: %s", urbanCenterDir)
    logger.debug("urbanClusterDir: %s", urbanClusterDir)
    
    #GPKG 포맷 격자경계(GRID) 만드는 함수
    convertGridLayerGeoPackage(gridLiterals, gridLvlList, grdBrdrHomeDir, bordDir)

    #pop_grid 만들기(자료가 바뀌지 않으면 한번만 만들면 됨, 전국 10~20분 정도 걸림) #pop_grid_YYYY
    createDirectoryIfNotExist(popGridDir)
    makePopGrid(baseYear, gridLiterals, pop_grid_BN, bordDir, statDir, outputDir, popGridDir, False)
    showLayer_suffixed(pop_grid_BN, popGridDir, baseYear)
    
    #도시 영역 만들기(자료가 바뀌지 않으면 한번만 만들면 됨) #urban_center_group_YYYY [pop1500*, gap_fill_NN, urban_center_group_NN]
    createDirectoryIfNotExist(urbanCenterDir)
    makePopLayers(pop_grid_BN, pop1500_BN, pop1500_gid_BN, pop1500_group_BN, pop1500_group_sum_BN, urbanCenterDir, popGridDir, \
    baseYear, False)
    
    makeUrbanCenter(urban_center_group_BN, urban_center_cell_BN, pop1500_gid_BN, pop1500_group_sum_BN, pop_grid_BN, touch_cell_BN, \
    touch_cell_tmp_BN, gap_fill_BN, baseYear, urbanCenterDir, popGridDir, PHASEMAX, False)
    
    #준도시 영역 만들기(도시 영역 만들어진 상태에서 만들기) #urban_cluster_group_YYYY [pop300, pop300_parts, pop300_gid, pop300_group] 
    createDirectoryIfNotExist(urbanClusterDir)
    makePop300(pop_grid_BN, pop300_BN, urbanClusterDir, popGridDir, baseYear, False)
    
    makeUrbanClusterCandi(urban_cluster_candi_BN, pop300_BN, pop300_group_BN, pop300_gid_BN, urbanClusterDir, False)
    makeUrbanClusterGroup(urban_cluster_group_BN, urban_cluster_candi_BN, urban_center_group_BN, baseYear, urbanClusterDir, urbanCenterDir, SHOWLAYER)
    
