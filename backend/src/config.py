# backend/src/vocal/config.py
import os
from dotenv import load_dotenv

# .env 파일 로드
load_dotenv()

# AWS S3 설정 - 환경 변수에서 가져오기
AWS_ACCESS_KEY_ID = os.getenv('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.getenv('AWS_SECRET_ACCESS_KEY')
AWS_REGION = os.getenv('AWS_REGION', 'ap-northeast-2')
S3_BUCKET_NAME = os.getenv('S3_BUCKET_NAME', 'ai-vocal-training')

REGION_NAME = os.getenv('AWS_REGION', 'ap-northeast-2')
BUCKET_NAME = os.getenv('S3_BUCKET_NAME', 'ai-vocal-training')

# S3 경로 설정
S3_LYRICS_PATH = 'lyrics/'
S3_ALBUM_COVER_PATH = 'album_cover/'
S3_MUSIC_FILE_PATH = 'MusicFile/'
S3_INST_PATH = 'inst/'
S3_MIDI_PATH = 'midi/'
S3_ORIGINAL_PATH = 'original/'

# FastAPI 설정
API_TITLE = "VoiceTrainingAI API"
API_VERSION = "1.0.0"
API_DESCRIPTION = "AI보컬 트레이닝 앱의 백엔드 API" 