import os
from urllib import parse
from qgis.analysis import QgsNativeAlgorithms
import processing
from processing.core.Processing import Processing
import sys
from qgis.core import *
from PyQt5.QtCore import QVariant

from urban_logger import *

def createDirectoryIfNotExist(directory):
    try:
        if not os.path.exists(directory):
            os.makedirs(directory)
    except OSError:
        print("Error: Failed to create the directory.")

#격자경계(GRID) 함수
def convertGridLayerGeoPackageOne(gridLiteral, gridLevel, gridFileHomeDir, bordDir):
    def getGridLiteralFolder(gridLiteral): #grid_다사
        #print('[getGridLiteralFolder: ' + 'grid_' + gridLiteral + ']')
        return 'grid_' + gridLiteral
    def getGridBaseName(gridLiteral, gridLevel): #확장자(.shp) 없음
        return getGridLiteralFolder(gridLiteral) + '_' + gridLevel
    def getGridFileName(gridLiteral, gridLevel):
        return getGridBaseName(gridLiteral, gridLevel) + '.shp'
    def getGridFileFullPath(gridFileHomeDir, gridLiteral, gridLevel):
        #print('[getGridFileName: ' + getGridFileName(gridLiteral, gridLevel) + ']')
        folderName = 'grid_' + gridLiteral
        # logger.debug('getGridFileFullPath - folderName: %s', folderName)
        gridFileName = getGridFileName(gridLiteral, gridLevel)
        # gridFileFullPath = gridFileHomeDir + "/" + folderName + "/" + gridFileName
        gridFileFullPath = gridFileHomeDir + "/" + gridFileName
        # logger.debug('getGridFileFullPath - gridFileFullPath: %s', gridFileFullPath)
        return gridFileFullPath
    def getGpkgFileFullForder(bordDir, gridLiteral, gridLevel):
        return bordDir + '/' + getGridLiteralFolder(gridLiteral)
    def createDirectoryIfNotExist(directory):
        try:
            if not os.path.exists(directory):
                os.makedirs(directory)
        except OSError:
            print("Error: Failed to create the directory.")
    def getGpkgFileFullPath(bordDir, gridLiteral, gridLevel): # <bordDir>/grid_가다/*.gpkg
        return getGpkgFileFullForder(bordDir, gridLiteral, gridLevel) + '/' + getGridBaseName(gridLiteral, gridLevel) + '.gpkg'
    
    def getGpkgFileFullPathSimple(bordDir, gridLiteral, gridLevel): # <bordDir>/*.gpkg
        # logger.debug('getGpkgFileFullPathSimple() - bordDir: %s, getGridBaseName: %s.gpkg', bordDir, getGridBaseName(gridLiteral, gridLevel))
        return bordDir + '/' + getGridBaseName(gridLiteral, gridLevel) + '.gpkg'

    # logger.debug('convertGridLayerGeoPackageOne() - gridLiteral: %s, gridLevel: %s', gridLiteral, gridLevel)
    
    gridBaseName = getGridBaseName(gridLiteral, gridLevel)  #grid_다사_1K
    # logger.debug('convertGridLayerGeoPackageOne - gridBaseName: %s', gridBaseName)
    gridFileFullPath = getGridFileFullPath(gridFileHomeDir, gridLiteral, gridLevel)
    # logger.debug('gridFileFullPath: %s', gridFileFullPath)
    gridLayer = QgsVectorLayer(gridFileFullPath, gridBaseName, "ogr")
    # logger.debug('convertGridLayerGeoPackageOne - bordDir: %s', bordDir)
    createDirectoryIfNotExist(bordDir)
    
    gpkgFileFullPath = getGpkgFileFullPathSimple(bordDir, gridLiteral, gridLevel)
    # logger.debug('gridFileFullPath: %s', gridFileFullPath)
    
    # res = processing.run("gdal:convertformat", {'INPUT': gridLayer, 'OPTIONS' : '--config OGR2OGR_USE_ARROW_API NO', 'OUTPUT': gpkgFileFullPath})
    # res = processing.run("gdal:convertformat", {'INPUT': gridLayer, 'OPTIONS' : '-f "GPKG" -overwrite', 'OUTPUT': gpkgFileFullPath})
    res = processing.run("gdal:convertformat", {'INPUT': gridLayer, 'OPTIONS' : '-overwrite', 'OUTPUT': gpkgFileFullPath})
    

def convertGridLayerGeoPackage(gridLiteralList, gridLevelList, gridFileHomeDir, bordDir):
    for gridLiteral in gridLiteralList:
        for gridLevel in gridLevelList:
            convertGridLayerGeoPackageOne(gridLiteral, gridLevel, gridFileHomeDir, bordDir)


#GPKG 1K 격자 경계파일 읽어들이는 함수
def getBord(bordDir, gridLiteral, outputDir):
    def getBordName(gridLiteral): #확장자(.gpkg) 없음
        return 'grid_' + gridLiteral + '_1K'    #grid_다사_1K
    def getBordFileName(gridLiteral):
        return getBordName(gridLiteral) + '.gpkg'   #grid_다사_1K.gpkg
    def getBordPath(bordDir, gridLiteral):
        return bordDir + "/" + getBordFileName(gridLiteral)  # <bordDir>/grid_다사_1K.gpkg
    def getBordPath4work(outputDir, gridLiteral):
        folderName = 'grid_' + gridLiteral
        return outputDir + "/격자경계_GPKG/" + getBordFileName(gridLiteral)  # <outputHomeDir>/grid_다사_1K.gpkg

    # print('in getBord() bordDir: ' + bordDir + ', gridLiteral: ' + gridLiteral + ', outputDir: ' + outputDir)
    bordName = getBordName(gridLiteral)
    bordPath = getBordPath(bordDir, gridLiteral)
    bordLayer = QgsVectorLayer(bordPath, bordName, "ogr")
    # print('in getBord() bordName: ' + bordName + ', bordPath: ' + bordPath)
    
    bordPath4work = getBordPath4work(outputDir, gridLiteral)
    # print('in getBord() bordPath4work: ' + bordPath4work)
    createDirectoryIfNotExist(outputDir)
    processing.run("gdal:convertformat", {'INPUT': bordLayer, 'OPTIONS' : '-f "GPKG" -overwrite', 'OUTPUT': bordPath4work})
    
    bordLayer4work = QgsVectorLayer(bordPath4work, bordName, "ogr")
    #추가속성(pop 등)이 원본 경계파일에 남아서 작업 폴더에 옮긴 파일로 자료처리
    
    return bordLayer4work

