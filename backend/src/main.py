from fastapi import FastAPI, HTTPException, Depends, WebSocket, WebSocketDisconnect, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn
import boto3
import os
import urllib.parse
from botocore.exceptions import ClientError
import json
from typing import List, Optional
import librosa
import numpy as np
from pydub import AudioSegment
import io
import tempfile
from datetime import datetime, timedelta
from collections import defaultdict
import asyncio
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

# WebSocket 연결 관리
class ConnectionManager:
    def __init__(self):
        self.active_connections: dict = defaultdict(list)  # user_id -> [WebSocket]
        self.file_monitors: dict = {}  # user_id -> asyncio.Task

    async def connect(self, websocket: WebSocket, user_id: str):
        await websocket.accept()
        self.active_connections[user_id].append(websocket)
        print(f"🔗 WebSocket 연결: 사용자 {user_id} (총 {len(self.active_connections[user_id])}개 연결)")

    def disconnect(self, websocket: WebSocket, user_id: str):
        if user_id in self.active_connections:
            self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]
                # 파일 모니터링 중지
                if user_id in self.file_monitors:
                    self.file_monitors[user_id].cancel()
                    del self.file_monitors[user_id]
        print(f"🔌 WebSocket 연결 해제: 사용자 {user_id}")

    async def send_personal_message(self, message: str, user_id: str):
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                try:
                    await connection.send_text(message)
                except:
                    # 연결이 끊어진 경우 제거
                    self.active_connections[user_id].remove(connection)
            print(f"📤 메시지 전송: 사용자 {user_id}에게 {message}")

    async def broadcast_file_update(self, user_id: str, file_info: dict):
        """파일 업데이트 알림을 특정 사용자에게 전송"""
        message = json.dumps({
            "type": "file_update",
            "data": file_info
        })
        await self.send_personal_message(message, user_id)

manager = ConnectionManager()

# 파일 변경 감지 함수
async def monitor_user_files(user_id: str):
    """사용자의 S3 파일 변경을 모니터링"""
    s3_client = boto3.client(
        's3',
        aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
        aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'),
        region_name=os.getenv('AWS_REGION', 'ap-northeast-2')
    )
    
    last_files = set()
    
    while True:
        try:
            # 사용자의 vocal 폴더에서 파일 목록 조회
            prefix = f"{user_id}/vocal/"
            response = s3_client.list_objects_v2(
                Bucket=os.getenv('S3_BUCKET_NAME'),
                Prefix=prefix
            )
            
            current_files = set()
            if 'Contents' in response:
                for obj in response['Contents']:
                    key = obj['Key']
                    if key.startswith(prefix) and key != prefix:
                        current_files.add(key)
            
            # 새로운 파일이 있는지 확인
            new_files = current_files - last_files
            if new_files:
                print(f"🆕 새로운 파일 감지: 사용자 {user_id}, 파일: {new_files}")
                
                # 각 새 파일에 대해 알림 전송
                for file_key in new_files:
                    filename = file_key.split('/')[-1]
                    if filename.endswith('_record.wav') or filename.endswith('_record.mp3'):
                        # 파일 정보 파싱
                        base_name = filename.replace("_record.wav", "").replace("_record.mp3", "")
                        
                        artist = "Unknown Artist"
                        title = base_name
                        
                        if base_name.startswith(f"{user_id}_"):
                            title = base_name.replace(f"{user_id}_", "").replace("_", " ")
                        else:
                            if "_" in base_name:
                                parts = base_name.split("_", 1)
                                if len(parts) == 2:
                                    artist = parts[0].replace("_", " ")
                                    title = parts[1].replace("_", " ")
                        
                        file_info = {
                            'key': file_key,
                            'filename': filename,
                            'song_title': title,
                            'artist': artist,
                            'type': 'realtime_recording' if not base_name.startswith(f'{user_id}_') else 'user_upload',
                            'timestamp': datetime.now().isoformat()
                        }
                        
                        await manager.broadcast_file_update(user_id, file_info)
            
            last_files = current_files
            
        except Exception as e:
            print(f"❌ 파일 모니터링 오류 (사용자 {user_id}): {e}")
        
        # 10초마다 체크
        await asyncio.sleep(10)

