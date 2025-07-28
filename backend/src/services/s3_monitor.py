import asyncio
import boto3
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from sqlalchemy.orm import Session
from src.DB.database import get_db
from src.DB.models import UsersSync, RecommendSongs
from src.vocal.s3_config import AWS_ACCESS_KEY, AWS_SECRET_KEY, BUCKET_NAME, USER_BUCKET_NAME, REGION_NAME
from src.vocal.trimbre_based_recommend import main as get_timbre_recommendations

logger = logging.getLogger(__name__)

class S3MonitorService:
    def __init__(self):
        self.s3_client = boto3.client(
            's3',
            aws_access_key_id=AWS_ACCESS_KEY,
            aws_secret_access_key=AWS_SECRET_KEY,
            region_name=REGION_NAME
        )
        self.last_check_time = datetime.now()
        self.monitoring = False
        # 파일 상태 추적을 위한 딕셔너리 (key: file_key, value: (size, last_modified))
        self.file_states = {}
        
    def get_summary_files(self) -> List[Dict]:
        """USER_BUCKET에서 모든 summary 파일 목록을 가져옵니다."""
        try:
            summary_files = []
            paginator = self.s3_client.get_paginator('list_objects_v2')
            for page in paginator.paginate(Bucket=USER_BUCKET_NAME):
                for obj in page.get('Contents', []):
                    key = obj['Key']
                    print(f"[DEBUG] S3에서 발견한 파일: {key}")  # 모든 파일 로그
                    if key.endswith('_summary.json'):
                        summary_files.append({
                            'key': key,
                            'last_modified': obj['LastModified'],
                            'size': obj['Size']
                        })
            print(f"[DEBUG] 감지된 summary 파일 목록: {[f['key'] for f in summary_files]}")
            return summary_files
        except Exception as e:
            logger.error(f"USER_BUCKET 파일 목록 조회 오류: {str(e)}")
            return []
    
    def get_user_embedding_files(self) -> List[Dict]:
        """USER_BUCKET에서 모든 사용자 임베딩 파일 목록을 가져옵니다."""
        try:
            user_files = []
            paginator = self.s3_client.get_paginator('list_objects_v2')
            for page in paginator.paginate(Bucket=USER_BUCKET_NAME):
                for obj in page.get('Contents', []):
                    key = obj['Key']
                    if key.startswith('user_embeddings/') and key.endswith('.json'):
                        user_files.append({
                            'key': key,
                            'last_modified': obj['LastModified'],
                            'size': obj['Size']
                        })
            return user_files
        except Exception as e:
            logger.error(f"USER_BUCKET 사용자 임베딩 파일 목록 조회 오류: {str(e)}")
            return []
    
    def extract_user_id_from_summary_key(self, key: str) -> str:
        """'userid/timbre/userid_summary.json'에서 userid를 robust하게 추출"""
        # 예: 'yunji/timbre/yunji_summary.json' -> 'yunji'
        try:
            # split: 'yunji/timbre/yunji_summary.json' -> ['yunji', 'timbre', 'yunji_summary.json']
            parts = key.split('/')
            if len(parts) >= 3 and parts[2].endswith('_summary.json'):
                # 파일명에서 userid 추출
                filename = parts[2]
                user_id = filename.replace('_summary.json', '')
                return user_id
            # fallback: 첫번째 디렉토리명을 user_id로 사용
            return parts[0]
        except Exception as e:
            print(f"[DEBUG] extract_user_id_from_summary_key 오류: {e}, key: {key}")
            return None
    
    def extract_user_id_from_embedding_key(self, key: str) -> Optional[str]:
        """사용자 임베딩 파일 키에서 사용자 ID를 추출합니다."""
        try:
            # 예: user_embeddings/도경수/도경수_20241201_123456.json
            parts = key.split('/')
            if len(parts) >= 2:
                return parts[1]  # 도경수
            return None
        except Exception as e:
            logger.error(f"사용자 ID 추출 오류: {str(e)}")
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
            if current_size != prev_size or current_modified > prev_modified:
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
    
    def run_recommendation_for_user(self, user_id: str, db: Session) -> bool:
        """특정 사용자에 대해 추천을 실행하고 DB에 저장합니다."""
        try:
            logger.info(f"사용자 '{user_id}'에 대한 추천 실행 시작")
            
            # test_recommend_db.py의 로직을 그대로 사용
            from src.vocal.trimbre_based_recommend import main as recommend_main
            
            # 추천 시스템 실행
            result = recommend_main(user_id)
            
            if result:
                logger.info(f"사용자 '{user_id}'의 추천 시스템 실행 완료")
                logger.info(f"추천 노래: {result['songs']}")
                logger.info(f"추천 가수: {result['singers']}")
                return True
            else:
                logger.error(f"사용자 '{user_id}'의 추천 시스템 실행 실패")
                return False
                
        except Exception as e:
            logger.error(f"추천 실행 오류 (사용자: {user_id}): {str(e)}")
            return False
    
    def check_and_update_recommendations(self, db: Session) -> List[str]:
        """변경된 파일을 확인하고 추천을 업데이트합니다."""
        updated_users = []
        
        try:
            # 최근 변경된 summary 파일 확인
            summary_files = self.get_summary_files()
            
            for file_info in summary_files:
                # 파일 변경 여부 확인
                if self.is_file_changed(file_info):
                    user_id = self.extract_user_id_from_summary_key(file_info['key'])
                    if user_id:
                        logger.info(f"변경된 summary 파일 감지: {file_info['key']} (사용자: {user_id})")
                        
                        # 추천 실행
                        if self.run_recommendation_for_user(user_id, db):
                            updated_users.append(user_id)
                            # 파일 상태 업데이트 (성공적으로 처리된 경우만)
                            self.update_file_state(file_info)
            
            # 최근 변경된 사용자 임베딩 파일 확인
            user_files = self.get_user_embedding_files()
            
            for file_info in user_files:
                # 파일 변경 여부 확인
                if self.is_file_changed(file_info):
                    user_id = self.extract_user_id_from_embedding_key(file_info['key'])
                    if user_id and user_id not in updated_users:
                        logger.info(f"변경된 사용자 임베딩 파일 감지: {file_info['key']} (사용자: {user_id})")
                        
                        # 추천 실행
                        if self.run_recommendation_for_user(user_id, db):
                            updated_users.append(user_id)
                            # 파일 상태 업데이트 (성공적으로 처리된 경우만)
                            self.update_file_state(file_info)
            
            if updated_users:
                logger.info(f"추천 업데이트 완료: {len(updated_users)}명의 사용자")
            
        except Exception as e:
            logger.error(f"S3 모니터링 오류: {str(e)}")
        
        return updated_users
    
    async def start_monitoring(self, check_interval: int = 60):
        """S3 모니터링을 시작합니다."""
        self.monitoring = True
        logger.info(f"S3 모니터링 시작 (체크 간격: {check_interval}초)")
        
        # 초기 실행: 기존 파일들의 상태를 기록 (처리하지는 않음)
        try:
            logger.info("🔄 초기 실행: 기존 파일들의 상태 기록...")
            
            # summary 파일들 상태 기록
            summary_files = self.get_summary_files()
            for file_info in summary_files:
                self.update_file_state(file_info)
            logger.info(f"📋 기존 summary 파일 상태 기록 완료: {len(summary_files)}개 파일")
            
            # 사용자 임베딩 파일들 상태 기록
            user_files = self.get_user_embedding_files()
            for file_info in user_files:
                self.update_file_state(file_info)
            logger.info(f"📋 기존 사용자 임베딩 파일 상태 기록 완료: {len(user_files)}개 파일")
            
        except Exception as e:
            logger.error(f"초기 파일 상태 기록 오류: {str(e)}")
        
        # 정기 모니터링 시작
        while self.monitoring:
            try:
                # DB 세션 생성
                db = next(get_db())
                
                # 변경사항 확인 및 추천 업데이트
                updated_users = self.check_and_update_recommendations(db)
                
                if updated_users:
                    logger.info(f"업데이트된 사용자: {', '.join(updated_users)}")
                
                db.close()
                
            except Exception as e:
                logger.error(f"모니터링 루프 오류: {str(e)}")
            
            # 다음 체크까지 대기
            await asyncio.sleep(check_interval)
    
    def stop_monitoring(self):
        """S3 모니터링을 중지합니다."""
        self.monitoring = False
        logger.info("S3 모니터링 중지")

# 전역 인스턴스
s3_monitor = S3MonitorService() 