#GPKG 1K 격자 통계파일 총인구(to_in_001) 읽어들이는 함수
#대부분의 경우 참값을 활용 
def getStatPop(statDir, baseYear, gridLiteral, DEBUGGING=False):
    def getStatFileUri(statFileFullPath):
        # return "file:///{}?type=csv&useHeader=No&geomType=none&encoding=UTF-8".format(parse.quote(statFileFullPath))
        return "file:///{}?type=csv&useHeader=No&geomType=none&encoding=CP949".format(parse.quote(statFileFullPath))
    def getStatBaseName(baseYear, gridLiteral):  #확장자(.txt) 없음
        return baseYear + "년_인구_" + gridLiteral + "_1K"  #2021년_인구_다사_1K
    def getStatFileFullPath(statDir, baseYear, gridLiteral):
        def getStatFileName(baseYear, gridLiteral):
            return getStatBaseName(baseYear, gridLiteral) + '.csv' # .csv로 변경
        statFileName = getStatFileName(baseYear, gridLiteral)
        
        # logger.debug("getStatPop() - statDir: %s, statFileName: %s", statDir, statFileName)

        return statDir + "/" + statFileName
    statCode = 'to_in_001'  #총인구 코드    
    statBaseName = getStatBaseName(baseYear, gridLiteral)
    # logger.debug("getStatPop() - statBaseName: %s", statBaseName)
    statFileFullPath = getStatFileFullPath(statDir, baseYear, gridLiteral)
    # logger.debug("getStatPop() - statFileFullPath: %s", statFileFullPath)
    statLayer = QgsVectorLayer(getStatFileUri(statFileFullPath), statBaseName, "delimitedtext")
    if not statLayer.isValid(): 
        print("STAT LAYER IS INVALID(ERROR)") 
        logger.debug("STAT LAYER IS INVALID(ERROR)") 
    
    if DEBUGGING == True: # 디버깅용
        logger.debug("in getStatPop() - statLayer: %s", statLayer)    
        field_names = [ field.name() for field in statLayer.fields() ]
        logger.debug("in getStatPop() - field_names: %s", field_names)
        feat = next(statLayer.getFeatures())
        for name in field_names:
            logging.debug("%s: %s", name, feat[name])
    
    res = processing.run("native:extractbyexpression", {'INPUT': statLayer, 'EXPRESSION':'"field_3" = \'{}\''.format(statCode), \
    'OUTPUT': 'TEMPORARY_OUTPUT'})            
    res = processing.run("native:deletecolumn", {'INPUT': res['OUTPUT'], 'COLUMN': ['field_1', 'field_3'], \
    'OUTPUT':'TEMPORARY_OUTPUT'})   # field_1: 연도, field_3: 통계속성('to_in_001' 등)
    
    return res['OUTPUT']

def joinBordStat(baseYear, gridLiteral, bordDir, statDir, outputDir):
    def getJoinInfo(targetLayer, joinLayer):
        joinInfo = QgsVectorLayerJoinInfo()
        joinInfo.setTargetFieldName(targetLayer.attributeDisplayName(1)) #geoPackage의 경우 2번째 필드, 'GRID_1K_CD(1K)
        joinInfo.setJoinFieldName(joinLayer.attributeDisplayName(0)) #'field_2' (연도(field_1)을 지워서 첫번째임)
        #print('target(1): ' + targetLayer.attributeDisplayName(1) + ', join(0): ' + joinLayer.attributeDisplayName(0))
        joinInfo.setJoinLayer(joinLayer)
        joinInfo.setPrefix('')
        return joinInfo
        
    bordLayer = getBord(bordDir, gridLiteral, outputDir)   #그리드 경계 합친 파일 생성
    print('grid_' + gridLiteral + '_1K' + ' [ATTR COUNT]: ' + str(len(bordLayer.attributeList())))
    #원본 경계파일에 속성이 결합된 경우가 있어서 속성 개수 '2'인지 확인
    statPop = getStatPop(statDir, baseYear, gridLiteral)
    bordLayer.addJoin(getJoinInfo(bordLayer, statPop))

    dp = bordLayer.dataProvider()
    dp.addAttributes([QgsField('base_year', QVariant.String, 'char')])
    dp.addAttributes([QgsField('pop', QVariant.Int, 'int')])
    bordLayer.updateFields()  

    #성능 확인하고 base_year 적용할지 판단
    ctx = QgsExpressionContext()
    ctx.appendScopes(QgsExpressionContextUtils.globalProjectLayerScopes(bordLayer))
    baseYear_exp = QgsExpression(baseYear) # 연도 추가(통계(txt)에 있는 연도는 join되지 않는 컬럼이 있어서 사용하지 않음)
    pop_exp = QgsExpression('"field_4"') # 결합한 컬럼을 따로 저장
    with edit(bordLayer):
        for feat in bordLayer.getFeatures():
            ctx.setFeature(feat)
            feat['base_year'] = baseYear_exp.evaluate(ctx)
            feat['pop'] = pop_exp.evaluate(ctx)
            bordLayer.updateFeature(feat)

    return bordLayer

def getMergedLayer(baseYear, gridLiteralList, bordDir, statDir, outputDir):
    layerList = []
    #layer = QgsVectorLayer()
    statLayerCount = 0
    # logger.debug("in getMergedLayer() baseYear: %s", baseYear)
    for gridLiteral in gridLiteralList:
        layer = joinBordStat(baseYear, gridLiteral, bordDir, statDir, outputDir)
        layerList.append(layer)
        statLayerCount = statLayerCount + 1
        logger.debug('getMergedLayer() - grid_%s_1K[%s]', gridLiteral, str(statLayerCount))

    res = processing.run("native:mergevectorlayers", {'LAYERS': layerList, 'OUTPUT': 'TEMPORARY_OUTPUT'})
    res = processing.run("native:deletecolumn", {'INPUT': res['OUTPUT'], 'COLUMN': ['fid','layer','path'], \
    'OUTPUT': 'TEMPORARY_OUTPUT'})  #fid를 삭제해도 저장하면 새로운 fid 자동 부여
    
    return res['OUTPUT']

