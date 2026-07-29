import logging
import os
from datetime import datetime

# 1. log 저장 폴더가 없으면 자동 생성
log_dir = r'C:/SGIS/도시화지역/log'
if not os.path.exists(log_dir):
    os.makedirs(log_dir)

# 2. 로거 생성 및 레벨 설정
logger = logging.getLogger('URBAN')
logger.setLevel(logging.DEBUG)

# 기존에 등록된 핸들러가 있다면 제거 (QGIS 재실행 시 중복 핸들러 쌓임 방지)
if logger.hasHandlers():
    logger.handlers.clear()

# 3. 포맷터 설정
formatter = logging.Formatter('%(asctime)s - [%(levelname)s] %(message)s', datefmt='%Y-%m-%d %H:%M:%S')

# 4. 파일 출력 핸들러만 설정 (QGIS 콘솔 출력용 StreamHandler는 제외)
today_date = datetime.today().strftime('%Y-%m-%d')
logfilename = os.path.join(log_dir, f'urban-{today_date}.log')

file_handler = logging.FileHandler(logfilename, encoding='utf-8')
file_handler.setLevel(logging.DEBUG)
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)

# 상위 root 로거로 메시지가 전달되어 콘솔에 남는 현상 방지
logger.propagate = False