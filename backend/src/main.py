from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import boto3
import os
from src.auth.clerk_auth import ClerkAuth
from src.auth.oauth_handlers import OAuthHandler
from src.DB.database import get_db
from sqlalchemy.orm import Session

app = FastAPI(title="Voice Training AI API", version="1.0.0")

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 개발 환경에서는 모든 origin 허용
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

class PresignedUrlRequest(BaseModel):
    bucket: str
    s3_key: str
    content_type: str

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
            
            # 더미 토큰인지 확인 (테스트용)
            if token_request.access_token.startswith('valid_google_token_test') or token_request.access_token == 'test':
                print("⚠️  더미 토큰 감지됨. 테스트용 더미 데이터를 반환합니다.")
                google_user_info = {
                    "sub": "test_google_user_123",
                    "email": "test.google@example.com",
                    "name": "테스트 구글 사용자",
                    "picture": "https://lh3.googleusercontent.com/a/test-photo",
                    "google": {
                        "id": "test_google_user_123",
                        "email": "test.google@example.com",
                        "name": "테스트 구글 사용자",
                        "picture": "https://lh3.googleusercontent.com/a/test-photo"
                    }
                }
            else:
                # 실제 토큰으로 Google People API 호출
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

@app.get("/api/vocal-range/{title}/{artist}")
async def get_vocal_range(title: str, artist: str):
    """노래별 보컬 범위 정보 조회 (임시 더미 데이터)"""
    # URL 디코딩
    import urllib.parse
    decoded_title = urllib.parse.unquote(title)
    decoded_artist = urllib.parse.unquote(artist)
    
    # 임시 더미 데이터 반환
    return {
        "success": True,
        "song": {
            "title": decoded_title,
            "artist": decoded_artist,
            "vocal_range": {
                "min_note": "C3",
                "max_note": "G5",
                "key": "C Major",
                "bpm": 120,
                "difficulty": "Medium"
            }
        }
    }

@app.post("/upload/presigned-url")
async def get_presigned_url(request: PresignedUrlRequest):
    """S3 업로드를 위한 presigned URL 생성"""
    try:
        # S3 클라이언트 생성
        s3_client = boto3.client(
            's3',
            aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
            aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'),
            region_name=os.getenv('AWS_REGION', 'ap-northeast-2')
        )
        
        # PUT용 presigned URL 생성 (업로드용)
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': request.bucket,
                'Key': request.s3_key,
                'ContentType': request.content_type
            },
            ExpiresIn=3600  # 1시간 유효
        )
        
        return {
            "success": True,
            "presigned_url": presigned_url,
            "bucket": request.bucket,
            "s3_key": request.s3_key
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Presigned URL 생성 실패: {str(e)}")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
