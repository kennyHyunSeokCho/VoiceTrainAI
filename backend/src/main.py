from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import asyncio
from contextlib import asynccontextmanager
from src.auth.clerk_auth import ClerkAuth
from src.auth.oauth_handlers import OAuthHandler
from src.DB.database import get_db
from sqlalchemy.orm import Session
# from src.vocal.rvc_training_api import router as rvc_router  # 임시로 비활성화
from src.vocal.ai_synthesis_api import router as ai_synthesis_router
from src.api.recommend import router as recommend_router
from src.services.s3_monitor import s3_monitor
from src.services.wav_processor import wav_processor

# 백그라운드 태스크 관리
@asynccontextmanager
async def lifespan(app: FastAPI):
    # 앱 시작 시 백그라운드 서비스들 시작
    print("🚀 백그라운드 서비스 시작...")
    
    # S3 모니터링 시작 (추천 시스템)
    print("📊 S3 모니터링 서비스 시작...")
    asyncio.create_task(s3_monitor.start_monitoring(check_interval=60))  # 60초마다 체크
    
    # wav 파일 처리 서비스 시작 (임베딩 추출)
    print("🎵 wav 파일 처리 서비스 시작...")
    asyncio.create_task(wav_processor.start_monitoring(check_interval=30))  # 30초마다 체크
    
    yield
    
    # 앱 종료 시 모든 백그라운드 서비스 중지
    print("🛑 백그라운드 서비스 중지...")
    s3_monitor.stop_monitoring()
    wav_processor.stop_monitoring()

app = FastAPI(
    title="Voice Training AI API", 
    version="1.0.0",
    lifespan=lifespan
)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 개발 환경에서는 모든 origin 허용
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 라우터 등록
# app.include_router(rvc_router)  # 임시로 비활성화 (RVCTrainingJob 모델 문제)
app.include_router(ai_synthesis_router)
app.include_router(recommend_router)

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
                    
                    # 사용자 정보 구성
                    user_info = {
                        "email": email_addresses[0]['value'] if email_addresses else None,
                        "name": names[0]['displayName'] if names else None,
                        "picture": photos[0]['url'] if photos else None,
                        "provider": "google"
                    }
                    
                    # OAuth 핸들러로 처리
                    oauth_handler = OAuthHandler()
                    result = await oauth_handler.handle_google_oauth(user_info, db)
                    
                    return result
                else:
                    raise HTTPException(status_code=400, detail=f"Google People API 오류: {response.status_code}")
        
        # ID 토큰이 있으면 Google ID 토큰 검증
        elif token_request.id_token:
            # Google ID 토큰 검증 및 사용자 정보 추출
            oauth_handler = OAuthHandler()
            result = await oauth_handler.handle_google_id_token(token_request.id_token, db)
            return result
            
    except Exception as e:
        print(f"Google OAuth 콜백 처리 오류: {e}")
        raise HTTPException(status_code=500, detail=f"OAuth 처리 중 오류가 발생했습니다: {str(e)}")

@app.post("/auth/kakao/callback")
async def kakao_oauth_callback(token_request: KakaoTokenRequest, db: Session = Depends(get_db)):
    """
    Kakao OAuth 콜백 처리
    Kakao Access Token을 받아서 Clerk JWT로 변환하고 사용자 정보를 데이터베이스에 동기화
    """
    try:
        print(f"Kakao Access Token으로 사용자 정보 가져오기 시작: {token_request.access_token[:20]}...")
        
        # Kakao 사용자 정보 API 호출
        import httpx
        async with httpx.AsyncClient() as client:
            response = await client.get(
                "https://kapi.kakao.com/v2/user/me",
                headers={"Authorization": f"Bearer {token_request.access_token}"}
            )
            
            print(f"Kakao API 응답 상태 코드: {response.status_code}")
            print(f"Kakao API 응답 내용: {response.text}")
            
            if response.status_code == 200:
                user_data = response.json()
                
                # Kakao 사용자 정보 추출
                kakao_account = user_data.get('kakao_account', {})
                profile = kakao_account.get('profile', {})
                
                user_info = {
                    "email": kakao_account.get('email'),
                    "name": profile.get('nickname'),
                    "picture": profile.get('profile_image_url'),
                    "provider": "kakao",
                    "kakao_id": str(user_data.get('id'))
                }
                
                # OAuth 핸들러로 처리
                oauth_handler = OAuthHandler()
                result = await oauth_handler.handle_kakao_oauth(user_info, db)
                
                return result
            else:
                raise HTTPException(status_code=400, detail=f"Kakao API 오류: {response.status_code}")
                
    except Exception as e:
        print(f"Kakao OAuth 콜백 처리 오류: {e}")
        raise HTTPException(status_code=500, detail=f"OAuth 처리 중 오류가 발생했습니다: {str(e)}")

@app.get("/auth/me")
async def get_current_user_info():
    """
    현재 인증된 사용자 정보 조회 (테스트용)
    """
    return {
        "message": "현재 인증된 사용자 정보",
        "note": "실제 구현에서는 JWT 토큰에서 사용자 정보를 추출합니다."
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000) 
    
    