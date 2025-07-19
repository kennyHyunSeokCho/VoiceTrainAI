"""
OAuth 기능 테스트 스크립트
Google, Kakao OAuth 기능을 테스트합니다.
"""

import os
import sys
import json
from dotenv import load_dotenv

# 상위 디렉토리를 Python 경로에 추가
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

# 환경 변수 로드
load_dotenv()

def create_sample_google_payload():
    """샘플 Google OAuth 페이로드를 생성합니다."""
    return {
        "sub": "user_google_123",
        "email": "test@gmail.com",
        "name": "테스트 구글 사용자",
        "first_name": "테스트",
        "last_name": "구글 사용자",
        "picture": "https://lh3.googleusercontent.com/a/test-photo",
        "email_verified": True,
        "google": {
            "id": "google_user_id_123",
            "email": "test@gmail.com",
            "verified_email": True,
            "name": "테스트 구글 사용자",
            "given_name": "테스트",
            "family_name": "구글 사용자",
            "picture": "https://lh3.googleusercontent.com/a/test-photo"
        }
    }

def create_sample_kakao_payload():
    """샘플 Kakao OAuth 페이로드를 생성합니다."""
    return {
        "sub": "user_kakao_456",
        "email": "test@kakao.com",
        "name": "테스트 카카오 사용자",
        "first_name": "테스트",
        "last_name": "카카오 사용자",
        "picture": "http://k.kakaocdn.net/14/dn/test-profile.jpg",
        "email_verified": True,
        "kakao": {
            "id": "kakao_user_id_456",
            "connected_at": "2024-01-01T00:00:00Z",
            "properties": {
                "nickname": "테스트 카카오 사용자",
                "profile_image": "http://k.kakaocdn.net/14/dn/test-profile.jpg",
                "thumbnail_image": "http://k.kakaocdn.net/14/dn/test-thumbnail.jpg"
            },
            "kakao_account": {
                "profile_needs_agreement": False,
                "profile": {
                    "nickname": "테스트 카카오 사용자",
                    "thumbnail_image_url": "http://k.kakaocdn.net/14/dn/test-thumbnail.jpg",
                    "profile_image_url": "http://k.kakaocdn.net/14/dn/test-profile.jpg"
                },
                "email_needs_agreement": False,
                "is_email_valid": True,
                "is_email_verified": True,
                "email": "test@kakao.com"
            }
        }
    }

def test_oauth_handler_import():
    """OAuth 핸들러 임포트를 테스트합니다."""
    try:
        from src.auth.oauth_handlers import OAuthHandler, oauth_handler
        print("✅ OAuth 핸들러 임포트 성공")
        return True
    except Exception as e:
        print(f"❌ OAuth 핸들러 임포트 실패: {e}")
        return False

def test_google_oauth_extraction():
    """Google OAuth 정보 추출을 테스트합니다."""
    try:
        from src.auth.oauth_handlers import OAuthHandler
        
        sample_payload = create_sample_google_payload()
        user_info = OAuthHandler.extract_google_user_info(sample_payload)
        
        print("✅ Google OAuth 정보 추출 성공")
        print(f"  - 사용자 ID: {user_info['id']}")
        print(f"  - 이메일: {user_info['email']}")
        print(f"  - 이름: {user_info['name']}")
        print(f"  - 제공자: {user_info['provider']}")
        print(f"  - 프로필 이미지: {user_info['picture']}")
        
        return True
    except Exception as e:
        print(f"❌ Google OAuth 정보 추출 실패: {e}")
        return False

def test_kakao_oauth_extraction():
    """Kakao OAuth 정보 추출을 테스트합니다."""
    try:
        from src.auth.oauth_handlers import OAuthHandler
        
        sample_payload = create_sample_kakao_payload()
        user_info = OAuthHandler.extract_kakao_user_info(sample_payload)
        
        print("✅ Kakao OAuth 정보 추출 성공")
        print(f"  - 사용자 ID: {user_info['id']}")
        print(f"  - 이메일: {user_info['email']}")
        print(f"  - 이름: {user_info['name']}")
        print(f"  - 제공자: {user_info['provider']}")
        print(f"  - 프로필 이미지: {user_info['picture']}")
        
        return True
    except Exception as e:
        print(f"❌ Kakao OAuth 정보 추출 실패: {e}")
        return False

