# GeoAI를 활용한 Sentinel-2 수체 탐지 실습

## 분석 링크 (Colab)

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/sgisgeodata/sgis-data-manual/blob/main/%EA%B0%9C%EB%B3%84%20%EA%B5%90%EC%9C%A1%EC%9E%90%EB%A3%8C%20Training%20Materials/%28260716%29%20%EA%B4%91%EC%A3%BC%EC%97%B0%EA%B5%AC%EC%9B%90/GeoAI%20%EC%8B%A4%EC%8A%B5/GeoAI_water/geoai_gwangju.ipynb)

## 분석 개요
- Google Earth Engine에서 Sentinel-2 위성영상을 불러오기
- GeoAI 사전학습 모델을 적용하여 수체 영역 탐지

## 활용 데이터

- 데이터: Sentinel-2 위성영상
- Earth Engine 컬렉션: `COPERNICUS/S2_SR_HARMONIZED` (구름비율 20% 미만)
- 분석 지역: 영월 청령포 일대
- 입력 밴드: B4(Red), B3(Green), B2(Blue), B8(NIR)

* 저장 경로: `개별 교육자료 Training Materials/(260716) 광주연구원/GeoAI 실습/GeoAI_water/cheongnyeongpo_sentinel2_rgbnir.tif`

![영월 청령포 위성사진](영월%20청령포%20위성사진.png)

## Sentinel-2와 GeoAI 개요

### Sentinel-2

* 유럽우주국(ESA)의 다중분광 지구관측 위성
* RGB뿐 아니라 근적외선(NIR), 단파적외선(SWIR) 등 여러 파장대의 정보 제공
* 이번 실습에서는 수체 탐지 모델의 입력에 필요한 B4, B3, B2, B8 밴드 사용

| 입력 순서 | Sentinel-2 밴드 | 파장 영역 | 
| ----: | ------------- | ----- | 
|     1 | B4            | Red   | 
|     2 | B3            | Green | 
|     3 | B2            | Blue  | 
|     4 | B8            | NIR   |  


### GeoAI

* 위성영상, 항공사진, 래스터 및 벡터 데이터의 AI 분석과 지도 시각화를 지원하는 Python 라이브러리
* 이번 실습에서는 사전학습된 수체 탐지 모델을 이용해 Sentinel-2 영상의 수체 영역 탐지

| 함수                                | 활용 내용                           |
| --------------------------------- | ------------------------------- |
| `geoai.object_detection()`        | 4밴드 Sentinel-2 영상에서 수체 마스크 생성   |
| `geoai.raster_to_vector()`        | 수체 탐지 GeoTIFF를 GeoJSON 폴리곤으로 변환 |
| `geoai.view_raster()`             | GeoTIFF 영상 확인                   |
| `geoai.view_vector_interactive()` | 원본 영상 위에 수체 폴리곤 중첩 시각화          |

### water_detection.pth

* 수체와 비수체의 특징을 학습한 사전학습 모델 파일
* RGB와 NIR로 구성된 4밴드 영상을 입력으로 사용
* 입력 영상을 작은 영역으로 나누어 분석한 뒤 수체로 판단된 픽셀을 래스터 마스크로 생성
* 주요 모델 파라미터

| 설정                     |   값 | 설명                                 |
| ---------------------- | --: | ---------------------------------- |
| `window_size`          | 128 | 영상을 128×128 픽셀 단위로 분할하여 분석         |
| `overlap`              |  32 | 인접 영상 조각을 중첩하여 경계 부분의 탐지 누락 완화     |
| `confidence_threshold` | 0.9 | 수체로 판단할 최소 신뢰도                     |
| `batch_size`           |   1 | 한 번에 처리하는 영상 조각 수                  |
| `num_channels`         |   4 | 입력 영상의 밴드 수(Red, Green, Blue, NIR) |

## 분석 절차

1. Google Earth Engine 인증 및 프로젝트 초기화
2. 영월 청령포 일대의 관심 영역(ROI) 설정
3. Sentinel-2 영상 검색 및 QA60 밴드 기반 구름 제거
4. 구름 비율이 가장 낮은 영상 선택
5. B4, B3, B2, B8 밴드 추출 및 8비트 영상 변환
6. Sentinel-2 영상을 4밴드 GeoTIFF로 저장
7. GeoAI `object_detection()`을 이용한 수체 마스크 생성
8. 래스터 마스크를 GeoJSON 폴리곤으로 변환
9. 탐지 결과 확인 및 시각화 



## 분석 결과

### 수체 마스크 생성

* 모델이 수체로 판단한 영역을 픽셀 단위의 래스터 마스크로 생성
* 픽셀값 `1`은 수체 영역, 픽셀값 `0`은 비수체 영역을 의미

![수체 탐지 결과 마스크](수체%20탐지%20결과%20마스크.png)


### 수체 폴리곤 변환

* 픽셀 기반 수체 마스크를 GeoJSON 폴리곤으로 변환

* 변환된 건물 폴리곤을 원본 정사영상 위에 중첩하여 시각화

![수체 탐지 결과](수체%20탐지%20결과%20.png)





## 실행 전 준비사항

* Google 계정 로그인
* [Google Earth Engine ](https://console.cloud.google.com/earth-engine/welcome) 접속
* 구성탭 → 새 프로젝트 만들기 → 프로젝트 ID 설정 → 비상업용으로 등록

노트북의 다음 코드는 본인의 Earth Engine 프로젝트 ID에 맞게 수정해야 합니다.

```python
ee.Initialize(project="프로젝트_ID")
```

## 관련 링크

* GeoAI: https://github.com/opengeos/geoai
* Google Earth Engine: https://earthengine.google.com/
* Sentinel-2 SR Harmonized: https://developers.google.com/earth-engine/datasets/catalog/COPERNICUS_S2_SR_HARMONIZED
* SGIS: https://sgis.mods.go.kr
* GitHub: https://github.com/sgisgeodata/sgis-data-manual
  ::: 

