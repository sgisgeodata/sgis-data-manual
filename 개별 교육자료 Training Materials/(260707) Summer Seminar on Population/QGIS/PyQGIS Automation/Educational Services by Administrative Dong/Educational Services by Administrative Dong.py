
# 1. 라이브러리 로드 및 사용 준비 --------------------------------------------------

from qgis.core import * # QGIS의 핵심 기능 제공
from qgis.utils import iface # QGIS의 맵 캔버스, 메뉴, 툴바 등 인터페이스에 접근
from PyQt5.QtCore import QTimer # 시간의 경과에 따라 작업 처리



# 2. 경계 레이어 추가하기(.shp) ---------------------------------------------------

# 파일 저장 경로
dir_path = 'C:/SGIS/QGIS/PyQGIS Automation/Educational Services by Administrative Dong/'

path_sido_bord = dir_path + 'bnd_sido_00_2025_2Q.shp'
path_sigungu_bord = dir_path + 'bnd_sigungu_00_2025_2Q.shp'
path_dong_bord = dir_path + 'bnd_dong_00_2025_2Q.shp'

# 벡터 레이어 불러오기
sido_bord = QgsVectorLayer(path_sido_bord, 'bnd_sido_00_2025_2Q', 'ogr')
sigungu_bord = QgsVectorLayer(path_sigungu_bord, 'bnd_sigungu_00_2025_2Q', 'ogr')
dong_bord = QgsVectorLayer(path_dong_bord, 'bnd_dong_00_2025_2Q', 'ogr')

# QgsVectorLayer(파일 경로, 레이어 이름, 제공자): 벡터 데이터를 다루는 클래스
# 'ogr': GDAL 라이브러리의 일부로, 다양한 벡터 데이터 형식(shp, gpkg, GeoJson 등)을 지원하는 제공자


# 3. 통계 레이어 추가하기(.txt) ---------------------------------------------------

path_stat_cp = dir_path + 'Establishments_by_Industry_2024.csv'
uri_stat_cp = f'file:///{path_stat_cp}?type=csv&useHeader=no&geomType=none&encoding=UTF-8'
stat_cp = QgsVectorLayer(uri_stat_cp, 'Establishments_by_Industry_2024', 'delimitedtext')

# ‘delimitedtext’: 구분자로 분리된 텍스트 파일을 지원하는 제공자(provider)


# 4. 통계 레이어에서 속성값(교육 서비스업)에 해당하는 통계항목 선택하기 -------------------

# 표현식을 이용해서 피처 선택
expression = "\"field_3\" = 'cp2_bnu_85'" 
stat_cp.selectByExpression(expression)

# 선택한 피처를 다른 이름으로 저장
path_stat_edu = dir_path + "Educational_Establishments_2024.csv"
QgsVectorFileWriter.writeAsVectorFormat(stat_cp, path_stat_edu, "UTF-8", driverName="CSV", onlySelected=True)

# 저장한 파일을 벡터 레이어 객체로 불러오기
uri_stat_edu = f'file:///{path_stat_edu}?type=csv&geomType=none&encoding=UTF-8'
stat_cp_edu = QgsVectorLayer(uri_stat_edu, 'Educational_Establishments_2024', 'delimitedtext')



# 5. 전국 행정동 경계와 교육 서비스업 통계 결합하기 -----------------------------------

# 조인 객체 생성
join_object = QgsVectorLayerJoinInfo()
join_object.setJoinLayer(stat_cp_edu) # 결합 레이어
join_object.setJoinFieldName('field_2') # 결합 필드
join_object.setTargetFieldName('ADM_CD') # 대상 필드
join_object.setJoinFieldNamesSubset(['field_4']) # 결합된 필드
join_object.setPrefix('') # 접두어 생략

# 조인 적용
dong_bord.addJoin(join_object)



# 6. 단계구분도 표시하기 ----------------------------------------------------------

# 1) 통계값(field_4)을 정수형로 변환한 필드 추가

dong_bord.dataProvider().addAttributes([QgsField('f4_int', QVariant.Int)])
dong_bord.updateFields()

