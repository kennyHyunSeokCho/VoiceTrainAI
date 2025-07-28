"""
수동 추천 시스템 테스트 스크립트
"""

import sys
import os

# 상위 디렉토리를 Python 경로에 추가
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from src.vocal.trimbre_based_recommend import main as get_timbre_recommendations

def test_recommendation():
    """추천 시스템을 수동으로 테스트합니다."""
    try:
        print("🚀 수동 추천 시스템 테스트 시작...")
        print("=" * 50)
        
        # 테스트할 사용자 ID들
        test_users = [
            "kakao_4358748397",
            "117320568783074641756"  # 새로 발견된 사용자
        ]
        
        for user_id in test_users:
            print(f"\n👤 사용자 {user_id} 테스트 중...")
            
            try:
                # 추천 실행
                result = get_timbre_recommendations(user_id)
                
                print(f"✅ 추천 성공!")
                print(f"   추천 노래: {result['songs']}")
                print(f"   추천 가수: {result['singers']}")
                
            except Exception as e:
                print(f"❌ 추천 실패: {str(e)}")
        
        print("\n🎉 수동 테스트 완료!")
        
    except Exception as e:
        print(f"❌ 전체 테스트 실패: {str(e)}")

if __name__ == "__main__":
    test_recommendation() 