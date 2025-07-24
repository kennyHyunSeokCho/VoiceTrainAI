from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import pandas as pd
import boto3
import urllib.parse
import os
from src.auth.clerk_auth import ClerkAuth
from src.auth.oauth_handlers import OAuthHandler
from src.DB.database import get_db
from sqlalchemy.orm import Session

app = FastAPI(title="VoiceTrainAI API", version="1.0.0", description="AI 기반 보컬 트레이닝 API")

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*", "http://localhost:3000", "http://127.0.0.1:3000"],  # Flutter 웹 포트 추가
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Clerk 인증 인스턴스 (테스트 모드로 초기화)
try:
    clerk_auth = ClerkAuth()
    print("✅ Clerk 인증이 정상적으로 초기화되었습니다.")
except ValueError as e:
    print(f"⚠️  Clerk 환경변수가 설정되지 않아 테스트 모드로 실행됩니다: {e}")
    clerk_auth = ClerkAuth(skip_config_check=True)

class GoogleTokenRequest(BaseModel):
    id_token: str | None = None
    access_token: str | None = None

class KakaoTokenRequest(BaseModel):
    access_token: str

class VocalRangeAnalysis(BaseModel):
    song_title: str
    artist: str
    total_range: str
    comfortable_range: str
    core_range: str
    difficulty: str
    analysis_status: str

# CSV 파일 경로 설정
SONG_CSV_PATH = "frontend/flutter/assets/all_chart_songs.csv"

class SongDetail(BaseModel):
    title: str
    artist: str
    lyrics: str
    album_cover_url: str
    release_date: str

@app.get("/")
async def root():
    return {"message": "Voice Training AI API"}

