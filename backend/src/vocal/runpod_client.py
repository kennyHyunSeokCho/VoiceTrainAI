import os
import requests
import json
import time
from typing import Dict, Any, Optional
from dotenv import load_dotenv
import sys
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from config import RUNPOD_API_KEY, RUNPOD_ENDPOINT_ID

load_dotenv()

class RunPodClient:
    """RunPod API를 통한 RVC 학습 관리 클라이언트"""
    
    def __init__(self):
        self.api_key = RUNPOD_API_KEY
        self.base_url = "https://api.runpod.io/v2"
        self.endpoint_id = RUNPOD_ENDPOINT_ID
        
        # 개발 환경에서는 API 키가 없어도 초기화 허용
        self.is_available = bool(self.api_key and self.endpoint_id)
        
        if not self.is_available:
            print("⚠️  RunPod API 키가 설정되지 않았습니다. RVC 학습 기능이 비활성화됩니다.")
    
    def _get_headers(self) -> Dict[str, str]:
        """API 요청 헤더 생성"""
        if not self.is_available:
            raise ValueError("RunPod API가 설정되지 않았습니다.")
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
    
    def start_rvc_training(self, 
                          audio_file_url: str, 
                          model_name: str,
                          user_id: str) -> Dict[str, Any]:
        """
        RVC 학습 시작
        
        Args:
            audio_file_url: 학습할 오디오 파일 URL
            model_name: 생성될 모델 이름
            user_id: 사용자 ID
            
        Returns:
            학습 작업 정보
        """
        if not self.is_available:
            raise ValueError("RunPod API가 설정되지 않아 RVC 학습을 시작할 수 없습니다.")
        
        payload = {
            "input": {
                "audio_url": audio_file_url,
                "model_name": model_name,
                "user_id": user_id,
                "training_config": {
                    "epochs": 100,
                    "batch_size": 4,
                    "learning_rate": 0.0001,
                    "save_every": 10
                }
            }
        }
        
        response = requests.post(
            f"{self.base_url}/{self.endpoint_id}/run",
            headers=self._get_headers(),
            json=payload
        )
        
        if response.status_code == 200:
            return response.json()
        else:
            raise Exception(f"RunPod API 오류: {response.status_code} - {response.text}")
    
    def get_training_status(self, job_id: str) -> Dict[str, Any]:
        """학습 상태 확인"""
        response = requests.get(
            f"{self.base_url}/{self.endpoint_id}/status/{job_id}",
            headers=self._get_headers()
        )
        
        if response.status_code == 200:
            return response.json()
        else:
            raise Exception(f"상태 확인 오류: {response.status_code}")
    
    def cancel_training(self, job_id: str) -> bool:
        """학습 작업 취소"""
        response = requests.post(
            f"{self.base_url}/{self.endpoint_id}/cancel/{job_id}",
            headers=self._get_headers()
        )
        
        return response.status_code == 200
    
    def get_trained_model(self, job_id: str) -> Optional[str]:
        """학습 완료된 모델 다운로드 URL 반환"""
        status = self.get_training_status(job_id)
        
        if status.get("status") == "COMPLETED":
            output = status.get("output", {})
            return output.get("model_url")
        
        return None
    
    def start_ai_synthesis(self, synthesis_payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        AI 음성 합성 시작
        
        Args:
            synthesis_payload: 합성 작업 페이로드
            
        Returns:
            합성 작업 정보
        """
        if not self.is_available:
            raise ValueError("RunPod API가 설정되지 않아 AI 합성을 시작할 수 없습니다.")
        
        response = requests.post(
            f"{self.base_url}/{self.endpoint_id}/run",
            headers=self._get_headers(),
            json=synthesis_payload
        )
        
        if response.status_code == 200:
            return response.json()
        else:
            raise Exception(f"RunPod AI 합성 API 오류: {response.status_code} - {response.text}")
    
    def get_synthesis_status(self, job_id: str) -> Dict[str, Any]:
        """AI 합성 상태 확인"""
        response = requests.get(
            f"{self.base_url}/{self.endpoint_id}/status/{job_id}",
            headers=self._get_headers()
        )
        
        if response.status_code == 200:
            return response.json()
        else:
            raise Exception(f"AI 합성 상태 확인 오류: {response.status_code}")
    
    def cancel_synthesis(self, job_id: str) -> bool:
        """AI 합성 작업 취소"""
        response = requests.post(
            f"{self.base_url}/{self.endpoint_id}/cancel/{job_id}",
            headers=self._get_headers()
        )
        
        return response.status_code == 200

# 싱글톤 인스턴스
runpod_client = RunPodClient() 