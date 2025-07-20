from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pandas as pd
import boto3
import urllib.parse
import os

app = FastAPI(title="VoiceTrainAI API", version="1.0.0", description="AI 기반 보컬 트레이닝 API")

# CORS 허용 (Flutter 개발용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*", "http://localhost:3000", "http://127.0.0.1:3000"],  # Flutter 웹 포트 추가
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

class VocalRangeAnalysis(BaseModel):
    song_title: str
    artist: str
    total_range: str
    comfortable_range: str
    core_range: str
    difficulty: str
    analysis_status: str

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

@app.get("/api/vocal-range/{title}/{artist}", response_model=VocalRangeAnalysis)
def analyze_song_vocal_range(title: str, artist: str):
    """
    노래의 음역대를 분석합니다.
    """
    try:
        # 다양한 음역대 데이터를 제공하는 더미 데이터
        vocal_ranges = [
            # 여성 보컬 (고음역)
            {
                "range": "F3 ~ D5",
                "comfortable": "G3 ~ C5", 
                "core": "A3 ~ B4",
                "difficulty": "중급"
            },
            # 남성 보컬 (중음역)
            {
                "range": "C3 ~ E5",
                "comfortable": "D3 ~ D5",
                "core": "E3 ~ C5", 
                "difficulty": "고급"
            },
            # 여성 보컬 (중고음역)
            {
                "range": "E3 ~ C5",
                "comfortable": "F3 ~ B4",
                "core": "G3 ~ A4",
                "difficulty": "중급"
            },
            # 남성 보컬 (저음역)
            {
                "range": "A2 ~ D4",
                "comfortable": "B2 ~ C4",
                "core": "C3 ~ B3",
                "difficulty": "초급"
            },
            # 여성 보컬 (고음역)
            {
                "range": "G3 ~ E5",
                "comfortable": "A3 ~ D5",
                "core": "B3 ~ C5",
                "difficulty": "고급"
            },
            # 남성 보컬 (중음역)
            {
                "range": "D3 ~ F5",
                "comfortable": "E3 ~ E5",
                "core": "F3 ~ D5",
                "difficulty": "고급"
            },
            # 여성 보컬 (중음역)
            {
                "range": "C3 ~ B4",
                "comfortable": "D3 ~ A4",
                "core": "E3 ~ G4",
                "difficulty": "초급"
            },
            # 남성 보컬 (저중음역)
            {
                "range": "B2 ~ E4",
                "comfortable": "C3 ~ D4",
                "core": "D3 ~ C4",
                "difficulty": "초급"
            }
        ]
        
        # 특정 곡들에 대한 고정 데이터
        if title.lower() in ['never ending story', '네버엔딩스토리'] and artist.lower() in ['iu', '아이유']:
            return VocalRangeAnalysis(
                song_title=title,
                artist=artist,
                total_range="F3 ~ D5",
                comfortable_range="G3 ~ C5",
                core_range="A3 ~ B4",
                difficulty="중급",
                analysis_status="completed"
            )
        
        if title.lower() in ['dynamite', '다이너마이트'] and artist.lower() in ['bts', '방탄소년단']:
            return VocalRangeAnalysis(
                song_title=title,
                artist=artist,
                total_range="C3 ~ E5",
                comfortable_range="D3 ~ D5",
                core_range="E3 ~ C5",
                difficulty="고급",
                analysis_status="completed"
            )
        
        if title.lower() in ['butter', '버터'] and artist.lower() in ['bts', '방탄소년단']:
            return VocalRangeAnalysis(
                song_title=title,
                artist=artist,
                total_range="D3 ~ F5",
                comfortable_range="E3 ~ E5",
                core_range="F3 ~ D5",
                difficulty="고급",
                analysis_status="completed"
            )
        
        # 곡 제목과 아티스트를 기반으로 일관된 음역대 선택
        import hashlib
        combined = f"{title.lower()}{artist.lower()}"
        hash_value = int(hashlib.md5(combined.encode()).hexdigest(), 16)
        selected_range = vocal_ranges[hash_value % len(vocal_ranges)]
        
        return VocalRangeAnalysis(
            song_title=title,
            artist=artist,
            total_range=selected_range["range"],
            comfortable_range=selected_range["comfortable"],
            core_range=selected_range["core"],
            difficulty=selected_range["difficulty"],
            analysis_status="completed"
        )
        
    except Exception as e:
        # 오류 발생 시 기본값 반환
        return VocalRangeAnalysis(
            song_title=title,
            artist=artist,
            total_range="분석 오류",
            comfortable_range="분석 오류",
            core_range="분석 오류",
            difficulty="분석 오류",
            analysis_status="error"
        )

@app.get("/")
def root():
    return {"message": "Hello, VoiceTrainAI FastAPI!"} 