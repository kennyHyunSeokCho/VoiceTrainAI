"""
데이터베이스 패키지
Clerk 인증 시스템 기반 보컬 트레이닝 앱의 데이터베이스 관련 모듈들을 포함합니다.
"""

from .database import Base, engine, SessionLocal, get_db, init_db, test_connection
from .models import (
    UsersSync,
    UserProfile,
    UserPrivacy,
    UserRefreshToken,
    Follow,
    Song,
    SongLine,
    Favorite,
    ModelProfile,
    Result,
    Feedback,
    UserMainSong,
    ScoreHistory,
    Ranking,
    AiCover
)

__all__ = [
    "Base",
    "engine", 
    "SessionLocal",
    "get_db",
    "init_db",
    "test_connection",
    # 사용자 관련 모델
    "UsersSync",
    "UserProfile", 
    "UserPrivacy",
    "UserRefreshToken",
    "Follow",
    # 노래 관련 모델
    "Song",
    "SongLine",
    "Favorite",
    # AI 모델 관련
    "ModelProfile",
    # 연습 결과 관련
    "Result",
    "Feedback",
    "UserMainSong",
    "ScoreHistory",
    "Ranking",
    "AiCover"
] 