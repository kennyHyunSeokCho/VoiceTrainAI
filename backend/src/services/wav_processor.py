#!/usr/bin/env python3
"""
wav 파일 처리 서비스
S3에서 새로 업로드된 wav 파일을 감지하여 임베딩을 추출하고 결과를 S3에 업로드
"""

import os
import sys
import asyncio
import numpy as np
import torch
import soundfile as sf
import json
import tempfile
import logging
import boto3
from datetime import datetime
from typing import Dict, List, Optional
from src.vocal.singer_identity import load_model
from src.vocal.s3_config import AWS_ACCESS_KEY, AWS_SECRET_KEY, USER_BUCKET_NAME, REGION_NAME

# librosa 캐싱 문제 해결을 위한 환경 변수 설정
os.environ['LIBROSA_CACHE_DIR'] = '/tmp/librosa_cache'
os.environ['JOBLIB_TEMP_FOLDER'] = '/tmp/joblib_cache'
os.environ['LIBROSA_CACHE_LEVEL'] = '0'
os.environ['LIBROSA_DISABLE_CACHE'] = '1'
os.environ['JOBLIB_N_JOBS'] = '1'

logger = logging.getLogger(__name__)

def safe_delete_file(file_path: str, max_retries: int = 3, delay: float = 1.0) -> bool:
    """
    Windows에서 안전하게 파일을 삭제하는 함수
    
    Args:
        file_path: 삭제할 파일 경로
        max_retries: 최대 재시도 횟수
        delay: 재시도 간 대기 시간 (초)
    
    Returns:
        삭제 성공 여부
    """
    import time
    
    for attempt in range(max_retries):
        try:
            if os.path.exists(file_path):
                os.unlink(file_path)
                logger.info(f"파일 삭제 성공: {file_path}")
                return True
            else:
                logger.info(f"파일이 이미 존재하지 않음: {file_path}")
                return True
        except PermissionError as e:
            if attempt < max_retries - 1:
                logger.warning(f"파일 삭제 실패 (시도 {attempt + 1}/{max_retries}): {file_path}, 오류: {e}")
                time.sleep(delay)
            else:
                logger.error(f"파일 삭제 최종 실패: {file_path}, 오류: {e}")
                return False
        except Exception as e:
            logger.error(f"파일 삭제 중 예상치 못한 오류: {file_path}, 오류: {e}")
            return False
    
    return False

