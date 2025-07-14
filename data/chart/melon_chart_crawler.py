import time
import re
import datetime
from pytz import timezone
import pandas as pd
from selenium import webdriver
from selenium.webdriver.common.by import By
from bs4 import BeautifulSoup
import os

# 한글 주석: 멜론 차트에서 TOP100 곡의 제목, 가수, 가사를 크롤링하는 함수
def melon_collector(url, year):
    print(f'{year} 년도 멜론 TOP100 수집 시작......')
    
    driver = webdriver.Chrome()
    driver.get(url)
    time.sleep(3)
    
    driver.execute_script('window.scrollTo(0,800)')
    time.sleep(3)
    
    html_source = driver.page_source
    soup = BeautifulSoup(html_source, 'html.parser')
    
    titles = driver.find_elements(By.CSS_SELECTOR, '.ellipsis.rank01')
    title_list = [title.text for title in titles][:100]  # TOP100만
    
    singers = driver.find_elements(By.CSS_SELECTOR, '.ellipsis.rank02')
    singer_list = [singer.text for singer in singers][:100]  # TOP100만
    
    song_info = soup.find_all('div', {'class': 'ellipsis rank01'})
    songid_list = [re.sub('[^0-9]', '', sid.find('a')['href'].split(',')[1]) for sid in song_info[:100]]  # TOP100만
    
    lyrics_list = []
    
    for i, song_id in enumerate(songid_list):
        print(f'{i+1} : {title_list[i]} 노래 가사 수집 중...')
        
        song_url = f'https://www.melon.com/song/detail.htm?songId={song_id}'
        driver.get(song_url)
        time.sleep(3)
        
        try:
            driver.find_element(By.CSS_SELECTOR, '.button_more.arrow_d').click()
            time.sleep(3)
            
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
    
    # 한글 주석: 결과를 data/info/chart_song_singer_lyrics.csv로 저장
    save_dir = 'data/info'
    os.makedirs(save_dir, exist_ok=True)
    save_path = os.path.join(save_dir, 'chart_song_singer_lyrics.csv')
    df = pd.DataFrame({'노래제목': title_list, '가수': singer_list, '가사': lyrics_list})
    df.to_csv(save_path, index=False, encoding='utf-8-sig')
    
    print(f'멜론 {year}년 TOP100 수집 완료! 저장 위치: {save_path}')
    driver.close()

if __name__ == "__main__":
    melon_url = "https://www.melon.com/chart/index.htm"
    melon_year = datetime.datetime.now().year
    melon_collector(melon_url, melon_year)