# WebSocket 엔드포인트
@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    await manager.connect(websocket, user_id)
    
    # 파일 모니터링 시작
    if user_id not in manager.file_monitors:
        manager.file_monitors[user_id] = asyncio.create_task(monitor_user_files(user_id))
    
    try:
        while True:
            # 클라이언트로부터 메시지 수신 (필요시)
            data = await websocket.receive_text()
            print(f"📨 WebSocket 메시지 수신: {data}")
            
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)

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

@app.get("/api/user-uploads/{user_id}")
async def get_user_uploads(user_id: str):
    """사용자가 업로드한 파일 목록 조회"""
    try:
        # config.py에서 AWS 설정 가져오기
        from src.config import AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, S3_BUCKET_NAME
        
        # S3 클라이언트 생성
        s3_client = boto3.client(
            's3',
            aws_access_key_id=AWS_ACCESS_KEY_ID,
            aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
            region_name=AWS_REGION
        )
        
        # 사용자의 vocal 폴더에서 파일 목록 조회
        prefix = f"{user_id}/vocal/"
        response = s3_client.list_objects_v2(
            Bucket=S3_BUCKET_NAME,
            Prefix=prefix
        )
        
        uploads = []
        if 'Contents' in response:
            for obj in response['Contents']:
                key = obj['Key']
                # vocal 폴더의 파일만 필터링
                if key.startswith(prefix) and key != prefix:
                    # 파일명에서 노래 정보 추출
                    filename = key.split('/')[-1]  # 예: "사용자ID_노래제목_record.wav" 또는 "가수명_노래제목_record.wav"
                    if filename.endswith('_record.wav') or filename.endswith('_record.mp3'):
                        # 파일명에서 _record.확장자 부분 제거
                        base_name = filename.replace("_record.wav", "").replace("_record.mp3", "")
                        
                        # 파일명 패턴 분석
                        # 1. 사용자 업로드 파일: "사용자ID_노래제목" -> "노래제목"
                        # 2. 실시간 녹음 파일: "가수명_노래제목" -> "가수명", "노래제목"
                        
                        artist = "Unknown Artist"
                        title = base_name
                        
                        # 사용자 ID로 시작하는지 확인 (사용자 업로드 파일)
                        if base_name.startswith(f"{user_id}_"):
                            # 사용자 업로드 파일: "사용자ID_노래제목" -> "노래제목"
                            title = base_name.replace(f"{user_id}_", "")
                            title = title.replace("_", " ")
                            artist = "Unknown Artist"
                        else:
                            # 실시간 녹음 파일: "가수명_노래제목" -> "가수명", "노래제목"
                            if "_" in base_name:
                                parts = base_name.split("_", 1)  # 첫 번째 언더스코어만 분리
                                if len(parts) == 2:
                                    artist = parts[0].replace("_", " ")
                                    title = parts[1].replace("_", " ")
                        
                        # 디버그 로그 추가
                        print(f"🔍 파일명 파싱: {filename}")
                        print(f"  - 파일 타입: {'실시간 녹음' if not base_name.startswith(f'{user_id}_') else '사용자 업로드'}")
                        print(f"  - 추출된 아티스트: {artist}")
                        print(f"  - 추출된 제목: {title}")
                        
                        uploads.append({
                            'key': key,
                            'filename': filename,
                            'song_title': title,
                            'artist': artist,
                            'size': obj['Size'],
                            'last_modified': obj['LastModified'].isoformat(),
                            'url': f"https://{S3_BUCKET_NAME}.s3.{AWS_REGION}.amazonaws.com/{key}",
                            'type': 'realtime_recording' if not base_name.startswith(f'{user_id}_') else 'user_upload'
                        })
        
        # 최신 파일 순으로 정렬
        uploads.sort(key=lambda x: x['last_modified'], reverse=True)
        
        print(f"📋 사용자 {user_id}의 업로드 파일 목록:")
        for upload in uploads:
            print(f"  - {upload['type']}: {upload['artist']} - {upload['song_title']}")
        
        return {
            "success": True,
            "uploads": uploads,
            "user_id": user_id
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"사용자 업로드 파일 조회 실패: {str(e)}")

