import time
import re
import pandas as pd
from selenium import webdriver
from selenium.webdriver.common.by import By
from bs4 import BeautifulSoup
import os
import boto3
import requests
from config import AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, S3_BUCKET_NAME

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

# S3 업로드 함수
# 이미지 URL을 받아 S3에 업로드하고, 업로드된 S3 URL을 반환

def upload_image_to_s3(image_url, singer, title, s3_folder="album_cover"):
    try:
        # 파일명을 가수_노래 형식으로 생성 (특수문자 제거)
        safe_singer = re.sub(r'[^\w\s-]', '', singer).strip()
        safe_title = re.sub(r'[^\w\s-]', '', title).strip()
        file_name = f"{safe_singer}_{safe_title}.jpg"
        
        # 이미지 다운로드
        response = requests.get(image_url, stream=True, timeout=10)
        if response.status_code == 200:
            s3_key = f"{s3_folder}/{file_name}"
            s3 = boto3.client(
                's3',
                aws_access_key_id=AWS_ACCESS_KEY_ID,
                aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
                region_name=AWS_REGION
            )
            
            # BytesIO를 사용하여 메모리에서 업로드
            from io import BytesIO
            image_data = BytesIO(response.content)
            image_data.seek(0)
            
            s3.upload_fileobj(image_data, S3_BUCKET_NAME, s3_key, ExtraArgs={'ContentType': 'image/jpeg'})
            s3_url = f"https://{S3_BUCKET_NAME}.s3.{AWS_REGION}.amazonaws.com/{s3_key}"
            print(f"S3 업로드 성공: {file_name}")
            return s3_url
        else:
            print(f"이미지 다운로드 실패: {image_url} (상태코드: {response.status_code})")
            return ''
    except Exception as e:
        print(f"S3 업로드 실패: {e}")
        return ''

