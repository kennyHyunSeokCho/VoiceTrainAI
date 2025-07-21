"""
OAuth 제공자별 사용자 정보 처리 모듈
Google, Kakao 등 OAuth 제공자에서 받은 정보를 처리합니다.
"""

import json
from typing import Dict, Any, Optional
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from .clerk_auth import clerk_auth
from ..DB.models import UsersSync, UserProfile

class OAuthHandler:
    """OAuth 제공자별 사용자 정보 처리 클래스"""
    
    @staticmethod
    def extract_google_user_info(payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Google OAuth에서 받은 사용자 정보를 추출합니다.
        
        Args:
            payload: Clerk JWT 토큰 페이로드
            
        Returns:
            정제된 사용자 정보
        """
        # Google OAuth 정보 추출
        google_data = payload.get("google", {})
        
        user_info = {
            "id": payload.get("sub"),  # Clerk User ID
            "email": payload.get("email"),
            "name": payload.get("name"),
            "first_name": payload.get("first_name"),
            "last_name": payload.get("last_name"),
            "picture": payload.get("picture"),  # 프로필 이미지 URL
            "email_verified": payload.get("email_verified", False),
            "provider": "google",
            "provider_user_id": google_data.get("id"),
            "raw_json": json.dumps(payload)
        }
        
        return user_info
    
    @staticmethod
    def extract_kakao_user_info(payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Kakao OAuth에서 받은 사용자 정보를 추출합니다.
        
        Args:
            payload: Clerk JWT 토큰 페이로드
            
        Returns:
            정제된 사용자 정보
        """
        # Kakao OAuth 정보 추출
        kakao_data = payload.get("kakao", {})
        
        user_info = {
            "id": payload.get("sub"),  # Clerk User ID
            "email": payload.get("email"),
            "name": payload.get("name"),
            "first_name": payload.get("first_name"),
            "last_name": payload.get("last_name"),
            "picture": payload.get("picture"),  # 프로필 이미지 URL
            "email_verified": payload.get("email_verified", False),
            "provider": "kakao",
            "provider_user_id": kakao_data.get("id"),
            "raw_json": json.dumps(payload)
        }
        
        return user_info
    
    @staticmethod
    def extract_oauth_user_info(payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        OAuth 제공자 정보를 자동으로 감지하여 사용자 정보를 추출합니다.
        
        Args:
            payload: Clerk JWT 토큰 페이로드
            
        Returns:
            정제된 사용자 정보
        """
        # OAuth 제공자 감지
        if "google" in payload:
            return OAuthHandler.extract_google_user_info(payload)
        elif "kakao" in payload:
            return OAuthHandler.extract_kakao_user_info(payload)
        else:
            # 기본 사용자 정보 (이메일/비밀번호 로그인 등)
            return {
                "id": payload.get("sub"),
                "email": payload.get("email"),
                "name": payload.get("name"),
                "first_name": payload.get("first_name"),
                "last_name": payload.get("last_name"),
                "picture": payload.get("picture"),
                "email_verified": payload.get("email_verified", False),
                "provider": "email",
                "provider_user_id": None,
                "raw_json": json.dumps(payload)
            }
    
    @staticmethod
    def sync_oauth_user_to_database(user_info: Dict[str, Any], db: Session) -> UsersSync:
        """
        OAuth 사용자 정보를 데이터베이스에 동기화합니다.
        
        Args:
            user_info: OAuth에서 추출한 사용자 정보
            db: 데이터베이스 세션
            
        Returns:
            동기화된 사용자 객체
        """
        # 기존 사용자 확인
        existing_user = db.query(UsersSync).filter(UsersSync.id == user_info["id"]).first()
        
        if existing_user:
            # 기존 사용자 정보 업데이트
            existing_user.email = user_info.get("email")
            existing_user.name = user_info.get("name")
            existing_user.raw_json = user_info.get("raw_json")
            existing_user.updated_at = datetime.now(timezone.utc)
            db.commit()
            return existing_user
        else:
            # 새 사용자 생성
            new_user = UsersSync(
                id=user_info["id"],
                email=user_info.get("email"),
                name=user_info.get("name"),
                raw_json=user_info.get("raw_json"),
                created_at=datetime.now(timezone.utc),
                updated_at=datetime.now(timezone.utc)
            )
            db.add(new_user)
            db.commit()
            db.refresh(new_user)
            
            # OAuth 제공자별 기본 프로필 생성
            OAuthHandler._create_oauth_profile(new_user.id, user_info, db)
            
            return new_user
    
    @staticmethod
    def _create_oauth_profile(user_id: str, user_info: Dict[str, Any], db: Session):
        """
        OAuth 사용자의 기본 프로필을 생성합니다.
        
        Args:
            user_id: 사용자 ID
            user_info: OAuth 사용자 정보
            db: 데이터베이스 세션
        """
        # 기본 프로필 생성
        profile = UserProfile(
            user_id=user_id,
            role_type="USER",
            profile_image_url=user_info.get("picture"),  # OAuth 프로필 이미지
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
        )
        db.add(profile)
        db.commit()

# OAuth 핸들러 인스턴스
oauth_handler = OAuthHandler() 