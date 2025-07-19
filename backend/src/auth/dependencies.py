"""
FastAPI 인증 의존성 모듈
Clerk 인증을 위한 FastAPI 의존성 함수들을 정의합니다.
"""

from typing import Optional
from fastapi import Depends, HTTPException, status, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from .clerk_auth import clerk_auth
from .oauth_handlers import oauth_handler
from ..DB.database import get_db
from ..DB.models import UsersSync

# HTTP Bearer 토큰 스키마
security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> UsersSync:
    """
    현재 인증된 사용자를 가져오는 의존성 함수 (OAuth 지원)
    
    Args:
        credentials: HTTP Bearer 토큰
        db: 데이터베이스 세션
        
    Returns:
        인증된 사용자 객체
        
    Raises:
        HTTPException: 인증 실패시
    """
    try:
        # 토큰에서 사용자 정보 추출
        user_data = clerk_auth.get_user_from_token(credentials.credentials)
        if not user_data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="유효하지 않은 토큰입니다.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        # OAuth 정보 처리
        payload = clerk_auth.verify_jwt_token(credentials.credentials)
        if payload:
            # OAuth 제공자별 사용자 정보 추출
            oauth_user_info = oauth_handler.extract_oauth_user_info(payload)
            # 데이터베이스에 OAuth 사용자 동기화
            user = oauth_handler.sync_oauth_user_to_database(oauth_user_info, db)
        else:
            # 기본 사용자 동기화 (OAuth가 아닌 경우)
            user = clerk_auth.sync_user_to_database(user_data, db)
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="사용자 정보를 찾을 수 없습니다.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        return user
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"인증 중 오류가 발생했습니다: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

async def get_optional_user(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
) -> Optional[UsersSync]:
    """
    선택적 사용자 인증 의존성 함수 (OAuth 지원, 토큰이 없어도 OK)
    
    Args:
        authorization: Authorization 헤더
        db: 데이터베이스 세션
        
    Returns:
        인증된 사용자 객체 또는 None
    """
    if not authorization or not authorization.startswith("Bearer "):
        return None
    
    try:
        token = authorization.replace("Bearer ", "")
        user_data = clerk_auth.get_user_from_token(token)
        if not user_data:
            return None
        
        # OAuth 정보 처리
        payload = clerk_auth.verify_jwt_token(token)
        if payload:
            # OAuth 제공자별 사용자 정보 추출
            oauth_user_info = oauth_handler.extract_oauth_user_info(payload)
            # 데이터베이스에 OAuth 사용자 동기화
            user = oauth_handler.sync_oauth_user_to_database(oauth_user_info, db)
        else:
            # 기본 사용자 동기화 (OAuth가 아닌 경우)
            user = clerk_auth.sync_user_to_database(user_data, db)
        
        return user
        
    except Exception:
        return None

def require_user_role(required_role: str):
    """
    특정 역할이 필요한 사용자만 접근 가능하도록 하는 의존성
    
    Args:
        required_role: 필요한 역할
        
    Returns:
        역할 검증 함수
    """
    async def verify_user_role(
        current_user: UsersSync = Depends(get_current_user),
        db: Session = Depends(get_db)
    ) -> UsersSync:
        """
        사용자 역할을 검증합니다.
        
        Args:
            current_user: 현재 사용자
            db: 데이터베이스 세션
            
        Returns:
            검증된 사용자 객체
            
        Raises:
            HTTPException: 역할이 부족한 경우
        """
        from ..DB.models import UserProfile
        
        profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        if not profile or profile.role_type != required_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"{required_role} 역할이 필요합니다."
            )
        
        return current_user
    
    return verify_user_role

# 역할별 의존성 함수들
require_admin = require_user_role("ADMIN")
require_moderator = require_user_role("MODERATOR")
require_user = require_user_role("USER") 