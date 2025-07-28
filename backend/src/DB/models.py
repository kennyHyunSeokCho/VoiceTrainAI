"""
데이터베이스 모델 정의
Clerk 인증 시스템 기반 보컬 트레이닝 앱의 테이블 구조를 정의합니다.
"""

from sqlalchemy import Column, Integer, String, Text, DateTime, Boolean, Float, ForeignKey, BigInteger
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import TIMESTAMP
from .database import Base

class UsersSync(Base):
    """외부 인증에서 동기화된 사용자 정보를 담는 테이블 (기존 Firebase UID 포함)"""
    __tablename__ = "users_sync"
    
    id = Column(Text, primary_key=True)  # Clerk User ID
    name = Column(Text)
    email = Column(Text)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), onupdate=func.now())
    deleted_at = Column(TIMESTAMP(timezone=True), nullable=True)
    raw_json = Column(Text)  # 원본 JSON
    
    # 관계 설정
    user_profile = relationship("UserProfile", back_populates="user", uselist=False)
    user_privacy = relationship("UserPrivacy", back_populates="user", uselist=False)
    user_refresh_tokens = relationship("UserRefreshToken", back_populates="user")
    followings = relationship("Follow", foreign_keys="Follow.follower_id", back_populates="follower")
    followers = relationship("Follow", foreign_keys="Follow.following_id", back_populates="following")
    favorites = relationship("Favorite", back_populates="user")
    model_profiles = relationship("ModelProfile", back_populates="user")
    results = relationship("Result", back_populates="user")
    user_main_songs = relationship("UserMainSong", back_populates="user")
    score_histories = relationship("ScoreHistory", back_populates="user")
    rankings = relationship("Ranking", back_populates="user")
    ai_covers = relationship("AiCover", back_populates="user")
    recommend_songs = relationship("RecommendSongs", back_populates="user", uselist=False)

class UserProfile(Base):
    """사용자 프로필 정보"""
    __tablename__ = "user_profile"
    
    user_id = Column(Text, ForeignKey("users_sync.id"), primary_key=True)
    vocal_range = Column(String(20))
    profile_image_url = Column(String(512))
    role_type = Column(String(20), default='USER')
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # 관계 설정
    user = relationship("UsersSync", back_populates="user_profile")

class UserPrivacy(Base):
    """사용자 개인정보 설정"""
    __tablename__ = "user_privacy"
    
    setting_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Text, ForeignKey("users_sync.id"), nullable=False)
    show_recording = Column(Boolean, default=True)
    show_score = Column(Boolean, default=True)
    is_profile_public = Column(Boolean, default=True)
    
    # 관계 설정
    user = relationship("UsersSync", back_populates="user_privacy")

class UserRefreshToken(Base):
    """사용자 리프레시 토큰"""
    __tablename__ = "user_refresh_token"
    
    refresh_token_seq = Column(Integer, primary_key=True, autoincrement=True)
    refresh_token = Column(String(256), nullable=False)
    user_id = Column(Text, ForeignKey("users_sync.id"), nullable=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    
    # 관계 설정
    user = relationship("UsersSync", back_populates="user_refresh_tokens")

class Follow(Base):
    """팔로우 관계"""
    __tablename__ = "follow"
    
    follow_id = Column(Integer, primary_key=True, autoincrement=True)
    follower_id = Column(Text, ForeignKey("users_sync.id"), nullable=False)
    following_id = Column(Text, ForeignKey("users_sync.id"), nullable=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    
    # 관계 설정
    follower = relationship("UsersSync", foreign_keys=[follower_id], back_populates="followings")
    following = relationship("UsersSync", foreign_keys=[following_id], back_populates="followers")

class Song(Base):
    """노래 정보"""
    __tablename__ = "song"
    
    song_id = Column(Integer, primary_key=True, autoincrement=True)
    song_title = Column(String(255), nullable=False)
    singer = Column(String(255))
    album_cover_image = Column(String(255))
    voice_file = Column(String(255))
    ai_mr_file = Column(Text)
    lyric_text = Column(Text)
    view = Column(Integer, default=0)
    only_training = Column(Boolean, default=False)
    start_timing = Column(Integer)
    running_time = Column(Text)
    vocal_range = Column(String(20))
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    
    # 관계 설정
    song_lines = relationship("SongLine", back_populates="song")
    favorites = relationship("Favorite", back_populates="song")
    results = relationship("Result", back_populates="song")
    user_main_songs = relationship("UserMainSong", back_populates="song")
    score_histories = relationship("ScoreHistory", back_populates="song")
    rankings = relationship("Ranking", back_populates="song")
    ai_covers = relationship("AiCover", back_populates="song")

class SongLine(Base):
    """노래 가사 라인 정보"""
    __tablename__ = "song_line"
    
    song_line_id = Column(Integer, primary_key=True, autoincrement=True)
    song_id = Column(Integer, ForeignKey("song.song_id"), nullable=False)
    start_time = Column(Float)
    end_time = Column(Float)
    start_node = Column(Integer)
    end_node = Column(Integer)
    
    # 관계 설정
    song = relationship("Song", back_populates="song_lines")

class Favorite(Base):
    """즐겨찾기"""
    __tablename__ = "favorite"
    
    favorite_seq = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Text, ForeignKey("users_sync.id"), nullable=False)
    song_id = Column(Integer, ForeignKey("song.song_id"), nullable=False)
    
    # 관계 설정
    user = relationship("UsersSync", back_populates="favorites")
    song = relationship("Song", back_populates="favorites")

class ModelProfile(Base):
    """AI 모델 프로필"""
    __tablename__ = "model_profile"
    
    model_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Text, ForeignKey("users_sync.id"), nullable=False)
    model_name = Column(String(255))
    file_path = Column(Text)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    
    # 관계 설정
    user = relationship("UsersSync", back_populates="model_profiles")

