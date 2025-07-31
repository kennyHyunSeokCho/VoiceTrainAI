#!/usr/bin/env python3
"""
RunPod Pod에 직접 연결하는 클라이언트
Serverless Endpoint를 거치지 않고 Pod에 직접 API 호출
"""

import requests
import json
import time
from typing import Dict, Any, Optional
from dotenv import load_dotenv
import os

load_dotenv()

class PodDirectClient:
    """RunPod Pod에 직접 연결하는 클라이언트"""
    
    def __init__(self, pod_url: str = None):
        """
        Pod URL 설정
        예: http://60i3lgomb5uz53-8888.proxy.runpod.net:8000
        
        ⚠️ 주의: 
        - Jupyter Lab URL (포트 8888)이 아닌 API 서버 URL (포트 8000)을 사용
        - https://.../lab (X) → http://...:8000 (O)
        """
        self.pod_url = pod_url or os.getenv("POD_DIRECT_URL")
        if not self.pod_url:
            raise ValueError("Pod URL이 설정되지 않았습니다. POD_DIRECT_URL 환경변수를 설정하거나 pod_url을 전달하세요.")
        
        # URL 정규화 (HTTPS 사용 - RunPod 프록시가 HTTPS로 작동)
        if not self.pod_url.startswith(("http://", "https://")):
            self.pod_url = f"https://{self.pod_url}"
        
        # HTTPS를 HTTP로 변환하지 않음 (RunPod 프록시는 HTTPS로 작동)
        # 포트 8000을 명시적으로 추가하지 않음 (RunPod 프록시가 자동으로 처리)
        
        print(f"[INFO] Pod 직접 연결: {self.pod_url}")
    
    def health_check(self) -> Dict[str, Any]:
        """Pod 서버 상태 확인"""
        try:
            response = requests.get(f"{self.pod_url}/health", timeout=10)
            if response.status_code == 200:
                return response.json()
            else:
                raise Exception(f"Health check 실패: {response.status_code}")
        except Exception as e:
            raise Exception(f"Pod 연결 실패: {e}")
    
    def start_synthesis(self, 
                       user_id: str,
                       artist: str,
                       title: str,
                       user_vocal_s3: str,
                       vocal_s3: str,
                       inst_s3: str) -> Dict[str, Any]:
        """
        합성 작업 시작
        """
        payload = {
            "user_id": user_id,
            "artist": artist,
            "title": title,
            "user_vocal_s3": user_vocal_s3,
            "vocal_s3": vocal_s3,
            "inst_s3": inst_s3
        }
        
        print(f"[INFO] Pod에 합성 요청: {payload}")
        
        try:
            response = requests.post(
                f"{self.pod_url}/synthesis/start",
                json=payload,
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                print(f"[INFO] 합성 작업 시작 성공: {result}")
                return result
            else:
                raise Exception(f"합성 시작 실패: {response.status_code} - {response.text}")
                
        except Exception as e:
            raise Exception(f"Pod API 호출 실패: {e}")
    
    def get_synthesis_status(self, job_id: str) -> Dict[str, Any]:
        """합성 작업 상태 확인"""
        try:
            response = requests.get(
                f"{self.pod_url}/synthesis/status/{job_id}",
                timeout=10
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                raise Exception(f"상태 확인 실패: {response.status_code}")
                
        except Exception as e:
            raise Exception(f"상태 확인 API 호출 실패: {e}")
    
    def list_jobs(self) -> Dict[str, Any]:
        """모든 작업 목록 조회"""
        try:
            response = requests.get(f"{self.pod_url}/jobs", timeout=10)
            if response.status_code == 200:
                return response.json()
            else:
                raise Exception(f"작업 목록 조회 실패: {response.status_code}")
        except Exception as e:
            raise Exception(f"작업 목록 API 호출 실패: {e}")
    
    def cancel_synthesis(self, job_id: str) -> bool:
        """합성 작업 취소"""
        try:
            response = requests.post(
                f"{self.pod_url}/synthesis/cancel/{job_id}",
                timeout=10
            )
            
            if response.status_code == 200:
                return True
            else:
                print(f"작업 취소 실패: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"작업 취소 API 호출 실패: {e}")
            return False
    
    def wait_for_completion(self, job_id: str, check_interval: int = 30) -> Dict[str, Any]:
        """
        작업 완료까지 대기
        """
        print(f"[INFO] 작업 완료 대기 중: {job_id}")
        
        while True:
            try:
                status = self.get_synthesis_status(job_id)
                
                if status["status"] == "completed":
                    print(f"[INFO] 작업 완료: {job_id}")
                    return status
                elif status["status"] == "failed":
                    print(f"[ERROR] 작업 실패: {job_id}")
                    return status
                else:
                    progress = status.get("progress", 0)
                    elapsed = status.get("elapsed_time", 0)
                    print(f"[INFO] 진행률: {progress}% (경과: {elapsed:.0f}초)")
                    time.sleep(check_interval)
                    
            except Exception as e:
                print(f"[WARNING] 상태 확인 실패: {e}")
                time.sleep(check_interval)

# 사용 예시
if __name__ == "__main__":
    # 환경변수에서 Pod URL 가져오기
    pod_url = os.getenv("POD_DIRECT_URL")
    if not pod_url:
        print("POD_DIRECT_URL 환경변수를 설정하세요.")
        print("❌ 잘못된 예시: https://60i3lgomb5uz53-8888.proxy.runpod.net/lab")
        print("✅ 올바른 예시: http://60i3lgomb5uz53-8888.proxy.runpod.net:8000")
        print("\n차이점:")
        print("- Jupyter Lab: 포트 8888, /lab 경로")
        print("- API 서버: 포트 8000, API 엔드포인트들")
        exit(1)
    
    client = PodDirectClient(pod_url)
    
    # 상태 확인
    try:
        health = client.health_check()
        print(f"Pod 상태: {health}")
    except Exception as e:
        print(f"Pod 연결 실패: {e}")
        exit(1)
    
    # 테스트 요청
    test_request = {
        "user_id": "test_user",
        "artist": "test_artist", 
        "title": "test_song",
        "user_vocal_s3": "test/user_vocal.wav",
        "vocal_s3": "MusicFile/test_artist/vocal/test_artist_test_song_vocal.wav",
        "inst_s3": "MusicFile/test_artist/inst/test_artist_test_song_inst.wav"
    }
    
    try:
        # 합성 시작
        result = client.start_synthesis(**test_request)
        job_id = result["job_id"]
        
        # 완료까지 대기
        final_result = client.wait_for_completion(job_id)
        print(f"최종 결과: {final_result}")
        
    except Exception as e:
        print(f"테스트 실패: {e}") 