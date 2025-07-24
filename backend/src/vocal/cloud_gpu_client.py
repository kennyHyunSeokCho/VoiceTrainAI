import requests
import json
import time
from typing import Dict, Any, Optional
import logging

logger = logging.getLogger(__name__)

class CloudGPUClient:
    """클라우드 GPU의 RVC API를 호출하는 클라이언트"""
    
    def __init__(self, gpu_api_url: str):
        """
        Args:
            gpu_api_url: 클라우드 GPU의 API URL (예: http://your-gpu-server:7860)
        """
        self.gpu_api_url = gpu_api_url.rstrip('/')
        self.is_available = bool(gpu_api_url)
        
        if not self.is_available:
            logger.warning("⚠️  클라우드 GPU API URL이 설정되지 않았습니다.")
    
    def start_rvc_synthesis(self, synthesis_payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        RVC 음성 합성 시작
        
        Args:
            synthesis_payload: 합성 요청 데이터
            
        Returns:
            합성 작업 정보
        """
        if not self.is_available:
            raise ValueError("클라우드 GPU API가 설정되지 않았습니다.")
        
        try:
            # RVC API 엔드포인트 (실제 RVC WebUI의 API 경로에 맞게 수정)
            api_endpoint = f"{self.gpu_api_url}/api/synthesis"
            
            logger.info(f"🚀 클라우드 GPU에 RVC 합성 요청 전송: {api_endpoint}")
            logger.info(f"📦 페이로드: {json.dumps(synthesis_payload, indent=2, ensure_ascii=False)}")
            
            response = requests.post(
                api_endpoint,
                headers={"Content-Type": "application/json"},
                json=synthesis_payload,
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                logger.info(f"✅ 클라우드 GPU 응답: {result}")
                return result
            else:
                logger.error(f"❌ 클라우드 GPU API 오류: {response.status_code} - {response.text}")
                raise Exception(f"클라우드 GPU API 오류: {response.status_code} - {response.text}")
                
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ 클라우드 GPU 연결 실패: {e}")
            raise Exception(f"클라우드 GPU 연결 실패: {e}")
    
    def get_synthesis_status(self, job_id: str) -> Dict[str, Any]:
        """
        합성 상태 확인
        
        Args:
            job_id: 작업 ID
            
        Returns:
            상태 정보
        """
        if not self.is_available:
            raise ValueError("클라우드 GPU API가 설정되지 않았습니다.")
        
        try:
            api_endpoint = f"{self.gpu_api_url}/api/status/{job_id}"
            
            response = requests.get(
                api_endpoint,
                timeout=10
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                logger.error(f"❌ 상태 확인 오류: {response.status_code} - {response.text}")
                raise Exception(f"상태 확인 오류: {response.status_code}")
                
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ 상태 확인 연결 실패: {e}")
            raise Exception(f"상태 확인 연결 실패: {e}")
    
    def cancel_synthesis(self, job_id: str) -> bool:
        """
        합성 작업 취소
        
        Args:
            job_id: 작업 ID
            
        Returns:
            취소 성공 여부
        """
        if not self.is_available:
            raise ValueError("클라우드 GPU API가 설정되지 않았습니다.")
        
        try:
            api_endpoint = f"{self.gpu_api_url}/api/cancel/{job_id}"
            
            response = requests.post(
                api_endpoint,
                timeout=10
            )
            
            return response.status_code == 200
            
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ 작업 취소 실패: {e}")
            return False

# 전역 인스턴스 생성 (config.py에서 URL 설정)
cloud_gpu_client = None

def init_cloud_gpu_client(gpu_api_url: str):
    """클라우드 GPU 클라이언트 초기화"""
    global cloud_gpu_client
    try:
        cloud_gpu_client = CloudGPUClient(gpu_api_url)
        logger.info(f"✅ 클라우드 GPU 클라이언트 초기화 성공: {gpu_api_url}")
        return cloud_gpu_client
    except Exception as e:
        logger.error(f"❌ 클라우드 GPU 클라이언트 초기화 실패: {e}")
        cloud_gpu_client = None
        raise 