@app.get("/api/s3/presigned-url")
async def get_s3_presigned_url(bucket: str, key: str):
    """S3 파일 다운로드를 위한 presigned URL 생성"""
    try:
        # config.py에서 AWS 설정 가져오기
        from src.config import AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
        
        # S3 클라이언트 생성
        s3_client = boto3.client(
            's3',
            aws_access_key_id=AWS_ACCESS_KEY_ID,
            aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
            region_name=AWS_REGION
        )
        
        # GET용 presigned URL 생성 (다운로드용)
        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={
                'Bucket': bucket,
                'Key': key
            },
            ExpiresIn=3600  # 1시간 유효
        )
        
        return {
            "success": True,
            "presigned_url": presigned_url,
            "bucket": bucket,
            "key": key
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Presigned URL 생성 실패: {str(e)}")

@app.get("/api/album-cover/{artist}/{title}")
async def get_album_cover_url(artist: str, title: str):
    """앨범 커버 이미지 URL 조회"""
    try:
        # URL 디코딩
        decoded_artist = urllib.parse.unquote(artist)
        decoded_title = urllib.parse.unquote(title)
        
        # 파일명에서 특수문자 제거 및 공백 처리
        def clean_filename(filename):
            import re
            # 특수문자 제거 (한글, 영문, 숫자, 공백만 허용)
            cleaned = re.sub(r'[^\w\s가-힣]', '', filename)
            # 공백을 언더스코어로 변경
            cleaned = re.sub(r'\s+', '_', cleaned)
            return cleaned.strip()
        
        clean_artist = clean_filename(decoded_artist)
        clean_title = clean_filename(decoded_title)
        
        # S3 앨범 커버 URL 생성
        from src.config import AWS_REGION
        album_cover_url = f"https://ai-vocal-training.s3.{AWS_REGION}.amazonaws.com/album_cover/{clean_artist}_{clean_title}.jpg"
        
        return {
            "success": True,
            "album_cover_url": album_cover_url,
            "artist": decoded_artist,
            "title": decoded_title
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"앨범 커버 URL 생성 실패: {str(e)}")

@app.get("/api/album-cover-by-title/{title}")
async def get_album_cover_by_title(title: str):
    """노래 제목만으로 앨범 커버 이미지 URL 조회"""
    try:
        # URL 디코딩
        decoded_title = urllib.parse.unquote(title)
        
        # config.py에서 AWS 설정 가져오기
        from src.config import AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
        
        # S3 클라이언트 생성
        s3_client = boto3.client(
            's3',
            aws_access_key_id=AWS_ACCESS_KEY_ID,
            aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
            region_name=AWS_REGION
        )
        
        # S3에서 album_cover 폴더의 파일 목록 조회
        bucket_name = 'ai-vocal-training'
        response = s3_client.list_objects_v2(
            Bucket=bucket_name,
            Prefix='album_cover/'
        )
        
        # 노래 제목이 포함된 파일 찾기
        matching_files = []
        if 'Contents' in response:
            for obj in response['Contents']:
                key = obj['Key']
                if key.endswith('.jpg') and decoded_title in key:
                    matching_files.append({
                        'key': key,
                        'url': f"https://{bucket_name}.s3.{AWS_REGION}.amazonaws.com/{key}"
                    })
        
        # 가장 적합한 파일 선택 (제목이 정확히 일치하는 것 우선)
        album_cover_url = None
        if matching_files:
            # 정확히 일치하는 파일 찾기
            exact_matches = [f for f in matching_files if f'_{decoded_title}.jpg' in f['key']]
            if exact_matches:
                album_cover_url = exact_matches[0]['url']
            else:
                # 부분 일치하는 파일 중 첫 번째 사용
                album_cover_url = matching_files[0]['url']
        
        print(f"🔍 앨범 커버 검색: '{decoded_title}'")
        print(f"  - 찾은 파일들: {[f['key'] for f in matching_files]}")
        print(f"  - 선택된 URL: {album_cover_url}")
        
        if album_cover_url:
            return {
                "success": True,
                "album_cover_url": album_cover_url,
                "title": decoded_title
            }
        else:
            return {
                "success": False,
                "message": f"'{decoded_title}' 제목의 앨범 커버를 찾을 수 없습니다."
            }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"앨범 커버 URL 생성 실패: {str(e)}")