#점검용 레이어 저장
def getLayerName_suffixed(layerBaseName, suffix):
    return layerBaseName + '_' + suffix  # <layerBaseName>_YYYY or <layerBaseName>_NN   
    
def getLayerPath_suffixed(layerBaseName, workDir, suffix):
    # <workDir>/<layerBaseName>_YYYY.gpkg or <layerBaseName>_NN.gpkg
    return workDir + '/' + getLayerName_suffixed(layerBaseName, suffix) + '.gpkg'  

def getLayerPath(layerBaseName, workDir):
    # <workDir>/<layerBaseName>.gpkg
    return workDir + '/' + layerBaseName + '.gpkg'  


#자주 쓰는 기능 함수로 만들기(getLayer, showLayer)
def getLayer_suffixed(layerBaseName, workDir, suffix):
    layer_path = getLayerPath_suffixed(layerBaseName, workDir, suffix)
    layer_name = getLayerName_suffixed(layerBaseName, suffix)
    return QgsVectorLayer(layer_path, layer_name, "ogr")
    
def getLayer(layerBaseName, workDir):
    layer_path = getLayerPath(layerBaseName, workDir)
    return QgsVectorLayer(layer_path, layerBaseName, "ogr")

def showLayer_suffixed(layerBaseName, workDir, suffix):
    layer = getLayer_suffixed(layerBaseName, workDir, suffix)
    QgsProject.instance().addMapLayer(layer)

def showLayer(layerBaseName, workDir):
    layer = getLayer(layerBaseName, workDir)
    QgsProject.instance().addMapLayer(layer)

def makePopGrid(baseYear, gridLiterals, pop_grid_BN, bordDir, statDir, outputDir, workDir, SHOWLAYER):
    pop_grid_layer = getMergedLayer(baseYear, gridLiterals, bordDir, statDir, outputDir)
    pop_grid_path = getLayerPath_suffixed(pop_grid_BN, workDir, baseYear)
    logger.debug("makePopGrid() - pop_grid_path: %s", pop_grid_path)
    createDirectoryIfNotExist(workDir)
    # processing.run("gdal:convertformat", {'INPUT': pop_grid_layer, 'OPTIONS': '-f "GPKG" -overwrite', 'OUTPUT': pop_grid_path})
    res = processing.run("gdal:convertformat", {'INPUT': pop_grid_layer, 'OPTIONS': '-overwrite', 'OUTPUT': pop_grid_path})
    
#    if SHOWLAYER == True:   showLayer(pop_grid_BN, baseYear)

def makePop1500(pop_grid_BN, pop1500_BN, urbanCenterDir, popGridDir, baseYear, SHOWLAYER):
    pop_grid_layer = getLayer_suffixed(pop_grid_BN, popGridDir, baseYear)
    pop_grid_layer.selectByExpression('"pop" >= 1500')
    pop1500_path = getLayerPath(pop1500_BN, urbanCenterDir)
    writer = QgsVectorFileWriter.writeAsVectorFormat(pop_grid_layer, pop1500_path, "utf-8", driverName="GPKG", onlySelected=True)
    if SHOWLAYER == True:    showLayer(pop1500_BN, urbanCenterDir)
        
    
def makePop1500_group(pop1500_BN, pop1500_group_BN, workDir, SHOWLAYER):
    pop1500_layer = getLayer(pop1500_BN, workDir)

    res = processing.run("native:dissolve", {'FIELD': [], 'INPUT': pop1500_layer, 'OUTPUT': 'TEMPORARY_OUTPUT' })
    res = processing.run("native:multiparttosingleparts", {'INPUT' : res['OUTPUT'], 'OUTPUT' : 'TEMPORARY_OUTPUT' })
    #parts의 컬럼은 의미없음 GPKG 형식으로 저장하고 fid 활용해서 영역에 구분되는 group_id 붙이는 작업 필요
    res = processing.run("native:deletecolumn", {'INPUT': res['OUTPUT'], 'COLUMN': ['fid','GRID_1K_CD','base_year','pop'], \
    'OUTPUT': 'TEMPORARY_OUTPUT'})

    pop1500_group_layer = res['OUTPUT']
    pop1500_group_path = getLayerPath(pop1500_group_BN, workDir)
    # processing.run("gdal:convertformat", {'INPUT': pop1500_group_layer, 'OPTIONS': '-f "GPKG" -overwrite', \
    processing.run("gdal:convertformat", {'INPUT': pop1500_group_layer, 'OPTIONS': '-overwrite', 'OUTPUT': pop1500_group_path})

    pop1500_group_name = pop1500_group_BN
    pop1500_group_layer = QgsVectorLayer(pop1500_group_path, pop1500_group_name, "ogr")
    #group_id 생성: gpkg의 fid(자동생성) 활용해서 만들기
    dp = pop1500_group_layer.dataProvider()
    dp.addAttributes([QgsField('group_id', QVariant.String, 'char')])
    pop1500_group_layer.updateFields()

    ctx = QgsExpressionContext()
    ctx.appendScopes(QgsExpressionContextUtils.globalProjectLayerScopes(pop1500_group_layer))
    group_id_exp = QgsExpression('concat(\'group_\', lpad( "fid", 4, \'0\'))')  #ID_WIDTH(4)
    with edit(pop1500_group_layer):
        for feat in pop1500_group_layer.getFeatures():
            ctx.setFeature(feat)
            feat['group_id'] = group_id_exp.evaluate(ctx)
            pop1500_group_layer.updateFeature(feat)

    if SHOWLAYER == True:    showLayer(pop1500_group_BN, workDir)

