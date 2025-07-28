<<<<<<< HEAD
# AWS S3 설정
import os
from dotenv import load_dotenv

# .env 파일 로드
load_dotenv()

AWS_ACCESS_KEY = os.getenv('AWS_ACCESS_KEY_ID')
AWS_SECRET_KEY = os.getenv('AWS_SECRET_ACCESS_KEY')
REGION_NAME = os.getenv('AWS_REGION', 'ap-northeast-2')
BUCKET_NAME = os.getenv('S3_BUCKET_NAME', 'ai-vocal-training')
USER_BUCKET_NAME = os.getenv('S3_USER_BUCKET_NAME', 'ai-vocal-training-user')

# S3 경로 설정
S3_LYRICS_PATH = 'lyrics/'
S3_ALBUM_COVER_PATH = 'album_cover/'
S3_MUSIC_FILE_PATH = 'MusicFile/'
S3_INST_PATH = 'inst/'
S3_MIDI_PATH = 'midi/'
S3_ORIGINAL_PATH = 'original/'
S3_VOCAL_PATH = 'vocal/'
S3_EMBEDDINGS_PATH = 'embeddings/' 
=======
 
>>>>>>> 2a42438 (feat: ChatGPT API를 활용한 자연어 피드백 시스템 구현 (보안 강화))