with edit(dong_bord):
    for feat in dong_bord.getFeatures(): # 레이어의 모든 피처(행)에 대해 반복
        try:
            feat['f4_int'] = int(feat['field_4']) # 정수 변환
        except:
            feat['f4_int'] = 0 # 정수가 아닌 값(결측치)는 0으로 변환
        dong_bord.updateFeature(feat)



# 2) 단계 구분도 시각화 

# 색상표 생성: 색상 직접 지정하여 그라데이션(하얀색 ~ 빨강색) 설정
color_ramp = QgsGradientColorRamp(QColor('white'), QColor('red'))
# color_ramp = QgsStyle().defaultStyle().colorRamp('OrRd') # 기존 색상표 중에 선택(다른 방법)

num_classes = 5 # 구간 개수


# 단계 구분도 시각화 방법 2가지

# 방법 1: 수동으로 범위 직접 지정

# 범위 지정: (범위 최솟값, 최댓값, 범례)
range_def = [
    (0, 30, '0 ~ 30'),
    (30, 150, '30 ~ 150'),
    (150, 300, '150 ~ 300'),
    (300, 600, '300 ~ 600'),
    (600, 980, '600 ~ 980')
]

# 각 구간별로 심볼 생성
ranges = []
for idx, (min_val, max_val, label) in enumerate(range_def):
    # 색상표에서 색상 추출
    t = idx / (num_classes - 1) # 시작색(0) ~ 끝 색(1) 사이의 비율값(0, 0.25, 0.5, 0.75, 1)
    color = color_ramp.color(t) # 색상표에서 비율값에 해당하는 색상 추출

    # 심볼 생성
    symbol = QgsSymbol.defaultSymbol(dong_bord.geometryType()) # 기본 심볼
    symbol.setColor(color) # 색상 설정

    # 렌더링 범위 생성
    range = QgsRendererRange(min_val, max_val, symbol, label)
    ranges.append(range)

# 렌더러 생성
renderer = QgsGraduatedSymbolRenderer('f4_int', ranges)
renderer.setMode(QgsGraduatedSymbolRenderer.Custom) # 수동으로 범위 지정할 때 사용


# # 방법 2: 네추럴 브레이크

# # 렌더러 생성
# renderer = QgsGraduatedSymbolRenderer('f4_int', [])
# renderer.setClassificationMethod(QgsClassificationJenks()) # 네추럴 브레이크 지정
# renderer.setSourceColorRamp(color_ramp) # 색상표 지정
# renderer.updateClasses(dong_bord, num_classes) 구간 개수에 따라 자동으로 범위 설정

# 렌더러 적용
dong_bord.setRenderer(renderer) # 레이어에 렌더러 적용
dong_bord.triggerRepaint() # 맵에 심볼 변경사항 반영



# 3) 시도 경계, 시군구 경계를 단순 라인으로 설정

# 시도 경계 단순 라인 설정
sido_symbol = sido_bord.renderer().symbol() # 현재 심볼 가져오기
sido_symbol.deleteSymbolLayer(0) # 기존 심볼 초기화 
sido_line = QgsSimpleLineSymbolLayer(width=0.46, color=QColor('black')) # 심볼 레이어 생성
sido_symbol.appendSymbolLayer(sido_line) # 새 심볼 레이어 추가
sido_bord.triggerRepaint() # 맵 캔버스에 심볼 변경사항 반영

# 시군구 경계 단순 라인 설정
sgg_symbol = sigungu_bord.renderer().symbol() # 현재 심볼 가져오기
sgg_symbol.deleteSymbolLayer(0) # 기존 심볼 초기화 
sgg_line = QgsSimpleLineSymbolLayer(width=0.46, color=QColor('black')) # 심볼 레이어 생성
sgg_symbol.appendSymbolLayer(sgg_line) # 새 심볼 레이어 추가
sigungu_bord.triggerRepaint() # 맵 캔버스에 심볼 변경사항 반영




# 7. 레이어를 순서대로 프로젝트에 추가 ----------------------------------------------

QgsProject.instance().addMapLayer(dong_bord)
QgsProject.instance().addMapLayer(sigungu_bord)
QgsProject.instance().addMapLayer(sido_bord)
QgsProject.instance().addMapLayer(stat_cp)
QgsProject.instance().addMapLayer(stat_cp_edu)



# 8. 선택한 레이어로 확대/축소  ----------------------------------------------------