def joinPop1500_gid(pop1500_BN, pop1500_group_BN, pop1500_gid_BN, workDir, SHOWLAYER):
    pop1500_layer = getLayer(pop1500_BN, workDir)
    pop1500_group_layer = getLayer(pop1500_group_BN, workDir)

    res = processing.run("native:joinattributesbylocation", { 'INPUT': pop1500_layer, 'JOIN': pop1500_group_layer, \
    'JOIN_FIELDS':['group_id'], 'PREDICATE':[0], 'METHOD':2, 'DISCARD_NONMATCHING':False, 'PREFIX':'', \
    'OUTPUT':'TEMPORARY_OUTPUT' })  #PREDICATE(0): 교차, METHOD(2): 최대 중첩 영역을 가진 피처의 속성만 가져오기(1대1)

    pop1500_gid_layer = res['OUTPUT']
    pop1500_gid_path = getLayerPath(pop1500_gid_BN, workDir)

    # processing.run("gdal:convertformat", {'INPUT': pop1500_gid_layer, 'OPTIONS': '-f "GPKG" -overwrite', \
    processing.run("gdal:convertformat", {'INPUT': pop1500_gid_layer, 'OPTIONS': '-overwrite', 'OUTPUT': pop1500_gid_path})
    
    if SHOWLAYER == True:    showLayer(pop1500_gid_BN, workDir)

def joinPop1500_group_sum(pop1500_group_BN, pop1500_gid_BN, pop1500_group_sum_BN, workDir, SHOWLAYER):
    pop1500_group_layer = getLayer(pop1500_group_BN, workDir)
    pop1500_gid_layer = getLayer(pop1500_gid_BN, workDir)

    #툴박스 > 벡터일반 > 위치를 이용하여 속성을 결합(요약)
    res = processing.run("qgis:joinbylocationsummary", {'INPUT': pop1500_group_layer, 'JOIN' : pop1500_gid_layer, \
    'JOIN_FIELDS': ['pop'], 'PREDICATE': [1], 'SUMMARIES': [5], 'DISCARD_NONMATCHING': False, 'OUTPUT': 'TEMPORARY_OUTPUT'})
    #PREDICATE(0): 교차(??), SUMMARIES(5): sum -> 과대집계되는 오류
    #PREDICATE(1): contains, SUMMARIES(5): sum

    pop1500_group_sum_layer = res['OUTPUT']
    pop1500_group_sum_path = getLayerPath(pop1500_group_sum_BN, workDir)

    # processing.run("gdal:convertformat", {'INPUT': pop1500_group_sum_layer, 'OPTIONS': '-f "GPKG" -overwrite', \
    processing.run("gdal:convertformat", {'INPUT': pop1500_group_sum_layer, 'OPTIONS': '-overwrite', 'OUTPUT': pop1500_group_sum_path})

    if SHOWLAYER == True:    showLayer(pop1500_group_sum_BN, workDir)

def makePopLayers(pop_grid_BN, pop1500_BN, pop1500_gid_BN, pop1500_group_BN, pop1500_group_sum_BN, urbanCenterDir, popGridDir, baseYear, SHOWLAYER):
    #pop1500 만들기
    makePop1500(pop_grid_BN, pop1500_BN, urbanCenterDir, popGridDir, baseYear, SHOWLAYER)    

    #pop1500_group 만들기
    makePop1500_group(pop1500_BN, pop1500_group_BN, urbanCenterDir, SHOWLAYER)

    #pop1500에 group_id 붙이기
    joinPop1500_gid(pop1500_BN, pop1500_group_BN, pop1500_gid_BN, urbanCenterDir, SHOWLAYER)

    #pop1500_group에 sum 붙이기
    joinPop1500_group_sum(pop1500_group_BN, pop1500_gid_BN, pop1500_group_sum_BN, urbanCenterDir, SHOWLAYER)

def initUrbanCenterGroup(urban_center_group_BN, phaseNo, workDir, pop1500_group_sum_BN, SHOWLAYER):
    pop1500_group_sum_layer = getLayer(pop1500_group_sum_BN, workDir)
    
    pop1500_group_sum_layer.selectByExpression('"pop_sum" >= 50000')
    urban_center_group_path = getLayerPath_suffixed(urban_center_group_BN, workDir, phaseString(phaseNo))
    writer = QgsVectorFileWriter.writeAsVectorFormat(pop1500_group_sum_layer, urban_center_group_path, "utf-8", \
    driverName="GPKG", onlySelected=True)
    
    if SHOWLAYER == True:    showLayer_suffixed(urban_center_group_BN, workDir, phaseString(phaseNo))
 
def initUrbanCenterCell(pop1500_BN, pop1500_gid_BN, urban_center_group_BN, urban_center_cell_BN, phaseNo, workDir, SHOWLAYER):
    pop1500_layer = getLayer(pop1500_gid_BN, workDir)
    urban_center_group_layer = getLayer_suffixed(urban_center_group_BN, workDir, phaseString(phaseNo))
    
    res = processing.run("native:selectbylocation", {'INPUT': pop1500_layer, 'INTERSECT': urban_center_group_layer, \
    'PREDICATE': [6], 'METHOD': 0}) #PREDICATE(6): are within, METHOD(0): 새 선택집합 생성 

    urban_center_cell_layer = res['OUTPUT']
    urban_center_cell_path = getLayerPath_suffixed(urban_center_cell_BN, workDir, phaseString(phaseNo))
    writer = QgsVectorFileWriter.writeAsVectorFormat(urban_center_cell_layer, urban_center_cell_path, "utf-8", \
    driverName="GPKG", onlySelected=True)
    
    if SHOWLAYER == True:    showLayer_suffixed(urban_center_cell_BN, workDir, phaseString(phaseNo))

def phaseString(phaseNo):
    phaseStr = str(phaseNo)
    return phaseStr.zfill(2)

