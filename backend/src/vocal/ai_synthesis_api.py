from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from typing import Dict, Any, Optional
import os
import json
from datetime import datetime
from pydantic import BaseModel

from ..DB.database import get_db
from ..DB.models import UserProfile, AiCover
# from .runpod_client import runpod_client  # 더 이상 사용하지 않음 (직접 연결 방식 사용)
from .cloud_gpu_client import init_cloud_gpu_client
from .s3_utils import get_s3_client_from_env, list_s3_files
from ..config import CLOUD_GPU_API_URL

router = APIRouter(prefix="/ai-synthesis", tags=["AI Voice Synthesis"])

class AISynthesisRequest(BaseModel):
    """AI 음성 합성 요청 모델"""
    user_id: str
    singer_name: str  # 가수명
    song_name: str    # 곡명
    model_name: Optional[str] = None  # 사용할 RVC 모델명 (선택사항)

class AISynthesisResponse(BaseModel):
    """AI 음성 합성 응답 모델"""
    success: bool
    job_id: str
    message: str
    estimated_time: str

@router.post("/start-synthesis", response_model=AISynthesisResponse)
async def start_ai_synthesis(
    request: AISynthesisRequest,
    db: Session = Depends(get_db)
):
    """
    AI 음성 합성 시작 (테스트용 - 단순 요청 처리)
    
    Args:
        request: AI 합성 요청 정보 (user_id, 가수명, 곡명)
        
    Returns:
        합성 작업 정보
    """
    try:
        print(f"🎵 AI 합성 요청 받음:")
        print(f"   - 사용자 ID: {request.user_id}")
        print(f"   - 가수명: {request.singer_name}")
        print(f"   - 곡명: {request.song_name}")
        print(f"   - 모델명: {request.model_name}")
        
        # 3. RunPod에 AI 합성 작업 요청 (테스트용 더미 데이터)
        synthesis_payload = {
            "input": {
                "user_vocal_url": f"https://test-bucket.s3.amazonaws.com/audio/{request.user_id}/test_vocal.wav",
                "singer_embedding_url": f"https://test-bucket.s3.amazonaws.com/embeddings/{request.singer_name}/test_embedding.json",
                "singer_name": request.singer_name,
                "song_name": request.song_name,
                "user_id": request.user_id,
                "model_name": request.model_name or f"user_{request.user_id}_model",
                "synthesis_config": {
                    "pitch_shift": 0,  # 피치 조정 (필요시)
                    "formant_shift": 0,  # 포먼트 조정 (필요시)
                    "output_format": "wav",
                    "sample_rate": 44100
                }
            }
        }
        
        # RunPod API 호출 (실제 호출)
        print(f"🚀 RunPod에 전송할 페이로드: {json.dumps(synthesis_payload, indent=2, ensure_ascii=False)}")
        
        try:
            # 클라우드 GPU 클라이언트 초기화 및 가져오기
            print(f"🔧 클라우드 GPU 클라이언트 초기화: {CLOUD_GPU_API_URL}")
            try:
                from .cloud_gpu_client import cloud_gpu_client
                if cloud_gpu_client is None:
                    init_cloud_gpu_client(CLOUD_GPU_API_URL)
                    from .cloud_gpu_client import cloud_gpu_client
                print(f"✅ 클라우드 GPU 클라이언트 초기화 완료")
            except Exception as init_error:
                print(f"❌ 클라우드 GPU 클라이언트 초기화 실패: {init_error}")
                raise Exception(f"클라우드 GPU 클라이언트 초기화 실패: {init_error}")
            
            # RunPod RVC API 서버에 합성 요청
            if cloud_gpu_client is None:
                raise Exception("클라우드 GPU 클라이언트가 초기화되지 않았습니다")
            
            print(f"🚀 RunPod RVC API 서버에 합성 요청 전송...")
            synthesis_response = cloud_gpu_client.start_rvc_synthesis(synthesis_payload)
            print(f"✅ RunPod RVC API 서버 응답: {synthesis_response}")
        except Exception as e:
            print(f"❌ RunPod RVC API 서버 호출 실패: {e}")
            # API 서버 호출 실패 시에도 테스트용 응답으로 계속 진행
            synthesis_response = {
                "id": f"test_job_{request.user_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
                "status": "IN_QUEUE"
            }
            print(f"🔄 테스트용 응답으로 대체: {synthesis_response}")
        
        # 4. 데이터베이스에 합성 작업 기록 (테스트 중 비활성화)
        print("📝 데이터베이스 저장은 테스트 중 비활성화됨")
        # TODO: 실제 사용자 인증 시스템과 연동 후 활성화
        
        return AISynthesisResponse(
            success=True,
            job_id=synthesis_response["id"],
            message="AI 음성 합성이 시작되었습니다.",
            estimated_time="약 2-5분 소요 예상"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI 합성 시작 실패: {str(e)}")

@router.get("/synthesis-status/{job_id}")
async def get_synthesis_status(
    job_id: str,
    user_id: str,
    db: Session = Depends(get_db)
):
    """AI 합성 상태 확인"""
    try:
        # RunPod에서 상태 확인
        status_response = runpod_client.get_synthesis_status(job_id)
        
        # 데이터베이스 업데이트 (기존 AiCover 테이블 사용)
        ai_cover = db.query(AiCover).filter(
            AiCover.job_id == job_id,
            AiCover.user_id == user_id
        ).first()
        
        if ai_cover:
            ai_cover.status = status_response.get("status", "UNKNOWN")
            ai_cover.progress = status_response.get("output", {}).get("progress", 0)
            if status_response.get("status") == "COMPLETED":
                ai_cover.completed_at = datetime.now()
                ai_cover.ai_cover_file = status_response.get("output", {}).get("synthesized_audio_url")
            elif status_response.get("status") == "FAILED":
                ai_cover.error_message = status_response.get("output", {}).get("message", "알 수 없는 오류")
            db.commit()
        
        return {
            "job_id": job_id,
            "status": status_response.get("status"),
            "progress": status_response.get("output", {}).get("progress", 0),
            "message": status_response.get("output", {}).get("message", ""),
            "synthesized_audio_url": status_response.get("output", {}).get("synthesized_audio_url"),
            "error_message": ai_cover.error_message if ai_cover else None
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"상태 확인 실패: {str(e)}")

@router.get("/user-syntheses/{user_id}")
async def get_user_syntheses(
    user_id: str,
    db: Session = Depends(get_db)
):
    """사용자의 AI 합성 결과 목록"""
    try:
        ai_covers = db.query(AiCover).filter(
            AiCover.user_id == user_id
        ).order_by(AiCover.created_at.desc()).all()
        
        return {
            "syntheses": [
                {
                    "id": ai_cover.ai_cover_id,
                    "job_id": ai_cover.job_id,
                    "singer_name": ai_cover.singer_name,
                    "song_name": ai_cover.song_name,
                    "status": ai_cover.status,
                    "created_at": ai_cover.created_at,
                    "completed_at": ai_cover.completed_at,
                    "result_url": ai_cover.ai_cover_file,
                    "progress": ai_cover.progress,
                    "error_message": ai_cover.error_message
                }
                for ai_cover in ai_covers
            ]
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"합성 목록 조회 실패: {str(e)}")

@router.post("/cancel-synthesis/{job_id}")
async def cancel_synthesis(
    job_id: str,
    user_id: str,
    db: Session = Depends(get_db)
):
    """AI 합성 작업 취소"""
    try:
        # RunPod에서 작업 취소
        success = runpod_client.cancel_synthesis(job_id)
        
        if success:
            # 데이터베이스 업데이트 (기존 AiCover 테이블 사용)
            ai_cover = db.query(AiCover).filter(
                AiCover.job_id == job_id,
                AiCover.user_id == user_id
            ).first()
            
            if ai_cover:
                ai_cover.status = "CANCELLED"
                ai_cover.completed_at = datetime.now()
                db.commit()
        
        return {
            "success": success,
            "message": "AI 합성이 취소되었습니다." if success else "취소 실패"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"취소 실패: {str(e)}") 