def zoom_layer():
    layer = QgsProject.instance().mapLayersByName("bnd_dong_00_2025_2Q")[0]
    iface.setActiveLayer(layer) # 활성 레이어로 지정
    iface.zoomToActiveLayer() # 활성 레이어 범위로 지도 확대

# 0.1초 뒤 실행 (지도 확대가 정상적으로 적용되는데 필요한 대기 시간)
QTimer.singleShot(100, zoom_layer)  



# 9. 조판 생성 및 이미지 저장하기 -------------------------------------------------

# 1) 현재 프로젝트에서 조판 생성
project = QgsProject.instance()
manager = project.layoutManager() # 조판 관리자
layout = QgsPrintLayout(project) # 새 조판 생성
layout.initializeDefaults() # 기본값으로 페이지 설정(A4용지, 가로 방향)
layout.setName("Educational Services by Administrative Dong") # 조판 이름
manager.addLayout(layout) # 조판 추가


# 페이지 설정
page = layout.pageCollection().page(0)
page.setPageSize(QgsLayoutSize(210, 297, QgsUnitTypes.LayoutMillimeters)) # A4 설정
page.orientation = QgsLayoutItemPage.Portrait # 세로 방향 설정

width = page.pageSize().width() # 페이지 너비(mm)
height = page.pageSize().height() # 페이지 높이(mm)


# 2) 맵 생성
map_item = QgsLayoutItemMap(layout)
map_item.attemptMove(QgsLayoutPoint(30, 30)) # 지도 왼쪽 위 모서리 위치 설정
map_item.attemptResize(QgsLayoutSize(width - 60, height - 60)) # 지도 너비, 높이
layer = QgsProject.instance().mapLayersByName("bnd_dong_00_2025_2Q")[0]
map_item.zoomToExtent(layer.extent()) # 선택한 레이어 범위에 맞추어 확대


# 3) 제목 라벨 생성
title = QgsLayoutItemLabel(layout)
title.setText("Educational Services by Administrative Dong(2024)")  # 제목 텍스트
title.setFont(QFont("맑은 고딕", 22, QFont.Bold)) # 폰트 설정
title.adjustSizeToText()  # 텍스트 크기에 맞게 자동 조정
title.attemptMove(QgsLayoutPoint(10, 10))  # 제목 위치(좌측 상단)


# 4) 범례 생성

# 범례 아이템 생성
legend = QgsLayoutItemLegend(layout)

# 범례 제목 및 폰트 설정
legend.setTitle("Number of Educational Services")
title_style = legend.style(QgsLegendStyle.Title)
title_style.setFont(QFont("맑은 고딕", 16, QFont.Bold))
legend.setStyle(QgsLegendStyle.Title, title_style)

# 선택한 레이어의 범례만 추가
legend.setAutoUpdateModel(False) # 자동 업데이트 끄기
layer = QgsProject.instance().mapLayersByName("bnd_dong_00_2025_2Q")[0]
legend_tree = QgsLayerTree() # 빈 레이어 트리
added_node = legend_tree.addLayer(layer) # 선택한 레이어 추가
QgsLegendRenderer.setNodeLegendStyle(added_node, QgsLegendStyle.Hidden) # 레이어 이름 숨기기
legend.model().setRootGroup(legend_tree) # 범례에 적용

# 심볼 라벨의 폰트 설정
sl_style = legend.style(QgsLegendStyle.SymbolLabel)
sl_style.setFont(QFont("맑은 고딕", 12, QFont.Bold))
legend.setStyle(QgsLegendStyle.SymbolLabel, sl_style)

# 범례 위치(우측 하단)
legend.attemptMove(QgsLayoutPoint(width - 100, height - 60))


# 5) 조판에 지도, 제목, 범례 추가 및 이미지 저장 

# 지도, 제목, 범례 아이템 추가
layout.addLayoutItem(map_item)
layout.addLayoutItem(title)
layout.addLayoutItem(legend)

# 조판을 이미지로 저장
QgsApplication.processEvents() # 대기 중인 이벤트를 즉시 처리
path_png = dir_path + 'Educational Services by Administrative Dong.png'
exporter = QgsLayoutExporter(layout)
exporter.exportToImage(path_png, QgsLayoutExporter.ImageExportSettings())