class Result(Base):
    """연습 결과"""
    __tablename__ = "result"
    
    result_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Text, ForeignKey("users_sync.id"), nullable=False)
    song_id = Column(Integer, ForeignKey("song.song_id"), nullable=False)
    record_file = Column(Text)
    pitch_score = Column(Float)
    rhythm_score = Column(Float)
    emotion_score = Column(Float)
    total_score = Column(Integer)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    is_public = Column(Boolean, default=True)
    like_count = Column(Integer, default=0)
    view_count = Column(Integer, default=0)
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # 관계 설정
    user = relationship("UsersSync", back_populates="results")
    song = relationship("Song", back_populates="results")
    feedbacks = relationship("Feedback", back_populates="result")
    user_main_songs = relationship("UserMainSong", back_populates="result")
    rankings = relationship("Ranking", back_populates="result")

class Feedback(Base):
    """피드백"""
    __tablename__ = "feedback"
    
    feedback_id = Column(Integer, primary_key=True, autoincrement=True)
    result_id = Column(Integer, ForeignKey("result.result_id"), nullable=False)
    content = Column(Text)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    
    # 관계 설정
    result = relationship("Result", back_populates="feedbacks")

class UserMainSong(Base):
    """사용자 대표곡"""
    __tablename__ = "user_main_song"
    
    rep_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Text, ForeignKey("users_sync.id"), nullable=False)
    song_id = Column(Integer, ForeignKey("song.song_id"), nullable=False)
    result_id = Column(Integer, ForeignKey("result.result_id"), nullable=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    
    # 관계 설정
    user = relationship("UsersSync", back_populates="user_main_songs")
    song = relationship("Song", back_populates="user_main_songs")
    result = relationship("Result", back_populates="user_main_songs")

class ScoreHistory(Base):
    """점수 히스토리"""
    __tablename__ = "score_history"
    
    score_history_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Text, ForeignKey("users_sync.id"), nullable=False)
    song_id = Column(Integer, ForeignKey("song.song_id"), nullable=False)
    pitch_score = Column(Float)
    rhythm_score = Column(Float)
    emotion_score = Column(Float)
    total_score = Column(Integer)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    
    # 관계 설정
    user = relationship("UsersSync", back_populates="score_histories")
    song = relationship("Song", back_populates="score_histories")

class Ranking(Base):
    """랭킹"""
    __tablename__ = "ranking"
    
    ranking_id = Column(Integer, primary_key=True, autoincrement=True)
    song_id = Column(Integer, ForeignKey("song.song_id"), nullable=False)
    user_id = Column(Text, ForeignKey("users_sync.id"), nullable=False)
    result_id = Column(Integer, ForeignKey("result.result_id"), nullable=False)
    rank = Column(Integer)
    week_start = Column(Text)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    
    # 관계 설정
    song = relationship("Song", back_populates="rankings")
    user = relationship("UsersSync", back_populates="rankings")
    result = relationship("Result", back_populates="rankings")

class AiCover(Base):
    """AI 커버"""
    __tablename__ = "ai_cover"
    
    ai_cover_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Text, ForeignKey("users_sync.id"), nullable=False)
    song_id = Column(Integer, ForeignKey("song.song_id"), nullable=False)
    ai_cover_file = Column(Text)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    
    # 관계 설정
    user = relationship("UsersSync", back_populates="ai_covers")
    song = relationship("Song", back_populates="ai_covers")

class RecommendSongs(Base):
    """사용자별 추천 노래 정보"""
    __tablename__ = "recommend_songs"
    
    user_id = Column(Text, ForeignKey("users_sync.id"), primary_key=True)
    
    # 추천 노래 5개 (제목으로 저장)
    song1 = Column(String(255), nullable=True)
    song2 = Column(String(255), nullable=True)
    song3 = Column(String(255), nullable=True)
    song4 = Column(String(255), nullable=True)
    song5 = Column(String(255), nullable=True)
    
    # 추천 가수 3개
    singer1 = Column(String(255), nullable=True)
    singer2 = Column(String(255), nullable=True)
    singer3 = Column(String(255), nullable=True)
    
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # 관계 설정
    user = relationship("UsersSync", back_populates="recommend_songs") 