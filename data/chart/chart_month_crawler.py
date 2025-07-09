import time
import re
import pandas as pd
from selenium import webdriver
from selenium.webdriver.common.by import By
from bs4 import BeautifulSoup
import os

# 한글 주석: 곡 제목/가수 중복 체크를 위한 정규화 함수
def normalize(text):
    # 연속 공백을 하나로, 앞뒤 공백 제거, 소문자 변환
    return re.sub(r'\s+', ' ', text).strip().lower()

# 한글 주석: 이미 저장된 곡(제목+가수) 정보를 불러와 중복 방지
collected_keys = set()
def load_existing_keys(csv_path):
    if os.path.exists(csv_path):
        df = pd.read_csv(csv_path)
        for _, row in df.iterrows():
            key = (normalize(str(row['노래제목'])), normalize(str(row['가수'])))
            collected_keys.add(key)

# 한글 주석: 현재 열린 멜론 월간 차트 페이지에서 곡 정보(최대 10곡, 중복 제외)를 통합 CSV에 누적 저장
def crawl_current_month(driver, csv_path, max_per_month=10):
    print("현재 페이지에서 곡 정보를 크롤링합니다...")
    soup = BeautifulSoup(driver.page_source, 'html.parser')
    titles = driver.find_elements(By.CSS_SELECTOR, '.ellipsis.rank01')
    title_list = [title.text for title in titles][:max_per_month]
    singers = driver.find_elements(By.CSS_SELECTOR, '.ellipsis.rank02')
    singer_list = [singer.text for singer in singers][:max_per_month]
    song_info = soup.find_all('div', {'class': 'ellipsis rank01'})
    songid_list = [re.sub('[^0-9]', '', sid.find('a')['href'].split(',')[1]) for sid in song_info[:max_per_month]]

    lyrics_list = []
    for i, song_id in enumerate(songid_list):
        print(f'{i+1} : {title_list[i]} 가사 수집 중...')
        song_url = f'https://www.melon.com/song/detail.htm?songId={song_id}'
        driver.get(song_url)
        time.sleep(2)
        try:
            driver.find_element(By.CSS_SELECTOR, '.button_more.arrow_d').click()
            time.sleep(2)
            song_soup = BeautifulSoup(driver.page_source, 'html.parser')
            lyric = song_soup.select_one('.lyric')
            if lyric:
                clean_lyric = re.sub('<.*?>', '', str(lyric).replace('<br/>', ' '))
                clean_lyric = re.sub(r'\s+', ' ', clean_lyric).strip()
                lyrics_list.append(clean_lyric)
            else:
                lyrics_list.append('')
        except:
            lyrics_list.append('')

    # 중복 확인 및 누적 저장
    new_rows = []
    for title, singer, lyric in zip(title_list, singer_list, lyrics_list):
        key = (normalize(title), normalize(singer))
        if key not in collected_keys:
            collected_keys.add(key)
            new_rows.append({'노래제목': title, '가수': singer, '가사': lyric})
        else:
            print(f'중복 곡 스킵: {title} - {singer}')

    if new_rows:
        df = pd.DataFrame(new_rows)
        if os.path.exists(csv_path):
            df.to_csv(csv_path, mode='a', header=False, index=False, encoding='utf-8-sig')
        else:
            df.to_csv(csv_path, index=False, encoding='utf-8-sig')
        print(f'누적 저장 완료: {csv_path}')
    else:
        print('새로 저장할 곡이 없습니다.')

if __name__ == "__main__":
    csv_path = 'data/info/all_chart_songs.csv'
    os.makedirs('data/info', exist_ok=True)
    load_existing_keys(csv_path)
    driver = webdriver.Chrome()
    url = "https://www.melon.com/chart/month/index.htm?classCd=GN0000"
    driver.get(url)
    while True:
        input("\n원하는 월을 직접 선택한 후 엔터를 누르세요 (종료하려면 Ctrl+C): ")
        crawl_current_month(driver, csv_path, max_per_month=10)
    driver.quit() 