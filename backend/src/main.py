from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pandas as pd
import boto3
import urllib.parse
from config import API_TITLE, API_VERSION, API_DESCRIPTION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, S3_BUCKET_NAME, S3_LYRICS_PATH, S3_ALBUM_COVER_PATH
import os
from vocal.trimbre_based_recommend import main as recommend_main

app = FastAPI(title=API_TITLE, version=API_VERSION, description=API_DESCRIPTION)

# CORS 허용 (Flutter 개발용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 실제 배포시에는 도메인 제한 권장
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SONG_CSV_PATH = os.path.join(BASE_DIR, '../../data/chart/data/info/all_chart_songs.csv')

class SongDetail(BaseModel):
    title: str
    artist: str
    lyrics: str
    album_cover_url: str
    release_date: str

def get_s3_client():
    return boto3.client(
        's3',
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        region_name=AWS_REGION,
    )

@app.get('/song/{title}/{artist}', response_model=SongDetail)
def get_song_detail(title: str, artist: str):
    try:
        df = pd.read_csv(SONG_CSV_PATH)
        row = df[(df['노래제목'] == title) & (df['가수'] == artist)].iloc[0]
        return SongDetail(
            title=row['노래제목'],
            artist=row['가수'],
            lyrics=row['가사'],
            album_cover_url=row['앨범커버'],
            release_date=row['발매일']
        )
    except Exception as e:
        raise HTTPException(status_code=404, detail='노래 정보를 찾을 수 없습니다.')

@app.get("/api/s3/album_cover")
def get_album_cover_url(artist: str, title: str):
    try:
        s3_client = get_s3_client()
        # 파일명: 가수_노래제목.jpg
        filename = f"{artist}_{title}.jpg"
        key = f"{S3_ALBUM_COVER_PATH}{filename}"
        url = s3_client.generate_presigned_url(
            'get_object',
            Params={"Bucket": S3_BUCKET_NAME, "Key": key},
            ExpiresIn=3600  # 1시간
        )
        return {"url": url}
    except Exception as e:
        raise HTTPException(status_code=404, detail=f'앨범 커버를 찾을 수 없습니다: {str(e)}')

@app.get("/api/s3/lyrics")
def get_lyrics(artist: str, song: str):
    try:
        s3_client = get_s3_client()
        # 가사 파일 경로: lyrics/가수명/가수명_노래제목.srt
        filename = f"{artist}_{song}.srt"
        key = f"{S3_LYRICS_PATH}{artist}/{filename}"
        obj = s3_client.get_object(Bucket=S3_BUCKET_NAME, Key=key)
        lyrics_content = obj["Body"].read().decode('utf-8')
        # SRT 파일 파싱
        lyrics_lines = []
        lines = lyrics_content.strip().split('\n')
        for i in range(len(lines)):
            line = lines[i].strip()
            # 시간 라인 찾기 (00:00:01,000 --> 00:00:04,000 형식)
            if '-->' in line:
                time_parts = line.split(' --> ')
                if len(time_parts) == 2:
                    start_time = parse_srt_time(time_parts[0])
                    # 다음 라인이 가사인지 확인
                    if i + 1 < len(lines):
                        lyric_text = lines[i + 1].strip()
                        if lyric_text and not '-->' in lyric_text:
                            lyrics_lines.append({
                                "time": start_time,
                                "text": lyric_text
                            })
        return {"lyrics": lyrics_lines}
    except Exception as e:
        raise HTTPException(status_code=404, detail=f'가사를 찾을 수 없습니다: {str(e)}')

def parse_srt_time(time_str):
    """SRT 시간 형식을 초 단위로 변환"""
    parts = time_str.split(':')
    if len(parts) == 3:
        hours = int(parts[0])
        minutes = int(parts[1])
        seconds_parts = parts[2].split(',')
        seconds = int(seconds_parts[0])
        milliseconds = int(seconds_parts[1]) if len(seconds_parts) > 1 else 0
        return hours * 3600 + minutes * 60 + seconds + milliseconds / 1000
    return 0.0 

@app.get("/recommend")
def get_recommendation():
    # trimbre_based_recommend.py의 main() 함수가 추천 결과를 반환하도록 수정 필요
    result = recommend_main()
    return result

@app.get("/")
def root():
    return {"message": "Hello, VoiceTrainAI FastAPI!"} 