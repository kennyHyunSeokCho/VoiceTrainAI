"""
DB에서 현재 저장된 추천 데이터를 확인하는 스크립트
"""

import sys
import os

# 상위 디렉토리를 Python 경로에 추가
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from src.DB.database import SessionLocal
from src.DB.models import RecommendSongs, Song, UsersSync

def check_db_recommendations():
    """DB에서 현재 저장된 추천 데이터를 확인합니다."""
    try:
        db = SessionLocal()
        
        print("🔍 DB에서 추천 데이터 확인 중...")
        print("=" * 50)
        
        # 모든 추천 데이터 조회
        recommendations = db.query(RecommendSongs).all()
        
        print(f"📊 총 추천 데이터: {len(recommendations)}개")
        print()
        
        for rec in recommendations:
            print(f"👤 사용자 ID: {rec.user_id}")
            print(f"📅 업데이트 시간: {rec.updated_at}")
            
            # 추천 노래 정보
            print("🎵 추천 노래:")
            for i in range(1, 6):
                song_id = getattr(rec, f'song{i}')
                if song_id:
                    song = db.query(Song).filter(Song.song_id == song_id).first()
                    if song:
                        print(f"   song{i}: {song.song_title} (ID: {song_id})")
                    else:
                        print(f"   song{i}: ID {song_id} (DB에서 찾을 수 없음)")
                else:
                    print(f"   song{i}: 없음")
            
            # 추천 가수 정보
            print("🎤 추천 가수:")
            for i in range(1, 4):
                singer = getattr(rec, f'singer{i}')
                if singer:
                    print(f"   singer{i}: {singer}")
                else:
                    print(f"   singer{i}: 없음")
            
            print("-" * 30)
        
        # 사용자 정보도 확인
        print("\n👥 사용자 정보:")
        users = db.query(UsersSync).all()
        for user in users:
            print(f"   - ID: {user.id}, 이름: {user.name}")
        
        db.close()
        
    except Exception as e:
        print(f"❌ DB 확인 중 오류: {str(e)}")

if __name__ == "__main__":
    check_db_recommendations() 