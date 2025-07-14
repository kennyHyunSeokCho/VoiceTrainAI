import boto3
import os
from pathlib import Path
import logging
from typing import Optional, List, Dict
import sys
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

logger = logging.getLogger(__name__)

def get_s3_client(aws_access_key_id: str, aws_secret_access_key: str, bucket_name: str, region_name: str = 'ap-northeast-2'):
    try:
        client = boto3.client(
            's3',
            aws_access_key_id=aws_access_key_id,
            aws_secret_access_key=aws_secret_access_key,
            region_name=region_name
        )
        logger.info(f"S3 클라이언트 초기화 완료 - 버킷: {bucket_name}")
        return client
    except Exception as e:
        logger.warning(f"S3 클라이언트 초기화 실패: {e}")
        return None

def get_s3_client_from_env(bucket_name: str, region_name: str = 'ap-northeast-2'):
    """환경변수에서 AWS 자격증명을 읽어와서 S3 클라이언트 생성"""
    try:
        # 환경변수에서 AWS 자격증명 읽기
        aws_access_key_id = os.getenv('AWS_ACCESS_KEY_ID')
        aws_secret_access_key = os.getenv('AWS_SECRET_ACCESS_KEY')
        
        if not aws_access_key_id or not aws_secret_access_key:
            logger.error("환경변수에 AWS 자격증명이 설정되지 않았습니다.")
            logger.info("다음 환경변수를 설정하세요:")
            logger.info("  export AWS_ACCESS_KEY_ID=your_access_key")
            logger.info("  export AWS_SECRET_ACCESS_KEY=your_secret_key")
            return None
        
        client = boto3.client(
            's3',
            aws_access_key_id=aws_access_key_id,
            aws_secret_access_key=aws_secret_access_key,
            region_name=region_name
        )
        logger.info(f"✓ S3 클라이언트 초기화 완료 (환경변수 사용) - 버킷: {bucket_name}")
        return client
        
    except Exception as e:
        logger.error(f"S3 클라이언트 초기화 실패: {e}")
        return None

def download_from_s3(s3_client, bucket_name: str, s3_key: str, local_path: Optional[str] = None) -> Optional[str]:
    import tempfile
    try:
        if local_path is None:
            temp_dir = tempfile.mkdtemp()
            file_name = Path(s3_key).name
            local_path = os.path.join(temp_dir, file_name)
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        s3_client.download_file(bucket_name, s3_key, local_path)
        return local_path
    except Exception as e:
        logger.error(f"S3 다운로드 실패: {str(e)}")
        return None

def list_s3_files(s3_client, bucket_name: str, prefix: str = "") -> List[Dict]:
    try:
        response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=prefix)
        files = []
        if 'Contents' in response:
            for obj in response['Contents']:
                files.append({
                    'key': obj['Key'],
                    'size': obj['Size'],
                    'last_modified': obj['LastModified'],
                    'url': f"https://{bucket_name}.s3.{s3_client.meta.region_name}.amazonaws.com/{obj['Key']}"
                })
        return files
    except Exception as e:
        logger.error(f"S3 파일 목록 조회 실패: {str(e)}")
        return []

def get_latest_user_vocal_s3_key(s3_client, bucket_name: str, user_id: str, audio_prefix: str = "audio/") -> Optional[str]:
    try:
        user_audio_prefix = f"{audio_prefix}{user_id}/"
        response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=user_audio_prefix)
        if 'Contents' not in response:
            return None
        audio_extensions = ['.wav', '.mp3', '.flac', '.m4a', '.aac', '.ogg']
        audio_files = [
            {
                'key': obj['Key'],
                'last_modified': obj['LastModified'],
                'size': obj['Size']
            }
            for obj in response['Contents']
            if any(obj['Key'].lower().endswith(ext) for ext in audio_extensions)
        ]
        if not audio_files:
            return None
        latest_file = max(audio_files, key=lambda x: x['last_modified'])
        return latest_file['key']
    except Exception as e:
        logger.error(f"최신 vocal 파일 검색 실패: {str(e)}")
        return None 

def download_s3_folder(s3_client, bucket_name: str, prefix: str, local_dir: str) -> bool:
    """S3 폴더 전체를 로컬 디렉토리로 다운로드"""
    try:
        os.makedirs(local_dir, exist_ok=True)
        
        paginator = s3_client.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=bucket_name, Prefix=prefix)
        
        download_count = 0
        for page in pages:
            if 'Contents' not in page:
                continue
                
            for obj in page['Contents']:
                key = obj['Key']
                
                # 폴더(끝이 /인 것) 건너뛰기
                if key.endswith('/'):
                    continue
                
                # 로컬 파일 경로 생성
                relative_path = os.path.relpath(key, prefix)
                local_file_path = os.path.join(local_dir, relative_path)
                
                # 로컬 디렉토리 생성
                os.makedirs(os.path.dirname(local_file_path), exist_ok=True)
                
                # 파일 다운로드
                s3_client.download_file(bucket_name, key, local_file_path)
                download_count += 1
                logger.info(f"다운로드 완료: {key} → {local_file_path}")
        
        logger.info(f"✓ S3 폴더 다운로드 완료: {download_count}개 파일")
        return True
        
    except Exception as e:
        logger.error(f"S3 폴더 다운로드 실패: {e}")
        return False

def upload_file_to_s3(s3_client, local_file_path: str, bucket_name: str, s3_key: str) -> bool:
    """로컬 파일을 S3에 업로드"""
    try:
        s3_client.upload_file(local_file_path, bucket_name, s3_key)
        logger.info(f"✓ S3 업로드 완료: {local_file_path} → s3://{bucket_name}/{s3_key}")
        return True
    except Exception as e:
        logger.error(f"S3 업로드 실패: {e}")
        return False

def get_singer_list_from_s3(s3_client, bucket_name: str, vocal_prefix: str = "vocal/") -> List[str]:
    """S3의 vocal 폴더에서 가수 목록 조회"""
    try:
        response = s3_client.list_objects_v2(
            Bucket=bucket_name, 
            Prefix=vocal_prefix, 
            Delimiter='/'
        )
        
        singers = []
        if 'CommonPrefixes' in response:
            for prefix in response['CommonPrefixes']:
                singer_folder = prefix['Prefix']
                singer_name = singer_folder.replace(vocal_prefix, '').rstrip('/')
                if singer_name:  # 빈 문자열 제외
                    singers.append(singer_name)
        
        logger.info(f"✓ 발견된 가수: {len(singers)}명 - {singers}")
        return singers
        
    except Exception as e:
        logger.error(f"가수 목록 조회 실패: {e}")
        return [] 