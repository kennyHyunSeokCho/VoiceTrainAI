from fastapi import APIRouter, BackgroundTasks, Depends, Request, HTTPException
from sqlalchemy.orm import Session
from typing import Dict, Any, Optional
import uuid
from datetime import datetime
from ..DB.database import get_db
import requests
import os
from dotenv import load_dotenv
import boto3
from ..config import AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, S3_BUCKET_NAME
# runpod_client import 제거 (Serverless Endpoint 사용 안함)
from .pod_direct_client import PodDirectClient
import urllib.parse
import re

# 환경변수 로드
load_dotenv()

router = APIRouter(prefix="/ai-synthesis", tags=["AI Voice Synthesis"])

def generate_s3_paths(title: str, artist: str) -> tuple[str, str]:
    """제목과 아티스트로 S3 경로들을 생성 (artist 폴더 포함)"""
    safe_title = title.replace(" ", "_").replace("'", "").replace('"', "")
    safe_artist = artist.replace(" ", "_").replace("'", "").replace('"', "")
    # artist 폴더가 중간에 들어가도록 경로 수정
    vocal_path = f"MusicFile/{safe_artist}/vocal/{safe_artist}_{safe_title}_vocal.wav"
    mr_path = f"MusicFile/{safe_artist}/inst/{safe_artist}_{safe_title}_inst.wav"
    return vocal_path, mr_path

def verify_s3_file_exists(s3_path: str) -> bool:
    """S3 파일 존재 여부 확인"""
    try:
        s3_client = boto3.client(
            's3',
            aws_access_key_id=AWS_ACCESS_KEY_ID,
            aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
            region_name=AWS_REGION
        )
        s3_client.head_object(Bucket=S3_BUCKET_NAME, Key=s3_path)
        return True
    except Exception as e:
        print(f"S3 파일 확인 실패 {s3_path}: {e}")
        return False

@router.post("/synthesis/start")
async def start_synthesis(request: Request, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    """
    프론트엔드에서 합성 요청을 받으면 Pod에 직접 요청하거나 Serverless Endpoint를 통해 요청
    """
    data = await request.json()
    job_id = str(uuid.uuid4())
    
    # 프론트엔드에서 받은 데이터 로그 출력
    print(f"프론트엔드에서 받은 데이터: {data}")
    
    # 필수 필드 검증
    required_fields = ["user_id", "song_name", "singer_name", "user_vocal_url"]
    for field in required_fields:
        if not data.get(field):
            raise HTTPException(status_code=400, detail=f"필수 필드가 누락되었습니다: {field}")
    
    # Pod 직접 연결 사용 (Serverless Endpoint 제거)
    background_tasks.add_task(request_pod_direct, job_id, data)
    
    return {"job_id": job_id}

def request_pod_direct(job_id, data):
    """
    Pod에 직접 합성 요청
    """
    try:
        # 프론트엔드에서 받은 S3 경로 사용
        user_vocal_s3 = data.get("user_vocal_url")
        vocal_s3 = data.get("vocal_file_url")  # 프론트엔드에서 받은 보컬 파일 URL
        inst_s3 = data.get("mr_file_url")      # 프론트엔드에서 받은 MR 파일 URL
        
        # 사용자 보컬 경로에서 버킷 접두사 제거 (Pod에서 처리)
        if user_vocal_s3 and user_vocal_s3.startswith('ai-vocal-training-user/'):
            user_vocal_s3 = user_vocal_s3.replace('ai-vocal-training-user/', '')
        
        # S3 파일 존재 여부 확인
        if not verify_s3_file_exists(vocal_s3):
            print(f"경고: 보컬 파일이 S3에 존재하지 않습니다: {vocal_s3}")
        if not verify_s3_file_exists(inst_s3):
            print(f"경고: MR 파일이 S3에 존재하지 않습니다: {inst_s3}")
        
        # Pod 직접 클라이언트 사용
        pod_url = os.getenv("POD_DIRECT_URL")
        if not pod_url:
            print("경고: POD_DIRECT_URL이 설정되지 않았습니다!")
            return
        
        client = PodDirectClient(pod_url)
        
        # Pod에 직접 요청
        result = client.start_synthesis(
            user_id=data.get("user_id"),
            artist=data["singer_name"],
            title=data["song_name"],
            user_vocal_s3=user_vocal_s3,
            vocal_s3=vocal_s3,
            inst_s3=inst_s3
        )
        
        print(f"Pod 직접 요청 성공: {result}")
        
    except Exception as e:
        print(f"Pod 직접 요청 중 오류 발생: {e}")

# request_gpu_server 함수 제거 (Serverless Endpoint 사용 안함)

@router.get("/synthesis/status/{job_id}")
async def get_synthesis_status(job_id: str, db: Session = Depends(get_db)):
    """
    job_id로 현재 합성 상태/결과를 반환 (Pod 직접 연결만 사용)
    """
    try:
        # URL 디코딩 및 ANSI 색상 코드 제거
        decoded_job_id = urllib.parse.unquote(job_id)
        # ANSI 색상 코드 제거 (예: [32m, [0m 등)
        clean_job_id = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', decoded_job_id).strip()
        
        print(f"원본 job_id: {job_id}")
        print(f"디코딩된 job_id: {decoded_job_id}")
        print(f"정리된 job_id: {clean_job_id}")
        
        pod_url = os.getenv("POD_DIRECT_URL")
        if not pod_url:
            return {
                "status": "error",
                "message": "POD_DIRECT_URL이 설정되지 않았습니다."
            }
        
        client = PodDirectClient(pod_url)
        status = client.get_synthesis_status(clean_job_id)
        return status
    except Exception as e:
        print(f"상태 확인 중 오류 발생: {e}")
        return {
            "status": "error",
            "message": f"상태 확인 실패: {str(e)}"
        }

@router.post("/synthesis/cancel/{job_id}")
async def cancel_synthesis(job_id: str, db: Session = Depends(get_db)):
    """
    합성 작업 취소 (Pod 직접 연결만 사용)
    """
    try:
        # URL 디코딩 및 ANSI 색상 코드 제거
        decoded_job_id = urllib.parse.unquote(job_id)
        # ANSI 색상 코드 제거 (예: [32m, [0m 등)
        clean_job_id = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', decoded_job_id).strip()
        
        print(f"취소 요청 - 원본 job_id: {job_id}")
        print(f"취소 요청 - 정리된 job_id: {clean_job_id}")
        
        pod_url = os.getenv("POD_DIRECT_URL")
        if not pod_url:
            raise HTTPException(status_code=400, detail="POD_DIRECT_URL이 설정되지 않았습니다.")
        
        client = PodDirectClient(pod_url)
        success = client.cancel_synthesis(clean_job_id)
        if success:
            return {"message": "합성 작업이 취소되었습니다."}
        else:
            raise HTTPException(status_code=400, detail="합성 작업 취소에 실패했습니다.")
    except Exception as e:
        print(f"작업 취소 중 오류 발생: {e}")
        raise HTTPException(status_code=500, detail=f"작업 취소 중 오류가 발생했습니다: {str(e)}")

@router.get("/synthesis/pod-health")
async def check_pod_health():
    """
    Pod 직접 연결 상태 확인
    """
    try:
        pod_url = os.getenv("POD_DIRECT_URL")
        if not pod_url:
            return {"status": "not_configured", "message": "POD_DIRECT_URL이 설정되지 않았습니다."}
        
        client = PodDirectClient(pod_url)
        health = client.health_check()
        return health
    except Exception as e:
        return {"status": "error", "message": f"Pod 연결 실패: {str(e)}"} 
