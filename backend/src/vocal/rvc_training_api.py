from fastapi import APIRouter, HTTPException, Depends, UploadFile, File
from sqlalchemy.orm import Session
from typing import Dict, Any
import boto3
import os
from datetime import datetime

from ..DB.database import get_db
from ..DB.models import UserProfile, RVCTrainingJob
from .runpod_client import runpod_client
from .s3_utils import upload_file_to_s3

router = APIRouter(prefix="/rvc", tags=["RVC Training"])

@router.post("/start-training")
async def start_rvc_training(
    audio_file: UploadFile = File(...),
    model_name: str = None,
    user_id: str = None,
    db: Session = Depends(get_db)
):
    """
    RVC 학습 시작
    
    Args:
        audio_file: 학습할 오디오 파일 (WAV, MP3)
        model_name: 생성될 모델 이름
        user_id: 사용자 ID
        
    Returns:
        학습 작업 정보
    """
    try:
        # 파일 검증
        if not audio_file.filename.lower().endswith(('.wav', '.mp3')):
            raise HTTPException(status_code=400, detail="WAV 또는 MP3 파일만 지원됩니다.")
        
        # S3에 오디오 파일 업로드
        file_key = f"training_audio/{user_id}/{datetime.now().strftime('%Y%m%d_%H%M%S')}_{audio_file.filename}"
        audio_url = await upload_file_to_s3(audio_file, file_key)
        
        # RunPod에서 학습 시작
        training_response = runpod_client.start_rvc_training(
            audio_file_url=audio_url,
            model_name=model_name or f"user_{user_id}_model",
            user_id=user_id
        )
        
        # 데이터베이스에 학습 작업 기록
        training_job = RVCTrainingJob(
            user_id=user_id,
            job_id=training_response["id"],
            model_name=model_name,
            audio_file_url=audio_url,
            status="RUNNING",
            created_at=datetime.now()
        )
        
        db.add(training_job)
        db.commit()
        db.refresh(training_job)
        
        return {
            "success": True,
            "job_id": training_response["id"],
            "message": "RVC 학습이 시작되었습니다.",
            "estimated_time": "약 30-60분 소요 예상"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"학습 시작 실패: {str(e)}")

@router.get("/training-status/{job_id}")
async def get_training_status(
    job_id: str,
    user_id: str = None,
    db: Session = Depends(get_db)
):
    """학습 상태 확인"""
    try:
        # RunPod에서 상태 확인
        status_response = runpod_client.get_training_status(job_id)
        
        # 데이터베이스 업데이트
        training_job = db.query(RVCTrainingJob).filter(
            RVCTrainingJob.job_id == job_id,
            RVCTrainingJob.user_id == user_id
        ).first()
        
        if training_job:
            training_job.status = status_response.get("status", "UNKNOWN")
            if status_response.get("status") == "COMPLETED":
                training_job.completed_at = datetime.now()
                training_job.model_url = status_response.get("output", {}).get("model_url")
            db.commit()
        
        return {
            "job_id": job_id,
            "status": status_response.get("status"),
            "progress": status_response.get("output", {}).get("progress", 0),
            "message": status_response.get("output", {}).get("message", ""),
            "model_url": status_response.get("output", {}).get("model_url")
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"상태 확인 실패: {str(e)}")

@router.post("/cancel-training/{job_id}")
async def cancel_training(
    job_id: str,
    user_id: str = None,
    db: Session = Depends(get_db)
):
    """학습 작업 취소"""
    try:
        # RunPod에서 작업 취소
        success = runpod_client.cancel_training(job_id)
        
        if success:
            # 데이터베이스 업데이트
            training_job = db.query(RVCTrainingJob).filter(
                RVCTrainingJob.job_id == job_id,
                RVCTrainingJob.user_id == user_id
            ).first()
            
            if training_job:
                training_job.status = "CANCELLED"
                training_job.completed_at = datetime.now()
                db.commit()
        
        return {
            "success": success,
            "message": "학습이 취소되었습니다." if success else "취소 실패"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"취소 실패: {str(e)}")

@router.get("/user-models/{user_id}")
async def get_user_models(
    user_id: str,
    db: Session = Depends(get_db)
):
    """사용자의 학습된 모델 목록"""
    try:
        models = db.query(RVCTrainingJob).filter(
            RVCTrainingJob.user_id == user_id,
            RVCTrainingJob.status == "COMPLETED"
        ).all()
        
        return {
            "models": [
                {
                    "id": model.id,
                    "model_name": model.model_name,
                    "created_at": model.created_at,
                    "completed_at": model.completed_at,
                    "model_url": model.model_url
                }
                for model in models
            ]
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"모델 목록 조회 실패: {str(e)}") 