def makeTouchCell_diff(pop_grid_BN, urban_center_group_BN, touch_cell_BN, touch_cell_tmp_BN, phaseNo, baseYear, urbanCenterDir, popGridDir, SHOWLAYER):

    #가장 최근의 urban_center_group 레이어를 이용해서 touch_cell_NN 만들기
    pop_grid_layer = getLayer_suffixed(pop_grid_BN, popGridDir, baseYear)
    
    #직전 단계의 urban_center_group 레이어 (touch_cell_01 단계면 00단계) 
    urban_center_group_layer_PREV = getLayer_suffixed(urban_center_group_BN, urbanCenterDir, phaseString(phaseNo - 1))

    res = processing.run("native:selectbylocation", {'INPUT': pop_grid_layer, 'INTERSECT': urban_center_group_layer_PREV, \
    'PREDICATE': [4], 'METHOD': 0}) #PREDICATE(4): touch, METHOD(0): 새 선택집합 생성 

    touch_cell_tmp_layer = res['OUTPUT']
    touch_cell_tmp_path = getLayerPath_suffixed(touch_cell_tmp_BN, urbanCenterDir, phaseString(phaseNo))
    writer = QgsVectorFileWriter.writeAsVectorFormat(touch_cell_tmp_layer, touch_cell_tmp_path, "utf-8", \
    driverName="GPKG", onlySelected=True)
    
    touch_cell_tmp_layer = getLayer_suffixed(touch_cell_tmp_BN, urbanCenterDir, phaseString(phaseNo))

    #touch_cell_tmp(잠정)에서 center_group을 빼서(difference) touch_cell 확정
    #(분리된) center_group이 대각선으로 접하는 경우 center_group의 일부가 touch_cell에 포함되고 gap_fill로 선택되기도 함
    res = processing.run("native:difference", { 'INPUT' : touch_cell_tmp_layer, 'OVERLAY' : urban_center_group_layer_PREV, \
    'OUTPUT' : 'TEMPORARY_OUTPUT'})

    touch_cell_layer = res['OUTPUT']
    touch_cell_path = getLayerPath_suffixed(touch_cell_BN, urbanCenterDir, phaseString(phaseNo))
    # processing.run("gdal:convertformat", {'INPUT': touch_cell_layer, 'OPTIONS': '-f "GPKG" -overwrite', \
    processing.run("gdal:convertformat", {'INPUT': touch_cell_layer, 'OPTIONS': '-overwrite', 'OUTPUT': touch_cell_path})

    if SHOWLAYER == True:    showLayer_suffixed(touch_cell_BN, urbanCenterDir, phaseString(phaseNo))

def makeTouchCell_diss(pop_grid_BN, urban_center_group_BN, touch_cell_BN, phaseNo, baseYear, workDir, SHOWLAYER):

    #직전 단계의 urban_center_group 레이어를 dissolve해서 우선 하나의 자료로 만듬
    urban_center_group_layer_PREV = getLayer_suffixed(urban_center_group_BN, workDir, phaseString(phaseNo - 1))
    
    #dissolve
    res = processing.run("native:dissolve", {'FIELD': [], 'INPUT': urban_center_group_layer_PREV, 'OUTPUT': 'TEMPORARY_OUTPUT' })
    urban_center_group_layer_PREV_DISS = res['OUTPUT']
    
    pop_grid_layer = getLayer_suffixed(pop_grid_BN, workDir, baseYear)
    
    res = processing.run("native:selectbylocation", {'INPUT': pop_grid_layer, 'INTERSECT': urban_center_group_layer_PREV_DISS, \
    'PREDICATE': [4], 'METHOD': 0}) #PREDICATE(4): touch, METHOD(0): 새 선택집합 생성 

    touch_cell_layer = res['OUTPUT']
    touch_cell_path = getLayerPath_suffixed(touch_cell_BN, workDir, phaseString(phaseNo))
    writer = QgsVectorFileWriter.writeAsVectorFormat(touch_cell_layer, touch_cell_path, "utf-8", \
    driverName="GPKG", onlySelected=True)
    
    if SHOWLAYER == True:    showLayer_suffixed(touch_cell_BN, workDir, phaseString(phaseNo))


def makeGapFill(touch_cell_BN, urban_center_cell_BN, gap_fill_BN, phaseNo, workDir, SHOWLAYER):

    #가장 최근의 urban_center_cell 레이어를 이용해서 gap_fill_NN 만들기
    touch_cell_layer = getLayer_suffixed(touch_cell_BN, workDir, phaseString(phaseNo))
    #직전 단계의 urban_center_group 레이어 (touch_cell_01 단계면 00단계) 
    urban_center_cell_layer = getLayer_suffixed(urban_center_cell_BN, workDir, phaseString(phaseNo - 1))

    res = processing.run("qgis:joinbylocationsummary", {'INPUT': touch_cell_layer, 'JOIN' : urban_center_cell_layer, \
    'JOIN_FIELDS': ['GRID_CD'], 'PREDICATE': [3], 'SUMMARIES': [0], 'DISCARD_NONMATCHING': False, 'OUTPUT': 'TEMPORARY_OUTPUT'})
    #PREDICATE(3): touches, SUMMARIES(0): count

    gap_fill_layer = res['OUTPUT']
    gap_fill_layer.selectByExpression('"GRID_CD_count" >= 5')
    
    gapFillCount = gap_fill_layer.selectedFeatureCount()
    print("phaseNo: " + phaseString(phaseNo) + ", gapFillCount: " + str(gap_fill_layer.selectedFeatureCount()))
    
    if gapFillCount >= 1:
        gap_fill_path = getLayerPath_suffixed(gap_fill_BN, workDir, phaseString(phaseNo))
        writer = QgsVectorFileWriter.writeAsVectorFormat(gap_fill_layer, gap_fill_path, "utf-8", driverName="GPKG", onlySelected=True)

        #phase_no 생성
        gap_fill_layer = getLayer_suffixed(gap_fill_BN, workDir, phaseString(phaseNo))

        dp = gap_fill_layer.dataProvider()
        dp.addAttributes([QgsField('phase_no', QVariant.String, 'char')])
        gap_fill_layer.updateFields()

        ctx = QgsExpressionContext()
        ctx.appendScopes(QgsExpressionContextUtils.globalProjectLayerScopes(gap_fill_layer))
        phase_no_exp = QgsExpression(phaseString(phaseNo))
        with edit(gap_fill_layer):
            for feat in gap_fill_layer.getFeatures():
                ctx.setFeature(feat)
                feat['phase_no'] = phase_no_exp.evaluate(ctx)
                gap_fill_layer.updateFeature(feat)

        if SHOWLAYER == True:    showLayer_suffixed(gap_fill_BN, workDir, phaseString(phaseNo))

    return gapFillCount