@app.post("/auth/google/callback")
async def google_oauth_callback(token_request: GoogleTokenRequest, db: Session = Depends(get_db)):
    """
    Google OAuth 콜백 처리
    Google ID 토큰 또는 Access Token을 받아서 Clerk JWT로 변환하고 사용자 정보를 데이터베이스에 동기화
    """
    try:
        # ID 토큰 또는 Access Token 확인
        if not token_request.id_token and not token_request.access_token:
            raise HTTPException(status_code=400, detail="ID 토큰 또는 Access 토큰이 필요합니다.")
        
        # Access Token이 있으면 Google People API로 사용자 정보 가져오기
        if token_request.access_token:
            import httpx
            print(f"Access Token으로 People API 호출 시작: {token_request.access_token[:20]}...")
            
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    "https://people.googleapis.com/v1/people/me?sources=READ_SOURCE_TYPE_PROFILE&personFields=photos,names,emailAddresses",
                    headers={"Authorization": f"Bearer {token_request.access_token}"}
                )
                
                print(f"People API 응답 상태 코드: {response.status_code}")
                print(f"People API 응답 내용: {response.text}")
                
                if response.status_code == 200:
                    user_data = response.json()
                    
                    # People API 응답에서 사용자 정보 추출
                    names = user_data.get('names', [])
                    email_addresses = user_data.get('emailAddresses', [])
                    photos = user_data.get('photos', [])
                    
                    name = names[0]['displayName'] if names else ''
                    email = email_addresses[0]['value'] if email_addresses else ''
                    picture = photos[0]['url'] if photos else ''
                    resource_name = user_data.get('resourceName', '')
                    user_id = resource_name.replace('people/', '') if resource_name else ''
                    
                    print(f"추출된 사용자 정보: {name}, {email}, {user_id}")
                    
                    google_user_info = {
                        "sub": user_id,
                        "email": email,
                        "name": name,
                        "picture": picture,
                        "google": {
                            "id": user_id,
                            "email": email,
                            "name": name,
                            "picture": picture
                        }
                    }
                else:
                    print(f"People API 요청 실패: {response.status_code} - {response.text}")
                    raise HTTPException(status_code=400, detail=f"Google People API 요청 실패: {response.status_code}")
        else:
            # ID 토큰이 있는 경우 (기존 로직)
            google_user_info = {
                "sub": "google_user_123",
                "email": "test@gmail.com",
                "name": "테스트 구글 사용자",
                "picture": "https://lh3.googleusercontent.com/a/test-photo",
                "google": {
                    "id": "google_user_id_123",
                    "email": "test@gmail.com",
                    "name": "테스트 구글 사용자",
                    "picture": "https://lh3.googleusercontent.com/a/test-photo"
                }
            }
        
        # OAuth 사용자 정보 추출
        user_info = OAuthHandler.extract_google_user_info(google_user_info)
        
        # 데이터베이스에 사용자 동기화
        synced_user = OAuthHandler.sync_oauth_user_to_database(user_info, db)
        
        # Clerk JWT 토큰 생성 (실제로는 Clerk API 사용)
        # 여기서는 테스트용으로 간단한 토큰 반환
        jwt_token = f"test_jwt_token_for_user_{synced_user.id}"
        
        return {
            "success": True,
            "jwt_token": jwt_token,
            "user": {
                "id": synced_user.id,
                "email": synced_user.email,
                "name": synced_user.name,
                "provider": user_info["provider"]
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Google OAuth 처리 실패: {str(e)}")

@app.post("/auth/kakao/callback")
async def kakao_oauth_callback(token_request: KakaoTokenRequest, db: Session = Depends(get_db)):
    """
    카카오 OAuth 콜백 처리
    카카오 Access Token을 받아서 사용자 정보를 가져오고 데이터베이스에 동기화
    """
    try:
        import httpx
        print(f"카카오 Access Token으로 사용자 정보 요청 시작: {token_request.access_token[:20]}...")
        
        async with httpx.AsyncClient() as client:
            # 카카오 사용자 정보 API 호출
            response = await client.get(
                "https://kapi.kakao.com/v2/user/me",
                headers={
                    "Authorization": f"Bearer {token_request.access_token}",
                    "Content-Type": "application/x-www-form-urlencoded;charset=utf-8"
                }
            )
            
            print(f"카카오 API 응답 상태 코드: {response.status_code}")
            print(f"카카오 API 응답 내용: {response.text}")
            
            if response.status_code == 200:
                user_data = response.json()
                
                # 카카오 사용자 정보 추출
                kakao_id = str(user_data.get('id', ''))
                account = user_data.get('kakao_account', {})
                profile = account.get('profile', {})
                
                name = profile.get('nickname', '')
                email = account.get('email', '')
                picture = profile.get('profile_image_url', '')
                is_email_verified = account.get('email_needs_agreement', False) == False
                
                print(f"추출된 카카오 사용자 정보: {name}, {email}, {kakao_id}")
                
                kakao_user_info = {
                    "sub": f"kakao_{kakao_id}",  # Clerk User ID 형식
                    "email": email,
                    "name": name,
                    "picture": picture,
                    "email_verified": is_email_verified,
                    "kakao": {
                        "id": kakao_id,
                        "email": email,
                        "name": name,
                        "picture": picture
                    }
                }
            else:
                print(f"카카오 API 요청 실패: {response.status_code} - {response.text}")
                raise HTTPException(status_code=400, detail=f"카카오 API 요청 실패: {response.status_code}")
        
        # OAuth 사용자 정보 추출
        user_info = OAuthHandler.extract_kakao_user_info(kakao_user_info)
        
        # 데이터베이스에 사용자 동기화
        synced_user = OAuthHandler.sync_oauth_user_to_database(user_info, db)
        
        # Clerk JWT 토큰 생성 (실제로는 Clerk API 사용)
        jwt_token = f"test_jwt_token_for_user_{synced_user.id}"
        
        return {
            "success": True,
            "jwt_token": jwt_token,
            "user": {
                "id": synced_user.id,
                "email": synced_user.email,
                "name": synced_user.name,
                "provider": user_info["provider"]
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"카카오 OAuth 처리 실패: {str(e)}")

@app.get("/auth/me")
async def get_current_user_info():
    """현재 로그인된 사용자 정보 조회 (테스트용)"""
    # 테스트 모드에서는 더미 사용자 정보 반환
    return {
        "user": {
            "id": "test_user_123",
            "email": "test@example.com",
            "name": "테스트 사용자",
            "provider": "email"
        }
    }

@app.get("/api/song/{title}/{artist}", response_model=SongDetail)
def get_song_detail(title: str, artist: str):
    """
    노래의 상세 정보를 반환합니다.
    """
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

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
