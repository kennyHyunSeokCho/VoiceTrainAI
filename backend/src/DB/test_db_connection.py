"""
데이터베이스 연결 테스트 스크립트
Railway PostgreSQL 데이터베이스 연결을 확인합니다.
"""

import os
import sys
from dotenv import load_dotenv

# 상위 디렉토리를 Python 경로에 추가
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

# 환경 변수 로드
load_dotenv()

def test_database_connection():
    """데이터베이스 연결을 테스트합니다."""
    try:
        from src.DB.database import test_connection, DATABASE_URL
        
        print(f"🔗 데이터베이스 URL: {DATABASE_URL}")
        
        # 연결 테스트
        success = test_connection()
        
        if success:
            # 추가 정보 출력
            from sqlalchemy import text
            from src.DB.database import engine
            
            with engine.connect() as connection:
                # 현재 데이터베이스 정보 확인
                result = connection.execute(text("SELECT current_database(), current_user;"))
                db_info = result.fetchone()
                print(f"🗄️  현재 데이터베이스: {db_info[0]}")
                print(f"👤 현재 사용자: {db_info[1]}")
                
                # 테이블 목록 확인
                result = connection.execute(text("""
                    SELECT table_name 
                    FROM information_schema.tables 
                    WHERE table_schema = 'public'
                    ORDER BY table_name;
                """))
                tables = [row[0] for row in result.fetchall()]
                print(f"📋 현재 테이블 목록: {tables if tables else '테이블이 없습니다'}")
        
        return success
            
    except Exception as e:
        print(f"❌ 데이터베이스 연결 실패: {str(e)}")
        return False

def test_models():
    """모델 정의를 테스트합니다."""
    try:
        from src.DB.models import (
            UsersSync, UserProfile, UserPrivacy, UserRefreshToken, Follow,
            Song, SongLine, Favorite, ModelProfile, Result, Feedback,
            UserMainSong, ScoreHistory, Ranking, AiCover
        )
        print("✅ 모든 모델이 성공적으로 로드되었습니다.")
        print(f"📊 총 {len([UsersSync, UserProfile, UserPrivacy, UserRefreshToken, Follow, Song, SongLine, Favorite, ModelProfile, Result, Feedback, UserMainSong, ScoreHistory, Ranking, AiCover])}개의 모델이 정의되었습니다.")
        return True
    except Exception as e:
        print(f"❌ 모델 로드 실패: {str(e)}")
        return False

def test_table_creation():
    """테이블 생성 테스트를 수행합니다."""
    try:
        from src.DB.database import init_db
        print("🔨 테이블 생성 중...")
        init_db()
        print("✅ 모든 테이블이 성공적으로 생성되었습니다.")
        return True
    except Exception as e:
        print(f"❌ 테이블 생성 실패: {str(e)}")
        return False

if __name__ == "__main__":
    print("🚀 Railway PostgreSQL 데이터베이스 연결 테스트 시작...")
    
    # 모델 테스트
    print("\n📋 모델 테스트...")
    model_success = test_models()
    
    # 연결 테스트
    print("\n🔗 연결 테스트...")
    connection_success = test_database_connection()
    
    # 테이블 생성 테스트 (선택사항)
    if connection_success and model_success:
        print("\n🔨 테이블 생성 테스트...")
        table_success = test_table_creation()
        
        if table_success:
            print("\n🎉 모든 테스트가 성공적으로 완료되었습니다!")
        else:
            print("\n⚠️  테이블 생성에 실패했습니다.")
    else:
        print("\n💥 기본 테스트에 실패했습니다. 설정을 확인해주세요.") 