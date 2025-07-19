"""
Clerk 인증 시스템 모듈
JWT 토큰 검증 및 사용자 정보 동기화를 처리합니다.
"""

import os
import json
import jwt
import requests
from typing import Optional, Dict, Any
from datetime import datetime, timezone
from dotenv import load_dotenv
from sqlalchemy.orm import Session
from ..DB.database import get_db
from ..DB.models import UsersSync, UserProfile, UserPrivacy

# 환경 변수 로드
load_dotenv()

class ClerkAuth:
    """Clerk 인증 시스템 클래스"""
    
    def __init__(self, skip_config_check: bool = False):
        self.secret_key = os.getenv("CLERK_SECRET_KEY")
        self.publishable_key = os.getenv("CLERK_PUBLISHABLE_KEY")
        self.jwt_issuer = os.getenv("CLERK_JWT_ISSUER")
        self.jwt_audience = os.getenv("CLERK_JWT_AUDIENCE")
        
        # 테스트 모드에서는 환경변수 검증을 건너뜀
        if not skip_config_check and not all([self.secret_key, self.publishable_key, self.jwt_issuer]):
            raise ValueError("Clerk 환경변수가 설정되지 않았습니다.")
    
    def verify_jwt_token(self, token: str) -> Optional[Dict[str, Any]]:
        """
        JWT 토큰을 검증하고 페이로드를 반환합니다.
        
        Args:
            token: 검증할 JWT 토큰
            
        Returns:
            토큰 페이로드 또는 None (검증 실패시)
        """
        if not self.secret_key:
            print("⚠️  Clerk 환경변수가 설정되지 않아 토큰 검증을 건너뜁니다.")
            return None
            
        try:
            # JWT 토큰 검증
            payload = jwt.decode(
                token,
                self.secret_key,
                algorithms=["RS256"],
                audience=self.jwt_audience,
                issuer=self.jwt_issuer
            )
            return payload
        except jwt.InvalidTokenError as e:
            print(f"JWT 토큰 검증 실패: {e}")
            return None
        except Exception as e:
            print(f"토큰 검증 중 오류 발생: {e}")
            return None
    
    def get_user_from_token(self, token: str) -> Optional[Dict[str, Any]]:
        """
        토큰에서 사용자 정보를 추출합니다.
        
        Args:
            token: JWT 토큰
            
        Returns:
            사용자 정보 또는 None
        """
        payload = self.verify_jwt_token(token)
        if not payload:
            return None
        
        # Clerk 토큰에서 사용자 정보 추출
        user_data = {
            "id": payload.get("sub"),  # Clerk User ID
            "email": payload.get("email"),
            "name": payload.get("name"),
            "raw_json": json.dumps(payload)
        }
        
        return user_data
    
    def sync_user_to_database(self, user_data: Dict[str, Any], db: Session) -> UsersSync:
        """
        Clerk 사용자 정보를 데이터베이스에 동기화합니다.
        
        Args:
            user_data: Clerk에서 받은 사용자 정보
            db: 데이터베이스 세션
            
        Returns:
            동기화된 사용자 객체
        """
        # 기존 사용자 확인
        existing_user = db.query(UsersSync).filter(UsersSync.id == user_data["id"]).first()
        
        if existing_user:
            # 기존 사용자 정보 업데이트
            existing_user.email = user_data.get("email")
            existing_user.name = user_data.get("name")
            existing_user.raw_json = user_data.get("raw_json")
            existing_user.updated_at = datetime.now(timezone.utc)
            db.commit()
            return existing_user
        else:
            # 새 사용자 생성
            new_user = UsersSync(
                id=user_data["id"],
                email=user_data.get("email"),
                name=user_data.get("name"),
                raw_json=user_data.get("raw_json"),
                created_at=datetime.now(timezone.utc),
                updated_at=datetime.now(timezone.utc)
            )
            db.add(new_user)
            db.commit()
            db.refresh(new_user)
            
            # 기본 프로필 생성
            self._create_default_profile(new_user.id, db)
            
            return new_user
    
    def _create_default_profile(self, user_id: str, db: Session):
        """
        사용자의 기본 프로필을 생성합니다.
        
        Args:
            user_id: 사용자 ID
            db: 데이터베이스 세션
        """
        # 기본 프로필 생성
        profile = UserProfile(
            user_id=user_id,
            role_type="USER",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
        )
        db.add(profile)
        
        # 기본 개인정보 설정 생성
        privacy = UserPrivacy(
            user_id=user_id,
            show_recording=True,
            show_score=True,
            is_profile_public=True
        )
        db.add(privacy)
        
        db.commit()
    
    def get_user_by_id(self, user_id: str, db: Session) -> Optional[UsersSync]:
        """
        사용자 ID로 사용자 정보를 조회합니다.
        
        Args:
            user_id: 사용자 ID
            db: 데이터베이스 세션
            
        Returns:
            사용자 객체 또는 None
        """
        return db.query(UsersSync).filter(UsersSync.id == user_id).first()
    
    def get_user_profile(self, user_id: str, db: Session) -> Optional[UserProfile]:
        """
        사용자 프로필을 조회합니다.
        
        Args:
            user_id: 사용자 ID
            db: 데이터베이스 세션
            
        Returns:
            사용자 프로필 객체 또는 None
        """
        return db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    
    def update_user_profile(self, user_id: str, profile_data: Dict[str, Any], db: Session) -> Optional[UserProfile]:
        """
        사용자 프로필을 업데이트합니다.
        
        Args:
            user_id: 사용자 ID
            profile_data: 업데이트할 프로필 데이터
            db: 데이터베이스 세션
            
        Returns:
            업데이트된 프로필 객체 또는 None
        """
        profile = self.get_user_profile(user_id, db)
        if not profile:
            return None
        
        # 프로필 업데이트
        for key, value in profile_data.items():
            if hasattr(profile, key):
                setattr(profile, key, value)
        
        profile.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(profile)
        
        return profile

    def get_current_user(self, token: str = None, db: Session = None):
        """
        FastAPI 의존성으로 사용할 현재 사용자 조회 메서드
        
        Args:
            token: JWT 토큰 (헤더에서 추출됨)
            db: 데이터베이스 세션
            
        Returns:
            현재 사용자 정보 또는 None
        """
        # 테스트 모드에서는 더미 사용자 반환
        if not self.secret_key:
            return {
                "id": "test_user_123",
                "email": "test@example.com",
                "name": "테스트 사용자",
                "provider": "email"
            }
        
        # 실제 토큰 검증
        if token:
            user_data = self.get_user_from_token(token)
            if user_data and db:
                return self.sync_user_to_database(user_data, db)
            return user_data
        
        return None

# 전역 Clerk 인증 인스턴스 (테스트 모드)
try:
    clerk_auth = ClerkAuth()
except ValueError:
    # 환경변수가 설정되지 않은 경우 테스트 모드로 생성
    clerk_auth = ClerkAuth(skip_config_check=True) 