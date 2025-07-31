#!/usr/bin/env python3
"""
RunPod Pod에서 실행되는 API 서버
test_model.py를 subprocess로 실행하여 RVC 파이프라인을 처리
"""

from fastapi import FastAPI, BackgroundTasks, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import subprocess
import os
import uuid
import time
import json
from typing import Dict, Any, Optional
import uvicorn

app = FastAPI(title="RVC Pipeline API Server", version="1.0.0")

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 작업 상태 저장소 (메모리 기반)
jobs = {}

class SynthesisRequest(BaseModel):
    user_id: str
    artist: str
    title: str
    user_vocal_s3: str
    vocal_s3: str
    inst_s3: str

class JobStatus:
    def __init__(self, job_id: str, request: SynthesisRequest):
        self.job_id = job_id
        self.request = request
        self.status = "pending"  # pending, running, completed, failed
        self.progress = 0
        self.start_time = time.time()
        self.end_time = None
        self.result = None
        self.error = None
        self.process = None

def run_test_model(job_id: str, request: SynthesisRequest):
    """
    test_model.py를 subprocess로 실행
    """
    try:
        # 작업 상태 업데이트
        jobs[job_id].status = "running"
        jobs[job_id].progress = 10
        
        # test_model.py 경로 확인
        test_model_path = "test_model.py"
        if not os.path.exists(test_model_path):
            # Cloud_code 폴더에서 찾기
            test_model_path = "Cloud_code/test_model.py"
            if not os.path.exists(test_model_path):
                raise Exception("test_model.py를 찾을 수 없습니다!")
        
        print(f"[INFO] test_model.py 실행 시작: {test_model_path}")
        print(f"[INFO] 인자: {request.dict()}")
        
        # test_model.py 실행 명령어 구성
        cmd = [
            "python3", test_model_path,
            "--user_id", request.user_id,
            "--artist", request.artist,
            "--title", request.title,
            "--user_vocal_s3", request.user_vocal_s3,
            "--vocal_s3", request.vocal_s3,
            "--inst_s3", request.inst_s3
        ]
        
        print(f"[INFO] 실행 명령어: {' '.join(cmd)}")
        
        # subprocess로 실행 (실시간 출력을 위해 버퍼링 비활성화)
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=os.getcwd(),
            bufsize=1,  # 라인 버퍼링
            universal_newlines=True
        )
        
        # 프로세스 저장
        jobs[job_id].process = process
        
        # 진행률 업데이트
        jobs[job_id].progress = 20
        
        # 실시간 출력 처리
        stdout_lines = []
        stderr_lines = []
        step_count = 0
        
        while True:
            # stdout 읽기
            stdout_line = process.stdout.readline()
            if stdout_line:
                line = stdout_line.strip()
                print(f"[{job_id}] STDOUT: {line}")
                stdout_lines.append(stdout_line)
                
                # 진행률 업데이트 (단계별)
                if "1단계" in line:
                    jobs[job_id].progress = 10
                elif "2단계" in line:
                    jobs[job_id].progress = 20
                elif "3단계" in line:
                    jobs[job_id].progress = 30
                elif "4단계" in line:
                    jobs[job_id].progress = 40
                elif "5단계" in line:
                    jobs[job_id].progress = 50
                elif "6단계" in line:
                    jobs[job_id].progress = 60
                elif "7단계" in line:
                    jobs[job_id].progress = 70
                elif "8단계" in line:
                    jobs[job_id].progress = 80
                elif "9단계" in line:
                    jobs[job_id].progress = 85
                elif "10단계" in line:
                    jobs[job_id].progress = 90
                elif "11단계" in line:
                    jobs[job_id].progress = 95
                elif "🎉 AI 음성 합성 파이프라인 완료!" in line:
                    jobs[job_id].progress = 100
            
            # stderr 읽기
            stderr_line = process.stderr.readline()
            if stderr_line:
                line = stderr_line.strip()
                print(f"[{job_id}] STDERR: {line}")
                stderr_lines.append(stderr_line)
            
            # 프로세스가 종료되었는지 확인
            if process.poll() is not None:
                # 남은 출력 읽기
                remaining_stdout, remaining_stderr = process.communicate()
                if remaining_stdout:
                    print(f"[{job_id}] STDOUT: {remaining_stdout.strip()}")
                    stdout_lines.append(remaining_stdout)
                if remaining_stderr:
                    print(f"[{job_id}] STDERR: {remaining_stderr.strip()}")
                    stderr_lines.append(remaining_stderr)
                break
        
        stdout = ''.join(stdout_lines)
        stderr = ''.join(stderr_lines)
        
        # 결과 처리
        if process.returncode == 0:
            jobs[job_id].status = "completed"
            jobs[job_id].progress = 100
            jobs[job_id].result = {
                "stdout": stdout,
                "stderr": stderr,
                "return_code": process.returncode
            }
            print(f"[INFO] test_model.py 실행 완료: {job_id}")
        else:
            jobs[job_id].status = "failed"
            jobs[job_id].error = {
                "stdout": stdout,
                "stderr": stderr,
                "return_code": process.returncode
            }
            print(f"[ERROR] test_model.py 실행 실패: {job_id}")
            print(f"[ERROR] stderr: {stderr}")
        
        jobs[job_id].end_time = time.time()
        
    except Exception as e:
        jobs[job_id].status = "failed"
        jobs[job_id].error = {"message": str(e)}
        jobs[job_id].end_time = time.time()
        print(f"[ERROR] test_model.py 실행 중 예외 발생: {e}")