class WavProcessorService:
    def __init__(self):
        self.s3_client = boto3.client(
            's3',
            aws_access_key_id=AWS_ACCESS_KEY,
            aws_secret_access_key=AWS_SECRET_KEY,
            region_name=REGION_NAME
        )
        self.model = None
        self.last_check_time = datetime.now()
        self.monitoring = False
        # 파일 상태 추적을 위한 딕셔너리 (key: file_key, value: (size, last_modified))
        self.file_states = {}
        
    def load_model(self):
        """singer-identity 모델을 로드합니다."""
        try:
            if self.model is None:
                logger.info("Loading singer-identity model...")
                self.model = load_model('byol')
                if self.model is not None:
                    self.model.eval()
                    logger.info("Singer-identity model loaded successfully")
                else:
                    logger.error("Failed to load model")
            return self.model
        except Exception as e:
            logger.error(f"Failed to load singer-identity model: {e}")
            return None
    
    def extract_embedding(self, audio: np.ndarray, target_sr: int = 44100) -> np.ndarray:
        """오디오에서 음색 임베딩 추출 (기존 가수 데이터와 동일한 방식)"""
        try:
            logger.info(f"Extracting embedding: audio shape={audio.shape}, target_sr={target_sr}")
            
            # 스테레오를 모노로 변환 (기존 가수 데이터와 동일)
            if len(audio.shape) > 1:
                audio = np.mean(audio, axis=1)
            
            # 샘플링 레이트 변환 (기존 가수 데이터와 동일한 librosa 사용)
            if target_sr is not None:
                import librosa
                audio = librosa.resample(audio, orig_sr=target_sr, target_sr=target_sr)
                logger.info(f"Resampled to {target_sr} Hz using librosa")
            
            # 4초 세그먼트로 분할 (기존 가수 데이터와 동일)
            segment_length = 4 * 44100
            segments = []
            for i in range(0, len(audio), segment_length):
                segment = audio[i:i + segment_length]
                if len(segment) == segment_length:
                    segments.append(segment)
            
            # 세그먼트가 없으면 패딩
            if not segments:
                segments.append(np.pad(audio, (0, segment_length - len(audio)), 'constant'))
            
            # 각 세그먼트에서 임베딩 추출
            embeddings = []
            model = self.load_model()
            if model is None:
                raise Exception("Model not loaded")
                
            for segment in segments:
                audio_tensor = torch.tensor(segment).unsqueeze(0).float()
                with torch.no_grad():
                    embedding = model(audio_tensor)
                    embeddings.append(embedding.numpy()[0])
            
            # 최종 임베딩은 평균
            final_embedding = np.mean(embeddings, axis=0)
            logger.info(f"Embedding extracted: shape={final_embedding.shape}")
            return final_embedding
            
        except Exception as e:
            logger.error(f"Error extracting embedding: {e}")
            raise
    
    def get_wav_files(self) -> List[Dict]:
        """USER_BUCKET에서 모든 wav 파일 목록을 가져옵니다."""
        try:
            wav_files = []
            paginator = self.s3_client.get_paginator('list_objects_v2')
            for page in paginator.paginate(Bucket=USER_BUCKET_NAME):
                for obj in page.get('Contents', []):
                    key = obj['Key']
                    if key.endswith('.wav') and '/voice_only/' in key:
                        wav_files.append({
                            'key': key,
                            'last_modified': obj['LastModified'],
                            'size': obj['Size']
                        })
            logger.info(f"Found {len(wav_files)} wav files")
            return wav_files
        except Exception as e:
            logger.error(f"Error getting wav files: {str(e)}")
            return []
    
    def extract_user_id_from_wav_key(self, key: str) -> Optional[str]:
        """wav 파일 키에서 사용자 ID를 추출합니다."""
        try:
            # 예: 'user_id/voice_only/file.wav' -> 'user_id'
            parts = key.split('/')
            if len(parts) >= 2:
                return parts[0]  # 첫 번째 디렉토리가 user_id
            return None
        except Exception as e:
            logger.error(f"Error extracting user ID: {str(e)}")
            return None
    
    def is_file_changed(self, file_info: Dict) -> bool:
        """파일이 변경되었는지 확인합니다 (새 파일이거나 수정된 파일)."""
        key = file_info['key']
        current_size = file_info['size']
        current_modified = file_info['last_modified'].replace(tzinfo=None)
        
        # 이전 상태 확인
        if key in self.file_states:
            prev_size, prev_modified = self.file_states[key]
            
            # 크기나 수정 시간이 변경되었으면 처리
            # 수정 시간이 1초 이상 차이나야 변경으로 인식 (무한 루프 방지)
            if current_size != prev_size or (current_modified - prev_modified).total_seconds() > 1:
                logger.info(f"파일 변경 감지: {key} (크기: {prev_size}->{current_size}, 수정시간: {prev_modified}->{current_modified})")
                return True
            else:
                return False
        else:
            # 새로운 파일
            logger.info(f"새 파일 감지: {key}")
            return True

    def update_file_state(self, file_info: Dict):
        """파일 상태를 업데이트합니다."""
        key = file_info['key']
        current_size = file_info['size']
        current_modified = file_info['last_modified'].replace(tzinfo=None)
        self.file_states[key] = (current_size, current_modified)
        logger.info(f"파일 상태 업데이트: {key}")

    def process_wav_file(self, user_id: str, wav_key: str) -> bool:
        """wav 파일을 처리하여 임베딩을 추출하고 S3에 업로드합니다."""
        temp_path = None
        temp_json_path = None
        temp_file = None
        temp_json_file = None
        
        try:
            logger.info(f"Processing wav file: {wav_key} for user: {user_id}")
            
            # S3에서 wav 파일 다운로드 (Windows 호환성을 위해 명시적으로 파일 핸들 관리)
            temp_file = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
            temp_path = temp_file.name
            temp_file.close()  # 명시적으로 파일 핸들 닫기
            
            self.s3_client.download_file(USER_BUCKET_NAME, wav_key, temp_path)
            logger.info(f"Downloaded file to: {temp_path}")
            
            # 파일이 완전히 저장될 때까지 잠시 대기
            import time
            time.sleep(0.5)
            
            # 기존 가수 데이터와 동일한 방식: soundfile로 로드
            try:
                audio, sr = sf.read(temp_path)
                logger.info(f"Audio loaded: shape={audio.shape}, sr={sr}")
            except Exception as e:
                logger.error(f"Error reading audio file: {e}")
                # 파일이 사용 중일 수 있으므로 잠시 대기 후 재시도
                time.sleep(1)
                audio, sr = sf.read(temp_path)
                logger.info(f"Audio loaded on retry: shape={audio.shape}, sr={sr}")
            
            # 임베딩 추출 (기존 가수 데이터와 동일한 방식)
            embedding = self.extract_embedding(audio, sr)
            logger.info(f"Embedding extracted: shape={embedding.shape}")
            
            # 결과 JSON 구성 (기존 가수 데이터와 동일한 형식)
            result = {
                "user_id": user_id,
                "wav_file": wav_key,
                "embedding": embedding.tolist(),
                "timestamp": datetime.now().isoformat(),
                "sample_rate": sr,
                "audio_shape": list(audio.shape)
            }
            
            # S3에 결과 업로드 (Windows 호환성을 위해 명시적으로 파일 핸들 관리)
            output_key = f"{user_id}/timbre/{os.path.basename(wav_key).replace('.wav', '_timbre.json')}"
            temp_json_file = tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False)
            temp_json_path = temp_json_file.name
            temp_json_file.close()  # 명시적으로 파일 핸들 닫기
            
            # JSON 파일에 데이터 쓰기
            with open(temp_json_path, 'w', encoding='utf-8') as f:
                json.dump(result, f, indent=2, ensure_ascii=False)
            
            # JSON 파일이 완전히 저장될 때까지 대기
            time.sleep(0.5)
            
            self.s3_client.upload_file(temp_json_path, USER_BUCKET_NAME, output_key)
            logger.info(f"Result uploaded to: {output_key}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error processing wav file {wav_key}: {str(e)}")
            return False
        finally:
            # 임시 파일들을 안전하게 삭제 (Windows 파일 접근 오류 방지)
            import time
            import gc
            
            # 가비지 컬렉션으로 메모리 정리
            gc.collect()
            
            # 임시 JSON 파일 삭제
            if temp_json_path:
                safe_delete_file(temp_json_path)
            
            # 임시 wav 파일 삭제
            if temp_path:
                safe_delete_file(temp_path)
    
    async def check_and_process_new_wav_files(self) -> List[str]:
        """새로 업로드되거나 변경된 wav 파일들을 처리합니다."""
        processed_users = []
        try:
            wav_files = self.get_wav_files()
            logger.info(f"총 {len(wav_files)}개의 wav 파일 확인")
            
            for file_info in wav_files:
                if self.is_file_changed(file_info):
                    user_id = self.extract_user_id_from_wav_key(file_info['key'])
                    if user_id:
                        logger.info(f"변경된 wav 파일 처리: {file_info['key']} (사용자: {user_id})")
                        
                        # 임베딩 추출
                        if self.process_wav_file(user_id, file_info['key']):
                            logger.info(f"임베딩 추출 완료: {user_id}")
                            processed_users.append(user_id)
                        
                        # 파일 상태 업데이트
                        self.update_file_state(file_info)
            
            if processed_users:
                logger.info(f"처리된 사용자: {processed_users}")
            
        except Exception as e:
            logger.error(f"wav 파일 처리 중 오류: {str(e)}")
        
        return processed_users
    
    async def start_monitoring(self, check_interval: int = 60):
        """wav 파일 모니터링을 시작합니다."""
        self.monitoring = True
        logger.info(f"wav 파일 모니터링 시작 (체크 간격: {check_interval}초)")
        
        # 초기 실행: 기존 파일들의 상태를 기록 (처리하지는 않음)
        try:
            logger.info("🔄 초기 실행: 기존 wav 파일들의 상태 기록...")
            wav_files = self.get_wav_files()
            for file_info in wav_files:
                self.update_file_state(file_info)
            logger.info(f"📋 기존 파일 상태 기록 완료: {len(wav_files)}개 파일")
        except Exception as e:
            logger.error(f"초기 파일 상태 기록 오류: {str(e)}")
        
        # 정기 모니터링 시작
        while self.monitoring:
            try:
                # 변경된 wav 파일 확인 및 처리
                processed_users = await self.check_and_process_new_wav_files()
                
                if processed_users:
                    logger.info(f"처리된 사용자: {', '.join(processed_users)}")
                
            except Exception as e:
                logger.error(f"모니터링 루프 오류: {str(e)}")
            
            # 다음 체크까지 대기
            await asyncio.sleep(check_interval)
    
    def stop_monitoring(self):
        """wav 파일 모니터링을 중지합니다."""
        self.monitoring = False
        logger.info("wav 파일 모니터링 중지")

# 전역 인스턴스
wav_processor = WavProcessorService() 