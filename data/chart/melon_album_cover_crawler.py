import os
import requests
from bs4 import BeautifulSoup
import boto3
import pandas as pd
from urllib.parse import quote_plus
from config import AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, S3_BUCKET_NAME
from PIL import Image
from io import BytesIO
import re

def search_album_cover(artist, song_name):
    # 가수명과 노래명을 조합하여 검색 쿼리 생성
    query = quote_plus(f"{artist} {song_name} album cover")
    url = f"https://www.google.com/search?q={query}&tbm=isch"
    headers = {"User-Agent": "Mozilla/5.0"}
    resp = requests.get(url, headers=headers)
    soup = BeautifulSoup(resp.text, "html.parser")
    img_tags = soup.find_all("img")
    # 2~4번째 이미지를 우선적으로 시도 (첫 번째는 구글 로고일 수 있음)
    for img_tag in img_tags[1:4]:
        if isinstance(img_tag, bs4.element.Tag):
            img_url = img_tag.get("src")
            if isinstance(img_url, str) and img_url.startswith("http"):
                return img_url
    return None

def download_and_convert_image(img_url, save_path):
    resp = requests.get(img_url)
    if resp.status_code == 200:
        img = Image.open(BytesIO(resp.content))
        img = img.convert("RGB")  # jpg로 변환
        img.save(save_path, "JPEG")
        return True
    return False

def upload_to_s3(file_path, s3_key):
    s3 = boto3.client(
        "s3",
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        region_name=AWS_REGION
    )
    s3.upload_file(file_path, S3_BUCKET_NAME, s3_key)
    url = f"https://{S3_BUCKET_NAME}.s3.{AWS_REGION}.amazonaws.com/{s3_key}"
    return url

def get_song_list_from_s3_original():
    s3 = boto3.client(
        "s3",
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        region_name=AWS_REGION
    )
    # original/ 이하 모든 객체 조회
    response = s3.list_objects_v2(Bucket=S3_BUCKET_NAME, Prefix="original/")
    song_list = []
    for obj in response.get('Contents', []):
        key = obj['Key']
        if key.endswith('/'):
            continue  # 폴더는 제외

        parts = key.split('/')
        if len(parts) < 3:
            continue  # original/가수명/파일명
        artist = parts[1]
        filename = parts[2]
        song_name = filename.rsplit('.', 1)[0]
        song_list.append((artist, song_name))
    return song_list

def safe_filename(filename):
    # 윈도우에서 허용되지 않는 문자 제거 및 공백/특수문자 대체
    filename = re.sub(r'[\\/:*?"<>|]', '', filename)
    filename = filename.replace(' ', '_')
    return filename

def get_uploaded_cover_set():
    s3 = boto3.client(
        "s3",
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        region_name=AWS_REGION
    )
    uploaded = set()
    paginator = s3.get_paginator('list_objects_v2')
    for page in paginator.paginate(Bucket=S3_BUCKET_NAME, Prefix="album_covers/"):
        for obj in page.get('Contents', []):
            filename = obj['Key'].split('/')[-1]
            if filename.endswith('.jpg'):
                uploaded.add(filename)
    return uploaded

def main(log_csv="album_cover_log.csv"):
    logs = []
    song_list = get_song_list_from_s3_original()
    uploaded_set = get_uploaded_cover_set()
    for artist, song_name in song_list:
        print(f"Processing: {artist} - {song_name}")
        raw_name = f"{artist}-{song_name}"
        safe_name = safe_filename(raw_name)
        jpg_filename = f"{safe_name}.jpg"
        if jpg_filename in uploaded_set:
            print(f"Already uploaded: {jpg_filename}, skipping.")
            logs.append({"artist": artist, "album": song_name, "s3_url": f"https://{S3_BUCKET_NAME}.s3.{AWS_REGION}.amazonaws.com/album_covers/{jpg_filename}", "status": "Already exists"})
            continue
        img_url = search_album_cover(artist, song_name)
        if not img_url:
            print(f"Image not found for {artist} - {song_name}")
            logs.append({"artist": artist, "album": song_name, "s3_url": None, "status": "Image not found"})
            continue
        img_path = f"{safe_name}.jpg"
        if not download_and_convert_image(img_url, img_path):
            print(f"Download failed for {artist} - {song_name}")
            logs.append({"artist": artist, "album": song_name, "s3_url": None, "status": "Download failed"})
            continue
        s3_key = f"album_covers/{safe_name}.jpg"
        try:
            s3_url = upload_to_s3(img_path, s3_key)
            logs.append({"artist": artist, "album": song_name, "s3_url": s3_url, "status": "Success"})
            print(f"Uploaded to S3: {s3_url}")
        except Exception as e:
            print(f"S3 upload failed for {artist} - {song_name}: {e}")
            logs.append({"artist": artist, "album": song_name, "s3_url": None, "status": f"S3 upload failed: {e}"})
        os.remove(img_path)
    df = pd.DataFrame(logs)
    df.to_csv(log_csv, index=False, encoding='utf-8-sig')
    print(f"Log saved to {log_csv}")

if __name__ == "__main__":
    main()

# 커밋 테스트용 주석입니다.