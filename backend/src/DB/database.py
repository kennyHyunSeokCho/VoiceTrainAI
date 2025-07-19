"""
데이터베이스 연결 및 설정 모듈
Railway PostgreSQL 데이터베이스 연결을 관리합니다.
"""

import os
from sqlalchemy import create_engine, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# 환경 변수 로드
load_dotenv()

def get_database_url():
    """
    데이터베이스 URL을 생성하거나 환경변수에서 가져옵니다.
    환경변수로 개별 설정이 있으면 조합하고, 없으면 DATABASE_URL을 사용합니다.
    """
    # 직접 DATABASE_URL이 설정되어 있으면 사용
    database_url = os.getenv("DATABASE_URL")
    
    if database_url:
        return database_url
    
    # 개별 환경변수로 설정된 경우 조합
    db_host = os.getenv("DB_HOST")
    db_port = os.getenv("DB_PORT")
    db_name = os.getenv("DB_NAME")
    db_user = os.getenv("DB_USER")
    db_password = os.getenv("DB_PASSWORD")
    
    if all([db_host, db_port, db_name, db_user, db_password]):
        return f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"
    
    raise ValueError("데이터베이스 연결 정보가 설정되지 않았습니다. DATABASE_URL 또는 개별 DB_* 환경변수를 설정해주세요.")

# 데이터베이스 URL 가져오기
DATABASE_URL = get_database_url()

# 동기식 psycopg2 사용 (asyncpg 대신)
if DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg2://", 1)

# SQLAlchemy 엔진 생성
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,  # 연결 상태 확인
    pool_recycle=300,    # 5분마다 연결 재생성
    echo=False,          # SQL 쿼리 로그 출력 (개발시 True로 설정 가능)
    pool_size=10,        # 연결 풀 크기
    max_overflow=20      # 최대 오버플로우 연결 수
)

# 세션 팩토리 생성
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 베이스 클래스 생성 (모델 클래스들이 상속받을 클래스)
Base = declarative_base()

def get_db():
    """
    데이터베이스 세션을 제공하는 의존성 함수
    FastAPI에서 사용됩니다.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def init_db():
    """
    데이터베이스 초기화 함수
    모든 테이블을 생성합니다.
    """
    Base.metadata.create_all(bind=engine)

def test_connection():
    """
    데이터베이스 연결을 테스트합니다.
    """
    try:
        with engine.connect() as connection:
            result = connection.execute(text("SELECT version();"))
            version = result.fetchone()[0]
            print(f"✅ 데이터베이스 연결 성공!")
            print(f"📊 PostgreSQL 버전: {version}")
            return True
    except Exception as e:
        print(f"❌ 데이터베이스 연결 실패: {str(e)}")
        return False 