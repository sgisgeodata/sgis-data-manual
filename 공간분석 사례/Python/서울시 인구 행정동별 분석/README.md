# 서울시 인구 행정동별 분석 (Python)


## 분석 링크

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/sgisgeodata/sgis-data-manual/blob/main/%EA%B3%B5%EA%B0%84%EB%B6%84%EC%84%9D%20%EC%82%AC%EB%A1%80/Python/%EC%84%9C%EC%9A%B8%EC%8B%9C%20%EC%9D%B8%EA%B5%AC%20%ED%96%89%EC%A0%95%EB%8F%99%EB%B3%84%20%EB%B6%84%EC%84%9D/%EC%84%9C%EC%9A%B8%EC%8B%9C_%EC%9D%B8%EA%B5%AC_%ED%96%89%EC%A0%95%EB%8F%99%EB%B3%84_%EB%B6%84%EC%84%9D.ipynb)


## 분석 개요

행정동 경계 데이터와 인구 통계 데이터를 결합하여 서울시 인구 분포를 시각화합니다.


## 활용 데이터

| 데이터                        | 설명             |
| -------------------------- | -------------- |
| bnd_dong_11_2025_2Q.shp    | 서울시 행정동 경계 데이터 |
| bnd_sigungu_11_2025_2Q.shp | 서울시 시군구 경계 데이터 |
| 11_2024년_인구총괄(총인구).csv     | 서울시 인구 통계 데이터  |


## 분석 절차

1. 서울시 경계 및 통계 데이터 불러오기
2. 통계 데이터 전처리
3. 행정동 경계와 통계 데이터 결합
4. 총인구수 구간 나누기
5. 행정동별 인구 분포 시각화


## 분석 결과

![서울시 인구 행정동별 분석](서울시%20인구%20행정동별%20분석%20지도.png)


## 관련 링크

* SGIS : https://sgis.mods.go.kr
* GitHub : https://github.com/sgisgeodata/sgis-data-manual
* 분석 내용 : https://sgis.mods.go.kr/view/pss/dataBook03
