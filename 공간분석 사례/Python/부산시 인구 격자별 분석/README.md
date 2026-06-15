# 부산시 인구 격자별 분석 (Python)

## 분석 링크 (Colab)

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/sgisgeodata/sgis-data-manual/blob/main/%EA%B3%B5%EA%B0%84%EB%B6%84%EC%84%9D%20%EC%82%AC%EB%A1%80/Python/%EB%B6%80%EC%82%B0%EC%8B%9C%20%EC%9D%B8%EA%B5%AC%20%EA%B2%A9%EC%9E%90%EB%B3%84%20%EB%B6%84%EC%84%9D/%EB%B6%80%EC%82%B0%EC%8B%9C_%EC%9D%B8%EA%B5%AC_%EA%B2%A9%EC%9E%90%EB%B3%84_%EB%B6%84%EC%84%9D.ipynb)

## 분석 개요

SGIS 자료제공 메뉴에서 제공하는 부산시 시군구 경계 데이터(`bnd_sigungu_21_2025_2Q.shp`), 1km 격자 경계 데이터(`grid_마라_1K.shp`, `grid_마마_1K.shp`) 및 2024년 격자통계 데이터(`2024년_인구_마라_1K.csv`, `2024년_인구_마마_1K.csv`)를 활용하여 부산시 인구의 공간적 분포를 분석하는 예제입니다.

## 활용 데이터

| 데이터                        | 설명                |
| -------------------------- | ----------------- |
| bnd_sigungu_21_2025_2Q.shp | 부산시 시군구 경계 데이터    |
| grid_마라_1K.shp             | 부산시 1km 격자 경계 데이터 |
| grid_마마_1K.shp             | 부산시 1km 격자 경계 데이터 |
| 2024년_인구_마라_1K.csv         | 부산시 격자통계 인구 데이터   |
| 2024년_인구_마마_1K.csv         | 부산시 격자통계 인구 데이터   |

## 분석 절차

1. 분석 환경 구성
2. 부산시 경계 및 격자 데이터 불러오기
3. 격자통계 데이터 불러오기
4. 공간데이터와 통계데이터 결합
5. 인구 규모 구간 분류
6. 격자별 인구 분포 시각화
7. 시군구 경계 중첩 및 결과 지도 생성

## 분석 결과

![부산시 인구 격자별 분석](부산시%20인구%20격자별%20분석%20지도.png)

## 관련 링크

* SGIS : https://sgis.mods.go.kr
* GitHub : https://github.com/sgisgeodata/sgis-data-manual
* 분석 내용 : https://sgis.mods.go.kr/view/pss/dataBook03
