# 부산시 인구 격자별 분석 (Python)

서울시 행정동 분석 예제와 달리, 격자(Grid) 단위 인구 데이터를 활용하여 부산시 인구의 공간적 분포를 시각화하는 예제입니다.

## 분석 링크 (Colab)

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/sgisgeodata/sgis-data-manual/blob/main/%EA%B3%B5%EA%B0%84%EB%B6%84%EC%84%9D%20%EC%82%AC%EB%A1%80/Python/%EB%B6%80%EC%82%B0%EC%8B%9C%20%EC%9D%B8%EA%B5%AC%20%EA%B2%A9%EC%9E%90%EB%B3%84%20%EB%B6%84%EC%84%9D/%EB%B6%80%EC%82%B0%EC%8B%9C_%EC%9D%B8%EA%B5%AC_%EA%B2%A9%EC%9E%90%EB%B3%84_%EB%B6%84%EC%84%9D.ipynb)

## 분석 개요

부산시 인구 격자 데이터를 활용하여 인구의 공간적 분포를 시각화합니다.
격자 단위 인구 현황을 분석함으로써 지역별 인구 밀집 특성을 보다 세밀하게 파악할 수 있습니다.

## 활용 데이터

| 데이터              | 설명                 |
| ---------------- | ------------------ |
| grid_pnt부_1K.shp | 부산시 1km 격자 중심점 데이터 |
| grid_pnt부_1K.dbf | 부산시 1km 격자 속성 데이터  |
| 부산시 인구 통계 데이터    | 격자별 인구 정보          |

## 분석 절차

1. 부산시 격자 데이터 불러오기
2. 인구 통계 데이터 불러오기
3. 격자 데이터와 인구 데이터 결합
4. 인구 규모 구간 분류
5. 격자별 인구 분포 시각화

## 분석 결과

![부산시 인구 격자별 분석](부산시%20인구%20격자별%20분석%20지도.png)

## 관련 링크

* SGIS : https://sgis.mods.go.kr
* GitHub : https://github.com/sgisgeodata/sgis-data-manual
* 분석 내용 : https://sgis.mods.go.kr/view/pss/dataBook03