def mergeUrbanCenterCell(urban_center_cell_BN, urban_center_group_BN, gap_fill_BN, pop1500_gid_BN, phaseNo, workDir, SHOWLAYER):
    pop1500_gid_layer = getLayer(pop1500_gid_BN, workDir)
    urban_center_group_layer = getLayer_suffixed(urban_center_group_BN, workDir, phaseString(phaseNo))
    
    #gap_fill 레이어와 urban_center_cell(전단계) 결합해서 urban_center_cell(현단계)에 저장
    urban_center_cell_layer_PREV = getLayer_suffixed(urban_center_cell_BN, workDir, phaseString(phaseNo - 1))
    
    #gap_fill_NN 레이어에서 'GRID_1K_CD_count', 'phase_no' 삭제
    gap_fill_layer = getLayer_suffixed(gap_fill_BN, workDir, phaseString(phaseNo))
    res = processing.run("native:deletecolumn", {'INPUT': gap_fill_layer, 'COLUMN': ['GRID_1K_CD_count', 'phase_no'], \
    'OUTPUT': 'TEMPORARY_OUTPUT'})
    
    res = processing.run("native:mergevectorlayers", {'LAYERS': [urban_center_cell_layer_PREV, res['OUTPUT']], \
    'OUTPUT': 'TEMPORARY_OUTPUT'})
    res = processing.run("native:deletecolumn", {'INPUT': res['OUTPUT'], 'COLUMN': ['fid','group_id', 'layer','path'], \
    'OUTPUT': 'TEMPORARY_OUTPUT'})  #fid를 삭제해도 저장하면 새로운 fid 자동 부여
    
    urban_center_cell_layer = res['OUTPUT']
    urban_center_cell_path = getLayerPath_suffixed(urban_center_cell_BN, workDir, phaseString(phaseNo))
    # processing.run("gdal:convertformat", {'INPUT': urban_center_cell_layer, 'OPTIONS': '-f "GPKG" -overwrite', \
    processing.run("gdal:convertformat", {'INPUT': urban_center_cell_layer, 'OPTIONS': '-overwrite', 'OUTPUT': urban_center_cell_path})

    if SHOWLAYER == True:    showLayer_suffixed(urban_center_cell_BN, workDir, phaseString(phaseNo))
    
def updateUrbanCenterGroup(urban_center_cell_BN, urban_center_group_BN, phaseNo, workDir, SHOWLAYER):
    urban_center_cell_layer = getLayer_suffixed(urban_center_cell_BN, workDir, phaseString(phaseNo))

    res = processing.run("native:dissolve", {'FIELD': [], 'INPUT': urban_center_cell_layer, 'OUTPUT': 'TEMPORARY_OUTPUT' })
    res = processing.run("native:multiparttosingleparts", {'INPUT' : res['OUTPUT'], 'OUTPUT' : 'TEMPORARY_OUTPUT' })
    #parts의 컬럼은 의미없음 경계(geometry) 정보만 있어도 됨 
    res = processing.run("native:deletecolumn", {'INPUT': res['OUTPUT'], 'COLUMN': ['fid', 'GRID_1K_CD', 'base_year', 'pop'], \
    'OUTPUT': 'TEMPORARY_OUTPUT'})

    urban_center_group_layer = res['OUTPUT']
    urban_center_group_path = getLayerPath_suffixed(urban_center_group_BN, workDir, phaseString(phaseNo))
    # processing.run("gdal:convertformat", {'INPUT': urban_center_group_layer, 'OPTIONS': '-f "GPKG" -overwrite', \
    processing.run("gdal:convertformat", {'INPUT': urban_center_group_layer, 'OPTIONS': '-overwrite', 'OUTPUT': urban_center_group_path})

    if SHOWLAYER == True:    showLayer_suffixed(urban_center_group_BN, workDir, phaseString(phaseNo))


def finalUrbanCenterGroup(urban_center_group_BN, phaseNo, baseYear, workDir, SHOWLAYER):
    # 마지막 단계의 urban_center_group 레이어를 urban_center_group_YYYY로 저장
    urban_center_group_layer = getLayer_suffixed(urban_center_group_BN, workDir, phaseString(phaseNo))

    #urban_id 'center_NNN' 생성: gpkg의 fid(자동생성) 활용해서 만들기
    dp = urban_center_group_layer.dataProvider()
    dp.addAttributes([QgsField('urban_id', QVariant.String, 'char')])
    urban_center_group_layer.updateFields()  

    ctx = QgsExpressionContext()
    ctx.appendScopes(QgsExpressionContextUtils.globalProjectLayerScopes(urban_center_group_layer))
    urban_id_exp = QgsExpression('concat(\'center_\', lpad( "fid", 4, \'0\'))') #ID_WIDTH(4)
    with edit(urban_center_group_layer):
        for feat in urban_center_group_layer.getFeatures():
            ctx.setFeature(feat)
            feat['urban_id'] = urban_id_exp.evaluate(ctx)
            urban_center_group_layer.updateFeature(feat)

    urban_center_group_path = getLayerPath_suffixed(urban_center_group_BN, workDir, baseYear)
    # processing.run("gdal:convertformat", {'INPUT': urban_center_group_layer, 'OPTIONS': '-f "GPKG" -overwrite', \
    processing.run("gdal:convertformat", {'INPUT': urban_center_group_layer, 'OPTIONS': '-overwrite', 'OUTPUT': urban_center_group_path})

    #if SHOWLAYER == True:    showLayer_suffixed(urban_center_group_BN, workDir, baseYear)
    showLayer_suffixed(urban_center_group_BN, workDir, baseYear)


def finalUrbanCenterCell(urban_center_cell_BN, urban_center_group_BN, phaseNo, baseYear, workDir, SHOWLAYER):
    # 마지막 단계의 urban_center_cell 레이어를 urban_center_cell_YYYY로 저장
    urban_center_cell_layer = getLayer_suffixed(urban_center_cell_BN, workDir, phaseString(phaseNo))

    urban_center_group_layer = getLayer_suffixed(urban_center_group_BN, workDir, baseYear)

    res = processing.run("native:joinattributesbylocation", { 'INPUT': urban_center_cell_layer, 'JOIN': urban_center_group_layer, \
    'JOIN_FIELDS':['urban_id'], 'PREDICATE':[0], 'METHOD':2, 'DISCARD_NONMATCHING':False, 'PREFIX':'', \
    'OUTPUT':'TEMPORARY_OUTPUT' })  #PREDICATE(0): 교차, METHOD(2): 최대 중첩 영역을 가진 피처의 속성만 가져오기(1대1)

    urban_center_cell_layer = res['OUTPUT']
    urban_center_cell_path = getLayerPath_suffixed(urban_center_cell_BN, workDir, baseYear)
    # processing.run("gdal:convertformat", {'INPUT': urban_center_cell_layer, 'OPTIONS': '-f "GPKG" -overwrite', \
    processing.run("gdal:convertformat", {'INPUT': urban_center_cell_layer, 'OPTIONS': '-overwrite', 'OUTPUT': urban_center_cell_path})

    if SHOWLAYER == True:    showLayer_suffixed(urban_center_cell_BN, workDir, baseYear)
    #showLayer_suffixed(urban_center_cell_BN, workDir, baseYear)

