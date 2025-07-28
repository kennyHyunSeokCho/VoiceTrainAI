from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import subprocess
import json
import os
import uuid
from typing import Dict, Any, Optional
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="RVC API Server", version="1.0.0")

class RVCInferenceRequest(BaseModel):
    """RVC 추론 요청 모델"""
    user_vocal_url: str  # 사용자 보컬 파일 URL
    singer_embedding_url: str  # 가수 임베딩 파일 URL
    singer_name: str  # 가수명
    song_name: str  # 곡명
    user_id: str  # 사용자 ID
    model_name: str = "my_model"  # RVC 모델명
    pitch_shift: int = 0  # 피치 조정
    formant_shift: int = 0  # 포먼트 조정
    output_format: str = "wav"  # 출력 형식
    sample_rate: str = "40000"  # 샘플레이트

class RVCInferenceResponse(BaseModel):
    """RVC 추론 응답 모델"""
    success: bool
    job_id: str
    message: str
    output_url: Optional[str] = None
    error_message: Optional[str] = None

# 작업 상태 저장소 (실제로는 Redis나 DB 사용 권장)
jobs = {}

@app.post("/api/synthesis", response_model=RVCInferenceResponse)
async def start_rvc_synthesis(request: RVCInferenceRequest):
    """
    RVC 음성 합성 시작
    
    Args:
        request: RVC 추론 요청 정보
        
    Returns:
        합성 작업 정보
    """
    try:
        # 고유 작업 ID 생성
        job_id = str(uuid.uuid4())
        
        logger.info(f"🎵 RVC 합성 요청 받음 (Job ID: {job_id}):")
        logger.info(f"   - 사용자 ID: {request.user_id}")
        logger.info(f"   - 가수명: {request.singer_name}")
        logger.info(f"   - 곡명: {request.song_name}")
        logger.info(f"   - 모델명: {request.model_name}")
        
        # 작업 상태 초기화
        jobs[job_id] = {
            "status": "RUNNING",
            "progress": 0,
            "request": request.dict(),
            "output_url": None,
            "error_message": None
        }
        
        # test_models.py 실행을 위한 명령어 구성
        # 실제 test_models.py의 인자에 맞게 수정 필요
        test_models_cmd = [
            "python", "test_models.py",
            "--model_name", request.model_name,
            "--input_file", request.user_vocal_url,  # 실제로는 로컬 파일 경로
            "--output_file", f"output_{job_id}.wav",
            "--pitch_shift", str(request.pitch_shift),
            "--formant_shift", str(request.formant_shift),
            "--sample_rate", request.sample_rate
        ]
        
        logger.info(f"🚀 test_models.py 실행 명령어: {' '.join(test_models_cmd)}")
        
        # 비동기로 test_models.py 실행 (실제로는 백그라운드에서 실행)
        # 여기서는 시뮬레이션
        import asyncio
        asyncio.create_task(run_rvc_synthesis(job_id, test_models_cmd))
        
        return RVCInferenceResponse(
            success=True,
            job_id=job_id,
            message="RVC 음성 합성이 시작되었습니다.",
            output_url=None
        )
        
    except Exception as e:
        logger.error(f"❌ RVC 합성 시작 실패: {e}")
        raise HTTPException(status_code=500, detail=f"RVC 합성 시작 실패: {str(e)}")

async def run_rvc_synthesis(job_id: str, cmd: list):
    """백그라운드에서 RVC 합성 실행"""
    try:
        logger.info(f"🔄 Job {job_id}: test_models.py 실행 시작")
        
        # 실제 test_models.py 실행
        # result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        
        # 시뮬레이션 (실제로는 위의 subprocess.run 사용)
        import asyncio
        await asyncio.sleep(5)  # 5초 대기 (실제 합성 시간)
        
        # 성공 시뮬레이션
        output_file = f"output_{job_id}.wav"
        output_url = f"https://60i3lgomb5uz53-8888.proxy.runpod.net/outputs/{output_file}"
        
        jobs[job_id].update({
            "status": "COMPLETED",
            "progress": 100,
            "output_url": output_url
        })
        
        logger.info(f"✅ Job {job_id}: RVC 합성 완료 - {output_url}")
        
    except Exception as e:
        logger.error(f"❌ Job {job_id}: RVC 합성 실패 - {e}")
        jobs[job_id].update({
            "status": "FAILED",
            "error_message": str(e)
        })

@app.get("/api/status/{job_id}")
async def get_synthesis_status(job_id: str):
    """합성 상태 확인"""
    if job_id not in jobs:
        raise HTTPException(status_code=404, detail="작업을 찾을 수 없습니다.")
    
    job = jobs[job_id]
    
    return {
        "job_id": job_id,
        "status": job["status"],
        "progress": job["progress"],
        "output_url": job.get("output_url"),
        "error_message": job.get("error_message")
    }

@app.post("/api/cancel/{job_id}")
async def cancel_synthesis(job_id: str):
    """합성 작업 취소"""
    if job_id not in jobs:
        raise HTTPException(status_code=404, detail="작업을 찾을 수 없습니다.")
    
    jobs[job_id]["status"] = "CANCELLED"
    
    return {"success": True, "message": "작업이 취소되었습니다."}

@app.get("/health")
async def health_check():
    """헬스 체크"""
    return {"status": "healthy", "message": "RVC API Server is running"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8888) 