@app.post("/synthesis/start")
async def start_synthesis(request: SynthesisRequest, background_tasks: BackgroundTasks):
    """
    합성 작업 시작
    """
    job_id = str(uuid.uuid4())
    
    # 작업 상태 초기화
    jobs[job_id] = JobStatus(job_id, request)
    
    # 백그라운드에서 test_model.py 실행
    background_tasks.add_task(run_test_model, job_id, request)
    
    return {
        "job_id": job_id,
        "status": "started",
        "message": "합성 작업이 시작되었습니다."
    }

@app.get("/synthesis/status/{job_id}")
async def get_synthesis_status(job_id: str):
    """
    합성 작업 상태 확인
    """
    if job_id not in jobs:
        raise HTTPException(status_code=404, detail="작업을 찾을 수 없습니다.")
    
    job = jobs[job_id]
    
    # 경과 시간 계산
    elapsed_time = time.time() - job.start_time if job.start_time else 0
    
    return {
        "job_id": job_id,
        "status": job.status,
        "progress": job.progress,
        "elapsed_time": elapsed_time,
        "result": job.result,
        "error": job.error,
        "request": job.request.dict()
    }

@app.post("/synthesis/cancel/{job_id}")
async def cancel_synthesis(job_id: str):
    """
    합성 작업 취소
    """
    if job_id not in jobs:
        raise HTTPException(status_code=404, detail="작업을 찾을 수 없습니다.")
    
    job = jobs[job_id]
    
    # 실행 중인 프로세스가 있으면 종료
    if job.process and job.process.poll() is None:
        job.process.terminate()
        try:
            job.process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            job.process.kill()
    
    job.status = "cancelled"
    job.end_time = time.time()
    
    return {"message": "작업이 취소되었습니다."}

@app.get("/jobs")
async def list_jobs():
    """
    모든 작업 목록 조회
    """
    job_list = []
    for job_id, job in jobs.items():
        elapsed_time = time.time() - job.start_time if job.start_time else 0
        job_list.append({
            "job_id": job_id,
            "status": job.status,
            "progress": job.progress,
            "elapsed_time": elapsed_time,
            "request": job.request.dict()
        })
    
    return {"jobs": job_list}

@app.get("/health")
async def health_check():
    """
    서버 상태 확인
    """
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "active_jobs": len([j for j in jobs.values() if j.status in ["pending", "running"]])
    }

@app.get("/system/info")
async def system_info():
    """
    시스템 정보 조회
    """
    # test_model.py 존재 여부 확인
    test_model_exists = os.path.exists("test_model.py") or os.path.exists("Cloud_code/test_model.py")
    
    # GPU 사용 가능 여부 확인
    gpu_available = os.path.exists("/dev/nvidia0")
    
    return {
        "test_model_exists": test_model_exists,
        "gpu_available": gpu_available,
        "current_directory": os.getcwd(),
        "python_version": f"{os.sys.version_info.major}.{os.sys.version_info.minor}.{os.sys.version_info.micro}"
    }

if __name__ == "__main__":
    print("[INFO] RVC Pipeline API 서버 시작...")
    print(f"[INFO] 현재 디렉토리: {os.getcwd()}")
    print(f"[INFO] test_model.py 존재: {os.path.exists('test_model.py') or os.path.exists('Cloud_code/test_model.py')}")
    
    # GPU 확인
    if os.path.exists("/dev/nvidia0"):
        print("[INFO] GPU 사용 가능")
    else:
        print("[WARNING] GPU 사용 불가능")
    
    # 서버 시작
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,  # 8888 대신 8000 포트 사용
        log_level="info"
    ) 