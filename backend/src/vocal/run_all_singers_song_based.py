#!/usr/bin/env python3
"""
모든 가수의 곡별 임베딩 JSON 파일 생성
S3에서 모든 가수 데이터를 다운로드하여 각 곡별로 개별 JSON 파일 생성 및 업로드
"""

import os
import sys

# 상위 디렉토리를 Python 경로에 추가
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from vocal.singer_embedding_system import SingerEmbeddingSystem

def main():
    print("🎵 모든 가수 곡별 임베딩 JSON 파일 생성 시작")
    print("=" * 60)
    
    # 환경변수 설정
    os.environ['AWS_ACCESS_KEY_ID'] = 'AWS_ACCESS_KEY_ID'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'AWS_SECRET_ACCESS_KEY'
    os.environ['AWS_DEFAULT_REGION'] = 'AWS_DEFAULT_REGION'
    
    # 시스템 초기화
    embedding_system = SingerEmbeddingSystem()
    
    # 모델 로드
    print("🤖 HuBERT 모델 로딩 중...")
    if not embedding_system.load_model():
        print("❌ 모델 로딩 실패")
        return
    
    # S3 설정
    bucket_name = "ai-vocal-training"
    vocal_prefix = "vocal/"
    embedding_prefix = "timbre_embeddings/"
    local_temp_dir = "./temp_all_singers/"
    
    print(f"📦 S3 버킷: {bucket_name}")
    print(f"📁 음성 데이터 경로: {vocal_prefix}")
    print(f"💾 임베딩 저장 경로: {embedding_prefix}")
    print(f"🗂️ 로컬 임시 디렉토리: {local_temp_dir}")
    print()
    
    try:
        # 모든 가수 처리
        result = embedding_system.build_and_upload_singer_embeddings_from_s3(
            bucket_name=bucket_name,
            vocal_prefix=vocal_prefix,
            embedding_prefix=embedding_prefix,
            local_temp_dir=local_temp_dir,
            region_name="ap-northeast-2"
        )
        
        print("\n" + "=" * 60)
        print("🎉 전체 작업 완료!")
        print(f"✅ 처리 성공: {result.get('success_count', 0)}명")
        print(f"❌ 처리 실패: {result.get('error_count', 0)}명")
        print(f"📊 총 처리 시간: {result.get('total_time', 'N/A')}")
        
        if result.get('errors'):
            print("\n⚠️ 오류 발생한 가수들:")
            for singer, error in result['errors'].items():
                print(f"  - {singer}: {error}")
        
    except KeyboardInterrupt:
        print("\n⏹️ 사용자에 의해 중단됨")
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
    finally:
        # 임시 디렉토리 정리
        if os.path.exists(local_temp_dir):
            import shutil
            print(f"🧹 임시 디렉토리 정리: {local_temp_dir}")
            shutil.rmtree(local_temp_dir)

if __name__ == "__main__":
    main() 