# 한글 주석: 현재 열린 멜론 월간 차트 페이지에서 곡 정보(최대 10곡, 중복 제외)를 통합 CSV에 누적 저장
def crawl_current_month(driver, csv_path, max_per_month=10):
    print("현재 페이지에서 곡 정보를 크롤링합니다...")
    
    # 페이지가 완전히 로드될 때까지 대기
    time.sleep(5)
    
    soup = BeautifulSoup(driver.page_source, 'html.parser')
    titles = driver.find_elements(By.CSS_SELECTOR, '.ellipsis.rank01')
    title_list = [title.text for title in titles][:max_per_month]
    singers = driver.find_elements(By.CSS_SELECTOR, '.ellipsis.rank02')
    singer_list = [singer.text for singer in singers][:max_per_month]
    song_info = soup.find_all('div', {'class': 'ellipsis rank01'})
    
    # 안전하게 곡 ID 추출
    songid_list = []
    for sid in song_info[:max_per_month]:
        a_tag = sid.find('a')
        if a_tag and a_tag.has_attr('href'):
            try:
                href = a_tag['href']
                song_id = re.sub('[^0-9]', '', href.split(',')[1])
                songid_list.append(song_id)
            except (IndexError, AttributeError) as e:
                print(f"곡 ID 추출 실패: {e}")
                songid_list.append('')
        else:
            songid_list.append('')

    # 앨범 커버 썸네일 추출 (리스트 썸네일)
    # 곡 리스트에서 앨범 커버 img 태그는 .image_typeAll img 셀렉터로 접근 가능
    album_imgs = driver.find_elements(By.CSS_SELECTOR, '.image_typeAll img')
    album_img_urls = [img.get_attribute('src') for img in album_imgs][:max_per_month]

    # 발매일 정보와 가사 수집
    release_dates = []
    lyrics_list = []
    
    for i, song_id in enumerate(songid_list):
        if not song_id:
            release_dates.append('')
            lyrics_list.append('')
            continue
            
        print(f'{i+1} : {title_list[i]} 정보 수집 중...')
        song_url = f'https://www.melon.com/song/detail.htm?songId={song_id}'
        driver.get(song_url)
        time.sleep(3)  # 페이지 로딩 대기 시간 증가
        
        try:
            # 발매일 정보 추출
            song_soup = BeautifulSoup(driver.page_source, 'html.parser')
            
            # 발매일 정보를 찾는 더 많은 셀렉터 시도
            release_date = ''
            release_selectors = [
                '.meta dd:nth-child(2)',  # 기본 2번째 dd
                '.meta dd:nth-child(4)',  # 4번째 dd
                '.meta dd:nth-child(6)',  # 6번째 dd
                '.info dd:nth-child(2)',  # info 클래스의 2번째 dd
                '.info dd:nth-child(4)',  # info 클래스의 4번째 dd
                '.song_info dd:nth-child(2)',  # song_info 클래스
                '.song_info dd:nth-child(4)',  # song_info 클래스
                '.wrap_info dd:nth-child(2)',  # wrap_info 클래스
                '.wrap_info dd:nth-child(4)',  # wrap_info 클래스
                '.wrap_info dd:nth-child(6)',  # wrap_info 클래스
                '.wrap_info dd:nth-child(8)',  # wrap_info 클래스
            ]
            
            # 먼저 모든 meta dd와 info dd를 확인
            all_dds = song_soup.select('.meta dd, .info dd, .song_info dd, .wrap_info dd')
            print(f"  발견된 dd 요소들: {len(all_dds)}개")
            
            for i, dd in enumerate(all_dds):
                text = dd.text.strip()
                print(f"    dd[{i}]: {text}")
                # 발매일 검색 조건 개선: YYYY.MM.DD 또는 YYYY-MM-DD 형식도 포함
                if ('발매' in text or 
                    ('년' in text and '월' in text and '일' in text) or
                    re.match(r'\d{4}[.-]\d{2}[.-]\d{2}', text)):  # YYYY.MM.DD 또는 YYYY-MM-DD 형식
                    release_date = text
                    print(f"  발매일 발견: {release_date}")
                    break
            
            # 위에서 찾지 못했다면 셀렉터로 시도
            if not release_date:
                for selector in release_selectors:
                    try:
                        release_info = song_soup.select_one(selector)
                        if release_info:
                            text = release_info.text.strip()
                            print(f"  셀렉터 {selector}: {text}")
                            if ('발매' in text or 
                                ('년' in text and '월' in text and '일' in text) or
                                re.match(r'\d{4}[.-]\d{2}[.-]\d{2}', text)):  # YYYY.MM.DD 또는 YYYY-MM-DD 형식
                                release_date = text
                                print(f"  발매일 발견: {release_date}")
                                break
                    except Exception as e:
                        print(f"  셀렉터 {selector} 오류: {e}")
                        continue
            
            release_dates.append(release_date)
            if not release_date:
                print(f"  발매일 정보를 찾을 수 없음 - 모든 dd 요소 확인 완료")
            
            # 가사 수집
            try:
                driver.find_element(By.CSS_SELECTOR, '.button_more.arrow_d').click()
                time.sleep(2)
                song_soup = BeautifulSoup(driver.page_source, 'html.parser')
                lyric = song_soup.select_one('.lyric')
                if lyric:
                    # 줄바꿈 유지하면서 HTML 태그만 제거
                    clean_lyric = str(lyric).replace('<br/>', '\n').replace('<br>', '\n').replace('<br />', '\n')
                    clean_lyric = re.sub('<.*?>', '', clean_lyric)  # HTML 태그 제거
                    clean_lyric = re.sub(r'[ \t]+', ' ', clean_lyric)  # 연속 공백만 정리 (줄바꿈은 유지)
                    clean_lyric = clean_lyric.strip()
                    lyrics_list.append(clean_lyric)
                else:
                    lyrics_list.append('')
            except:
                lyrics_list.append('')
                
        except Exception as e:
            print(f"  곡 정보 수집 실패: {e}")
            release_dates.append('')
            lyrics_list.append('')

    # S3 업로드 및 S3 URL 리스트 생성 (곡별로 바로 저장)
    for i, (title, singer, img_url, lyric, release_date) in enumerate(zip(title_list, singer_list, album_img_urls, lyrics_list, release_dates)):
        key = (normalize(title), normalize(singer))
        if key in collected_keys:
            print(f'중복 곡 스킵: {title} - {singer}')
            continue
        collected_keys.add(key)
        print(f'{i+1} : 앨범 커버 S3 업로드 중...')
        album_cover_url = upload_image_to_s3(img_url, singer, title)
        print(f'앨범커버 S3 URL: {album_cover_url}')  # 추가
        # 곡 정보 바로 저장
        row = {
            '노래제목': title,
            '가수': singer,
            '가사': lyric,
            '앨범커버': album_cover_url,
            '발매일': release_date
        }
        df = pd.DataFrame([row])
        file_exists = os.path.exists(csv_path)
        df.to_csv(csv_path, mode='a', header=not file_exists, index=False, encoding='utf-8-sig')
        print(f'저장 완료: {title} - {singer}')

    print(f'크롤링 완료! 파일 위치: {csv_path}')

if __name__ == "__main__":
    csv_path = 'data/info/all_chart_songs.csv'
    os.makedirs('data/info', exist_ok=True)
    load_existing_keys(csv_path)
    driver = webdriver.Chrome()
    url = "https://www.melon.com/chart/month/index.htm?classCd=GN0000"
    driver.get(url)
    try:
        while True:
            input("\n원하는 월을 직접 선택한 후 엔터를 누르세요 (종료하려면 Ctrl+C): ")
            crawl_current_month(driver, csv_path, max_per_month=100)
            print("한 번 더 크롤링하려면 월을 바꾼 뒤 엔터, 종료하려면 Ctrl+C")
    except KeyboardInterrupt:
        print("크롤링 종료")
        driver.quit()