def makeUrbanCenter(urban_center_group_BN, urban_center_cell_BN, pop1500_gid_BN, pop1500_group_sum_BN, pop_grid_BN, touch_cell_BN, \
    touch_cell_tmp_BN, gap_fill_BN, baseYear, urbanCenterDir, popGridDir, PHASEMAX, SHOWLAYER):

    phaseNo = 0
    #urban_center_group 만들기 #1500명, 50000명 조건에 맞는 초기 urban_center group
    initUrbanCenterGroup(urban_center_group_BN, phaseNo, urbanCenterDir, pop1500_group_sum_BN, SHOWLAYER)

    #urban_center_cell 만들기 #1500명, 50000명 조건에 맞는 초기 urban_center 개별격자
    initUrbanCenterCell(pop1500_gid_BN, pop1500_gid_BN, urban_center_group_BN, urban_center_cell_BN, phaseNo, urbanCenterDir, SHOWLAYER)
    
    logger.debug('makeUrbanCenter() - baseYear: %s', baseYear)
    
    while True:
        phaseNo = phaseNo + 1

        if phaseNo > PHASEMAX:   break;    #몇번만 진행해보기
        
        #diff(빼기)는 2단계로 처리하지만 빠르고, diss(디졸브)는 1단계로 코드 간결하지만 느림(phase 당 5분 내외)
        makeTouchCell_diff(pop_grid_BN, urban_center_group_BN, touch_cell_BN, touch_cell_tmp_BN, phaseNo, baseYear, urbanCenterDir, popGridDir, False)
        #makeTouchCell_diss(pop_grid_BN, urban_center_group_BN, touch_cell_BN, phaseNo, baseYear, workDir, False)

        gapFillCount = makeGapFill(touch_cell_BN, urban_center_cell_BN, gap_fill_BN, phaseNo, urbanCenterDir, SHOWLAYER)
        logger.debug("makeUrbanCenter() - phaseNo: %s, gapFillCount: %s", phaseNo, gapFillCount)

        if gapFillCount == 0:   break; 
            
        #gap_fill 레이어와 urban_center_cell(전단계) 결합해서 urban_center_cell(현단계)에 저장
        mergeUrbanCenterCell(urban_center_cell_BN, urban_center_group_BN, gap_fill_BN, pop1500_gid_BN, phaseNo, urbanCenterDir, False)

        updateUrbanCenterGroup(urban_center_cell_BN, urban_center_group_BN, phaseNo, urbanCenterDir, False)

    finalPhaseNo = phaseNo - 1
    logger.debug("finalPhaseNo: %s", str(finalPhaseNo))

    finalUrbanCenterGroup(urban_center_group_BN, finalPhaseNo, baseYear, urbanCenterDir, SHOWLAYER)

    finalUrbanCenterCell(urban_center_cell_BN, urban_center_group_BN, finalPhaseNo, baseYear, urbanCenterDir, SHOWLAYER)

def getPopGridDir(outputDir, popGridPath):
    return outputDir + "/" + popGridPath

def getUrbanCenterDir(outputDir, urbanCenterPath, baseYear):
    return outputDir + "/" + urbanCenterPath + "_" + baseYear 

def getUrbanClusterDir(outputDir, urbanClusterPath, baseYear):
    return outputDir + "/" + urbanClusterPath + "_" + baseYear 

def makePop300(pop_grid_BN, pop300_BN, urbanClusterDir, popGridDir, baseYear, SHOWLAYER):
    pop300_layer = getLayer_suffixed(pop_grid_BN, popGridDir, baseYear)
    pop300_layer.selectByExpression('"pop" >= 300')
    pop300_path = getLayerPath(pop300_BN, urbanClusterDir)
    writer = QgsVectorFileWriter.writeAsVectorFormat(pop300_layer, pop300_path, "utf-8", driverName="GPKG", onlySelected=True)
    if SHOWLAYER == True:    showLayer(pop300_BN, urbanClusterDir)


