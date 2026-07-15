# GeoDeep을 활용한 정사영상 객체 탐지 실습

## 분석 링크 (Colab)

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/sgisgeodata/sgis-data-manual/blob/main/%EA%B0%9C%EB%B3%84%20%EA%B5%90%EC%9C%A1%EC%9E%90%EB%A3%8C%20Training%20Materials/%28260716%29%20%EA%B4%91%EC%A3%BC%EC%97%B0%EA%B5%AC%EC%9B%90/GeoAI%20%EC%8B%A4%EC%8A%B5/GeoDeep_building/geodeep_gwangju.ipynb)

## 분석 개요

정사영상(GeoTIFF)에 사전학습된 AI 모델을 적용하여 객체를 탐지하고 결과를 지도 위에 시각화


## 활용 데이터

| 데이터             | 설명                                 |
| --------------- | ---------------------------------- |
|buildings.tif | 광주 첨단지구 일대를 클립한 2025년 정사영상 GeoTIFF |

![서울시 인구 행정동별 분석](서울시%20인구%20행정동별%20분석%20지도.png)

## GeoDeep과 GeoAI 개요

### GeoDeep
- GeoTIFF와 같은 지리공간 래스터 데이터를 대상으로 AI 기반 객체 탐지와 의미론적 분할을 수행할 수 있는 Python 오픈소스 라이브러리
- 사전학습 모델을 제공하므로, 별도의 모델 학습 과정 없이 정사영상에서 건물, 도로, 차량 등 특정 객체 탐지 및 분할 가능

| 모델                           | 설명                          |
| ------------------------------ | --------------------------- |
|    detect   | 영상 내 객체의 위치와 종류 탐지          |
| segment | 영상의 각 픽셀을 객체 영역과 배경 영역으로 분류 (빌딩, 도로) |


### GeoAI

- 위성영상, 항공사진, 벡터 데이터 등 공간데이터 기반 AI 분석, 데이터 변환, 지도 시각화를 지원하는 Python 라이브러리
- 이번 실습에서의 주요 활용 용도는 다음과 같음

| 함수                                | 활용 내용                         |
| --------------------------------- | ----------------------------- |
| geoai.raster_to_vector()        | 마스크 GeoTIFF를 GeoJSON 폴리곤으로 변환 |
| geoai.view_vector_interactive() | 원본 정사영상 위에 벡터 결과 중첩 시각화       |


## 분석 절차

1. GitHub의 GeoTIFF 파일을 Colab에서 불러오기
2. GeoDeep `segment()`를 이용한 건물 마스크 생성
3. 픽셀 마스크를 벡터 폴리곤으로 변환
4. GeoDeep `detect()`를 이용한 객체 탐지
5. 탐지 결과 확인 및 시각화
6. 분석 결과를 GeoPackage(`.gpkg`)로 저장 후 QGIS에서 확인

## 분석 결과

### Segment - 건물 마스크 생성

- 정사영상에서 건물로 판단되는 영역을 픽셀 단위 마스크로 생성
- 마스크에서 픽셀값 `1`은 건물로 판단된 영역, 픽셀값 `0`은 건물이 아닌 배경 영역 의미

### Detect - 객체 탐지

- 여러 객체 클래스를 탐지할 수 있는 `waldo30_nano` 모델을 이용하여 정사영상 내 객체 탐지
- 실습 정사영상에서는 `light-vehicle` 소형 차량 112대와 `building` 건물 65개 탐지


## 관련 링크

* GeoDeep: https://github.com/uav4geo/GeoDeep
* GeoAI: https://github.com/opengeos/geoai
* SGIS: https://sgis.mods.go.kr
* GitHub: https://github.com/sgisgeodata/sgis-data-manual