@app.get("/api/audio-presigned-url/{user_id}/{filename}")
async def get_audio_presigned_url(user_id: str, filename: str):
    """오디오 파일 재생을 위한 presigned URL 생성"""
    try:
        # config.py에서 AWS 설정 가져오기
        from src.config import AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, S3_BUCKET_NAME
        
        # URL 디코딩
        decoded_user_id = urllib.parse.unquote(user_id)
        decoded_filename = urllib.parse.unquote(filename)
        
        # S3 클라이언트 생성
        s3_client = boto3.client(
            's3',
            aws_access_key_id=AWS_ACCESS_KEY_ID,
            aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
            region_name=AWS_REGION
        )
        
        # S3 키 생성
        s3_key = f"{decoded_user_id}/vocal/{decoded_filename}"
        
        # GET용 presigned URL 생성 (재생용)
        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={
                'Bucket': S3_BUCKET_NAME,
                'Key': s3_key
            },
            ExpiresIn=3600  # 1시간 유효
        )
        
        print(f"🎵 오디오 presigned URL 생성: {s3_key}")
        print(f"  - 디코딩된 사용자 ID: {decoded_user_id}")
        print(f"  - 디코딩된 파일명: {decoded_filename}")
        print(f"  - S3 키: {s3_key}")
        print(f"  - Presigned URL: {presigned_url}")
        
        return {
            "success": True,
            "presigned_url": presigned_url,
            "s3_key": s3_key
        }
        
    except Exception as e:
        print(f"❌ 오디오 presigned URL 생성 실패: {e}")
        raise HTTPException(status_code=500, detail=f"오디오 presigned URL 생성 실패: {str(e)}")

@app.get("/api/vocal-range/{artist}/{title}")
async def analyze_vocal_range(artist: str, title: str):
    """
    원곡의 음역대를 분석하여 반환합니다.
    """
    try:
        print(f"🎵 음역대 분석 요청: {artist} - {title}")
        
        # 임시로 더미 데이터 반환 (실제 분석 구현 전)
        return {
            "success": True,
            "vocal_range": {
                "lowest_note": "C3",
                "highest_note": "G5",
                "range_span": "C3 - G5",
                "top_notes": ["C4", "D4", "E4", "F4", "G4"],
                "note_frequencies": {"C4": 150, "D4": 120, "E4": 100, "F4": 80, "G4": 60}
            }
        }
        
    except Exception as e:
        print(f"❌ 음역대 분석 오류: {e}")
        # 임시로 더미 데이터 반환 (실제 분석이 실패할 경우)
        return {
            "success": True,
            "vocal_range": {
                "lowest_note": "C3",
                "highest_note": "G5",
                "range_span": "C3 - G5",
                "top_notes": ["C4", "D4", "E4", "F4", "G4"],
                "note_frequencies": {"C4": 150, "D4": 120, "E4": 100, "F4": 80, "G4": 60}
            }
        }

@app.get("/api/ai-vocal-presigned-url/{artist}/{title}")
async def get_ai_vocal_presigned_url(artist: str, title: str):
    """
    AI 보컬 파일의 presigned URL을 생성합니다.
    """
    try:
        from src.config import AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, S3_BUCKET_NAME
        
        # AI 보컬 파일 경로 (ai-vocal-training-user 버킷 사용)
        ai_vocal_key = f"MusicFile/{artist}/vocal/{artist}_{title}_vocal.wav"
        bucket_name = S3_BUCKET_NAME  # user 버킷 사용
        
        s3_client = boto3.client(
            's3',
            aws_access_key_id=AWS_ACCESS_KEY_ID,
            aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
            region_name=AWS_REGION
        )
        
        try:
            # S3에서 파일 존재 여부 확인
            s3_client.head_object(Bucket=bucket_name, Key=ai_vocal_key)
            
            # Presigned URL 생성
            presigned_url = s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': bucket_name, 'Key': ai_vocal_key},
                ExpiresIn=3600
            )
            
            return {
                "success": True,
                "presigned_url": presigned_url,
                "s3_key": ai_vocal_key
            }
            
        except ClientError as e:
            if e.response['Error']['Code'] == 'NoSuchKey':
                raise HTTPException(status_code=404, detail=f"AI 보컬 파일을 찾을 수 없습니다: {ai_vocal_key}")
            else:
                raise HTTPException(status_code=500, detail=f"S3 오류: {str(e)}")
                
    except Exception as e:
        print(f"AI 보컬 presigned URL 생성 오류: {e}")
        # 임시로 더미 데이터 반환 (실제 S3 접근이 실패할 경우)
        return {
            "success": True,
            "presigned_url": "https://example.com/dummy-ai-vocal.wav",
            "s3_key": f"MusicFile/{artist}/vocal/{artist}_{title}_vocal.wav"
        }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