def makeUrbanClusterCandi(urban_cluster_candi_BN, pop300_BN, pop300_group_BN, pop300_gid_BN, urbanClusterDir, SHOWLAYER):
    pop300_layer = getLayer(pop300_BN, urbanClusterDir)

    #1m 버퍼(buffer) 처리하면서 결과물 디졸브(dissolve)
    res = processing.run("native:buffer", {'DISTANCE' : 1, 'INPUT' : pop300_layer, 'DISSOLVE' : True, 'END_CAP_STYLE' : 0, \
    'JOIN_STYLE' : 0, 'MITER_LIMIT' : 2, 'SEGMENTS' : 5, 'OUTPUT' : 'TEMPORARY_OUTPUT' })
    #거리(DISTANCE): 1m, 결과물 디졸브(DISSOLVE): True, 선끝 스타일('END_CAP_STYLE' ): 0(둥글게), 
    #이음새 스타일(JOIN STYLE): 0(둥글게), 마이터 제한(MITER_LIMIT): 2, 선분(SEGMENTS): 5

    #디졸브된 레이어를 분리된 그룹으로 나누기(꼭지점 맞닿은 격자도 한 그룹으로 묶임)
    res = processing.run("native:multiparttosingleparts", {'INPUT' : res['OUTPUT'], 'OUTPUT' : 'TEMPORARY_OUTPUT' })
    #parts의 컬럼은 의미없음 경계(geometry) 정보만 있어도 됨 
    res = processing.run("native:deletecolumn", {'INPUT': res['OUTPUT'], 'COLUMN': ['fid', 'GRID_CD', 'base_year', 'pop'], \
    'OUTPUT': 'TEMPORARY_OUTPUT'})

    #group의 컬럼은 의미없음 GPKG 형식으로 저장하고 fid 활용해서 영역에 구분되는 group_id 붙이는 작업 필요
    pop300_group_layer = res['OUTPUT']
    pop300_group_path = getLayerPath(pop300_group_BN, urbanClusterDir)
    # processing.run("gdal:convertformat", {'INPUT': pop300_group_layer, 'OPTIONS': '-f "GPKG" -overwrite', \
    processing.run("gdal:convertformat", {'INPUT': pop300_group_layer, 'OPTIONS': '-overwrite', 'OUTPUT': pop300_group_path})

    pop300_group_name = pop300_group_BN
    pop300_group_layer = QgsVectorLayer(pop300_group_path, pop300_group_name, "ogr")
    #group_id 생성: gpkg의 fid(자동생성) 활용해서 만들기
    dp = pop300_group_layer.dataProvider()
    dp.addAttributes([QgsField('group_id', QVariant.String, 'char')])
    pop300_group_layer.updateFields()  

    ctx = QgsExpressionContext()
    ctx.appendScopes(QgsExpressionContextUtils.globalProjectLayerScopes(pop300_group_layer))
    #준도시 후보가 1000개가 넘어서 group_id를 4자리로 생성(2020년의 경우 1200개 이상)
    group_id_exp = QgsExpression('concat(\'group_\', lpad( "fid", 4, \'0\'))')  #ID_WIDTH(4)
    with edit(pop300_group_layer):
        for feat in pop300_group_layer.getFeatures():
            ctx.setFeature(feat)
            feat['group_id'] = group_id_exp.evaluate(ctx)
            pop300_group_layer.updateFeature(feat)

    if SHOWLAYER == True:    showLayer(pop300_group_BN, urbanClusterDir)

    #pop300 레이어에 임시 그룹ID 붙여서 그룹ID로 디졸브하기
    res = processing.run("native:joinattributesbylocation", { 'INPUT': pop300_layer, 'JOIN': pop300_group_layer, \
    'JOIN_FIELDS':['group_id'], 'PREDICATE':[0], 'METHOD':2, 'DISCARD_NONMATCHING':False, 'PREFIX':'', \
    'OUTPUT':'TEMPORARY_OUTPUT' })  #PREDICATE(0): 교차, METHOD(2): 최대 중첩 영역을 가진 피처의 속성만 가져오기(1대1)

    pop300_gid_layer = res['OUTPUT']
    pop300_gid_path = getLayerPath(pop300_gid_BN, urbanClusterDir)
    # processing.run("gdal:convertformat", {'INPUT': pop300_gid_layer, 'OPTIONS': '-f "GPKG" -overwrite', \
    processing.run("gdal:convertformat", {'INPUT': pop300_gid_layer, 'OPTIONS': '-overwrite', 'OUTPUT': pop300_gid_path})

    if SHOWLAYER == True:    showLayer(pop300_gid_BN, urbanClusterDir)

    res = processing.run("native:dissolve", { 'FIELD' : ['group_id'], 'INPUT' : pop300_gid_layer, 'OUTPUT' : 'TEMPORARY_OUTPUT' })
    res = processing.run("native:deletecolumn", {'INPUT': res['OUTPUT'], 'COLUMN': ['fid', 'GRID_CD', 'base_year', 'pop'], \
    'OUTPUT': 'TEMPORARY_OUTPUT'})
    
    #요약(인구수 합계) 추가해서 urban_cluster_candi 만들기 준비(pop300 또는 pop300_gid 레이어 이용)
    res = processing.run("qgis:joinbylocationsummary", {'INPUT': res['OUTPUT'], 'JOIN' : pop300_gid_layer, \
    'JOIN_FIELDS': ['pop'], 'PREDICATE': [1], 'SUMMARIES': [5], 'DISCARD_NONMATCHING': False, 'OUTPUT': 'TEMPORARY_OUTPUT'})
    #PREDICATE(1): contains, SUMMARIES(5): sum

    urban_cluster_candi_layer = res['OUTPUT']
    urban_cluster_candi_layer.selectByExpression('"pop_sum" >= 5000') #그룹별 인구수 합계 '5000명 이상' 선택

    urban_cluster_candi_path = getLayerPath(urban_cluster_candi_BN, urbanClusterDir)
    writer = QgsVectorFileWriter.writeAsVectorFormat(urban_cluster_candi_layer, urban_cluster_candi_path, "utf-8", \
    driverName="GPKG", onlySelected=True)

    if SHOWLAYER == True:   showLayer(urban_cluster_candi_BN, urbanClusterDir)
    
    
def makeUrbanClusterGroup(urban_cluster_group_BN, urban_cluster_candi_BN, urban_center_group_BN, baseYear, urbanClusterDir, urbanCenterDir, SHOWLAYER):
    urban_cluster_candi_layer = getLayer(urban_cluster_candi_BN, urbanClusterDir)
    urban_center_group_layer = getLayer_suffixed(urban_center_group_BN, urbanCenterDir, baseYear)
    
    #urban_cluster_candi에서 미리 만들어진 urban_center_group를 빼기(difference)해서 urban_cluster 만들기
    res = processing.run("native:difference", { 'INPUT' : urban_cluster_candi_layer, 'OVERLAY' : urban_center_group_layer, \
    'OUTPUT' : 'TEMPORARY_OUTPUT'})

    urban_cluster_group_layer = res['OUTPUT']
    urban_cluster_group_path = getLayerPath_suffixed(urban_cluster_group_BN, urbanClusterDir, baseYear)
    # processing.run("gdal:convertformat", {'INPUT': urban_cluster_group_layer, 'OPTIONS': '-f "GPKG" -overwrite', \
    processing.run("gdal:convertformat", {'INPUT': urban_cluster_group_layer, 'OPTIONS': '-overwrite', 'OUTPUT': urban_cluster_group_path})

    logger.debug("makeUrbanClusterGroup() - baseYear: %s", baseYear)
        
    #if SHOWLAYER == True:    showLayer_suffixed(urban_cluster_group_BN, urbanClusterDir, baseYear)
    showLayer_suffixed(urban_cluster_group_BN, urbanClusterDir, baseYear)