def test_oauth_provider_detection():
    """OAuth 제공자 자동 감지를 테스트합니다."""
    try:
        from src.auth.oauth_handlers import OAuthHandler
        
        # Google OAuth 테스트
        google_payload = create_sample_google_payload()
        google_user_info = OAuthHandler.extract_oauth_user_info(google_payload)
        print(f"✅ Google 제공자 감지: {google_user_info['provider']}")
        
        # Kakao OAuth 테스트
        kakao_payload = create_sample_kakao_payload()
        kakao_user_info = OAuthHandler.extract_oauth_user_info(kakao_payload)
        print(f"✅ Kakao 제공자 감지: {kakao_user_info['provider']}")
        
        # 기본 이메일 로그인 테스트
        email_payload = {
            "sub": "user_email_789",
            "email": "test@example.com",
            "name": "테스트 이메일 사용자"
        }
        email_user_info = OAuthHandler.extract_oauth_user_info(email_payload)
        print(f"✅ 이메일 제공자 감지: {email_user_info['provider']}")
        
        return True
    except Exception as e:
        print(f"❌ OAuth 제공자 감지 실패: {e}")
        return False

def test_oauth_database_sync():
    """OAuth 사용자 데이터베이스 동기화를 테스트합니다."""
    try:
        from src.DB.database import get_db
        from src.auth.oauth_handlers import OAuthHandler
        
        # 환경변수가 설정되지 않은 경우 스킵
        if not os.getenv("CLERK_SECRET_KEY"):
            print("⚠️  Clerk 환경변수가 설정되지 않아 데이터베이스 동기화 테스트를 스킵합니다.")
            return True
        
        db = next(get_db())
        
        # Google OAuth 사용자 동기화 테스트
        google_payload = create_sample_google_payload()
        google_user_info = OAuthHandler.extract_google_user_info(google_payload)
        synced_user = OAuthHandler.sync_oauth_user_to_database(google_user_info, db)
        print(f"✅ Google OAuth 사용자 동기화 성공: {synced_user.id}")
        
        # 프로필 확인
        from src.DB.models import UserProfile
        profile = db.query(UserProfile).filter(UserProfile.user_id == synced_user.id).first()
        if profile and profile.profile_image_url:
            print(f"✅ OAuth 프로필 이미지 저장 확인: {profile.profile_image_url}")
        
        return True
        
    except Exception as e:
        print(f"❌ OAuth 데이터베이스 동기화 실패: {e}")
        return False

def test_fastapi_oauth_dependencies():
    """FastAPI OAuth 의존성을 테스트합니다."""
    try:
        from src.auth.dependencies import get_current_user, get_optional_user
        
        print("✅ FastAPI OAuth 의존성 임포트 성공")
        return True
    except Exception as e:
        print(f"❌ FastAPI OAuth 의존성 임포트 실패: {e}")
        return False

if __name__ == "__main__":
    print("🚀 OAuth 기능 테스트 시작...")
    
    tests = [
        ("OAuth 핸들러 임포트 테스트", test_oauth_handler_import),
        ("Google OAuth 정보 추출 테스트", test_google_oauth_extraction),
        ("Kakao OAuth 정보 추출 테스트", test_kakao_oauth_extraction),
        ("OAuth 제공자 감지 테스트", test_oauth_provider_detection),
        ("FastAPI OAuth 의존성 테스트", test_fastapi_oauth_dependencies),
        ("OAuth 데이터베이스 동기화 테스트", test_oauth_database_sync)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n📋 {test_name}...")
        if test_func():
            passed += 1
        else:
            print(f"❌ {test_name} 실패")
    
    print(f"\n📊 테스트 결과: {passed}/{total} 통과")
    
    if passed == total:
        print("🎉 모든 OAuth 테스트가 성공적으로 완료되었습니다!")
        print("\n📝 OAuth 설정 가이드:")
        print("1. Clerk 대시보드에서 Social Connections 설정")
        print("2. Google OAuth: Google Cloud Console에서 클라이언트 ID/시크릿 생성")
        print("3. Kakao OAuth: Kakao Developers에서 애플리케이션 생성")
        print("4. 각 제공자의 Redirect URI를 Clerk 설정에 추가")
    else:
        print("⚠️  일부 OAuth 테스트가 실패했습니다. 설정을 확인해주세요.") 