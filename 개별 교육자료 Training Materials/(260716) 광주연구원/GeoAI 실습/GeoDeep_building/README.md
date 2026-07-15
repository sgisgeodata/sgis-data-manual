# GeoDeep을 활용한 정사영상 객체 탐지 실습

## 분석 링크

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/sgisgeodata/sgis-data-manual/blob/main/%EA%B0%9C%EB%B3%84%20%EA%B5%90%EC%9C%A1%EC%9E%90%EB%A3%8C%20Training%20Materials/%28260716%29%20%EA%B4%91%EC%A3%BC%EC%97%B0%EA%B5%AC%EC%9B%90/GeoAI%20%EC%8B%A4%EC%8A%B5/GeoDeep_building/geodeep_gwangju.ipynb)

## 분석 개요

2025년에 촬영한 광주지역 정사영상 GeoTIFF를 활용하여 GeoDeep의 사전학습 AI 모델을 적용하고, 건물 마스크 생성 및 객체 탐지 결과를 공간정보 형태로 저장·시각화하는 실습

이번 실습에서는 `segment()`를 이용한 건물 마스크 생성, `detect()`를 이용한 객체 탐지, GeoAI를 활용한 래스터-벡터 변환 및 지도 기반 시각화 수행

## 활용 데이터

| 데이터             | 설명                                 |
| --------------- | ---------------------------------- |
| `buildings.tif` | 광주 첨단지구 일대를 클립한 2025년 정사영상 GeoTIFF |

## GeoDeep과 GeoAI 개요

이번 실습에서는 정사영상 분석을 위해 **GeoDeep**과 **GeoAI**를 함께 활용

### GeoDeep

[GeoDeep GitHub](https://github.com/uav4geo/GeoDeep)

**GeoDeep**은 GeoTIFF와 같은 지리공간 래스터 데이터를 대상으로 AI 기반 객체 탐지와 의미론적 분할을 수행할 수 있는 Python 오픈소스 라이브러리

GeoDeep은 사전학습 모델을 제공하므로, 별도의 모델 학습 과정 없이 정사영상에서 건물, 도로, 차량 등 특정 객체 탐지 및 분할 가능

| 기능                             | 설명                          |
| ------------------------------ | --------------------------- |
| 객체 탐지(Object Detection)        | 영상 내 객체의 위치와 종류 탐지          |
| 의미론적 분할(Semantic Segmentation) | 영상의 각 픽셀을 객체 영역과 배경 영역으로 분류 |

이번 실습에서는 `segment()` 함수를 이용한 건물 마스크 생성과 `detect()` 함수를 이용한 객체 탐지 수행

### GeoAI

[GeoAI GitHub](https://github.com/opengeos/geoai)

**GeoAI**는 위성영상, 항공사진, 벡터 데이터 등 공간데이터 기반 AI 분석, 데이터 변환, 지도 시각화를 지원하는 Python 라이브러리

이번 실습에서의 주요 활용 내용은 다음과 같음

| 함수                                | 활용 내용                         |
| --------------------------------- | ----------------------------- |
| `geoai.download_file()`           | GitHub에 있는 GeoTIFF 파일 다운로드    |
| `geoai.raster_to_vector()`        | 마스크 GeoTIFF를 GeoJSON 폴리곤으로 변환 |
| `geoai.view_vector_interactive()` | 원본 정사영상 위에 벡터 결과 중첩 시각화       |

즉, **GeoDeep은 AI 모델 실행**, **GeoAI는 데이터 다운로드·변환·시각화 보조** 역할

## 분석 절차

1. GitHub의 GeoTIFF 파일을 Colab에서 불러오기
2. GeoDeep `segment()`를 이용한 건물 마스크 생성
3. 픽셀 마스크를 벡터 폴리곤으로 변환
4. GeoDeep `detect()`를 이용한 객체 탐지
5. 탐지 결과 확인 및 시각화
6. 분석 결과를 GeoPackage(`.gpkg`)로 저장 후 QGIS에서 확인

## 분석 결과

### Segment - 건물 마스크 생성

`segment()`를 이용하여 정사영상에서 건물로 판단되는 영역을 픽셀 단위 마스크로 생성

마스크에서 픽셀값 `1`은 건물로 판단된 영역, 픽셀값 `0`은 건물이 아닌 배경 영역 의미

생성된 마스크는 원본 정사영상의 좌표계와 위치정보를 참조하여 `building_mask.tif`로 저장한 뒤, GeoJSON 벡터 폴리곤으로 변환

### Detect - 객체 탐지

`detect()`와 `waldo30_nano` 모델을 이용하여 정사영상 내 객체 탐지

`waldo30_nano`는 차량, 사람, 건물, 선박, 자전거, 트럭, 태양광 패널 등 여러 객체 클래스를 탐지할 수 있는 사전학습 객체 탐지 모델

탐지 결과 주요 컬럼은 다음과 같음

| 컬럼명        | 설명                   |
| ---------- | -------------------- |
| `class`    | 탐지된 객체의 종류           |
| `score`    | 모델이 해당 객체라고 판단한 신뢰도  |
| `geometry` | 탐지된 객체의 공간 위치와 형태 정보 |

해당 정사영상에서는 `light-vehicle` 소형 차량 112대와 `building` 건물 65개 탐지

## 결과 파일

| 파일명                    | 설명                           |
| ---------------------- | ---------------------------- |
| `building_mask.tif`    | 좌표정보가 포함된 건물 마스크 GeoTIFF     |
| `building.geojson`     | 건물 마스크를 벡터 폴리곤으로 변환한 GeoJSON |
| `building_result.gpkg` | QGIS에서 확인 가능한 건물 마스크 벡터 결과   |
| `waldo_result.gpkg`    | QGIS에서 확인 가능한 객체 탐지 결과       |

## QGIS 활용

분석 결과를 QGIS에서 확인하기 위해 GeoPackage(`.gpkg`) 형식으로 저장

GeoPackage는 하나의 파일 안에 여러 개의 공간데이터 레이어를 저장할 수 있는 형식으로, 실습 결과를 QGIS에서 불러와 원본 정사영상과 함께 확인 가능

## 실습 결과 해석

사전학습 모델의 결과는 영상 해상도, 촬영 지역, 객체의 형태 등에 따라 달라질 수 있음

따라서 이번 실습 결과는 오픈소스 기반 AI 모델을 공간영상 분석에 적용해보는 예시로 해석

## 관련 링크

* GeoDeep: https://github.com/uav4geo/GeoDeep
* GeoAI: https://github.com/opengeos/geoai
* SGIS: https://sgis.mods.go.kr
* GitHub: https://github.com/sgisgeodata/sgis-data-manual
