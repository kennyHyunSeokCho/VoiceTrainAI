#!/usr/bin/env python3
"""
Google Cloud Speech-to-Text API 테스트 스크립트
"""

import os
import sys
from pathlib import Path
from voice_to_text_google import VoiceToTextGoogle

def main():
    """Google Cloud Speech 음성인식 테스트 실행"""
    
    print("🔊 Google Cloud Speech-to-Text 테스트 시작!")
    print("=" * 60)
    
    # 환경변수 확인
    print("\n🔧 환경변수 확인:")
    
    credentials_path = os.getenv('GOOGLE_APPLICATION_CREDENTIALS')
    project_id = os.getenv('GOOGLE_CLOUD_PROJECT_ID')
    credentials_json = os.getenv('GOOGLE_CLOUD_CREDENTIALS_JSON')
    
    if credentials_path:
        print(f"✅ GOOGLE_APPLICATION_CREDENTIALS: {credentials_path}")
        if not os.path.exists(credentials_path):
            print(f"❌ 키 파일이 존재하지 않습니다: {credentials_path}")
            return False
    elif credentials_json:
        print("✅ GOOGLE_CLOUD_CREDENTIALS_JSON: 설정됨 (JSON 문자열)")
    else:
        print("⚠️  Google Cloud 인증 정보 없음 - 기본 인증 시도")
    
    if project_id:
        print(f"✅ GOOGLE_CLOUD_PROJECT_ID: {project_id}")
    else:
        print("⚠️  GOOGLE_CLOUD_PROJECT_ID 미설정")
    
    # 입력/출력 폴더 확인
    test_result_dir = Path('test_result')
    test_text_dir = Path('test_text')
    
    print(f"\n📂 폴더 확인:")
    print(f"입력 폴더: {test_result_dir} {'✅' if test_result_dir.exists() else '❌'}")
    print(f"출력 폴더: {test_text_dir} {'✅' if test_text_dir.exists() else '📁 생성 예정'}")
    
    if not test_result_dir.exists():
        print(f"❌ 입력 폴더가 없습니다: {test_result_dir}")
        print("💡 먼저 보컬 분리를 실행하여 _vocal.wav 파일들을 생성하세요.")
        return False
    
    # _vocal.wav 파일들 확인
    vocal_files = list(test_result_dir.glob('*_vocal.wav'))
    if not vocal_files:
        print(f"❌ {test_result_dir}에서 _vocal.wav 파일을 찾을 수 없습니다")
        print("💡 먼저 보컬 분리를 실행하세요: python simple_test.py")
        return False
    
    print(f"\n🎵 발견된 보컬 파일들:")
    total_size = 0
    total_duration = 0
    
    for i, vocal_file in enumerate(vocal_files, 1):
        file_size = vocal_file.stat().st_size / (1024 * 1024)  # MB
        total_size += file_size
        
        try:
            import ffmpeg
            probe = ffmpeg.probe(str(vocal_file))
            duration = float(probe['streams'][0]['duration'])
            total_duration += duration
            
            print(f"{i}. {vocal_file.name}")
            print(f"   📦 크기: {file_size:.1f}MB, ⏱️ 길이: {duration:.1f}초")
        except:
            print(f"{i}. {vocal_file.name}")
            print(f"   📦 크기: {file_size:.1f}MB")
    
    # 예상 비용 계산
    estimated_cost = (total_duration / 60) * 0.006  # $0.006/분
    
    print(f"\n💰 예상 비용:")
    print(f"총 오디오 길이: {total_duration:.1f}초 ({total_duration/60:.1f}분)")
    print(f"예상 비용: ${estimated_cost:.4f} (약 {estimated_cost * 1400:.0f}원)")
    
    # 사용자 확인
    print(f"\n처리할 파일: {len(vocal_files)}개")
    response = input("Google Cloud Speech로 음성인식을 시작할까요? (y/N): ").strip().lower()
    
    if response not in ['y', 'yes', '예', 'ㅇ']:
        print("❌ 테스트 취소됨")
        return False
    
    try:
        print("\n🚀 Google Cloud Speech 인스턴스 생성 중...")
        
        # VoiceToTextGoogle 인스턴스 생성
        vtt_google = VoiceToTextGoogle(project_id=project_id)
        
        print("✅ 인스턴스 생성 완료!")
        
        # 음성인식 처리 시작
        print("\n🎯 음성인식 처리 시작...")
        print("-" * 60)
        
        results = vtt_google.process_vocal_files(
            input_dir='test_result',
            output_dir='test_text'
        )
        
        # 결과 출력
        print("\n" + "=" * 60)
        print("🎉 Google Cloud Speech 처리 완료!")
        print("=" * 60)
        
        print(f"✅ 성공: {results['processed']}개")
        print(f"❌ 실패: {results['failed']}개")
        print(f"💰 총 비용: ${results['total_cost']:.4f} (약 {results['total_cost'] * 1400:.0f}원)")
        
        if results['files']:
            print("\n📄 파일별 상세 결과:")
            print("-" * 60)
            
            for i, file_result in enumerate(results['files'], 1):
                if file_result['status'] == 'success':
                    print(f"{i}. ✅ {file_result['input_file']}")
                    print(f"   📝 출력: {file_result['output_file']}")
                    print(f"   📄 텍스트: {file_result['text_length']}자")
                    print(f"   ⏱️  길이: {file_result['duration']:.1f}초")
                    print(f"   📦 크기: {file_result['file_size_mb']:.1f}MB")
                    print(f"   🎯 신뢰도: {file_result['confidence']:.2f}")
                    print(f"   📝 단어수: {file_result['word_count']}개")
                    print(f"   🎤 화자수: {file_result['speaker_count']}명")
                    print(f"   💰 비용: ${file_result['cost']:.4f}")
                    print()
                else:
                    print(f"{i}. ❌ {file_result['input_file']}")
                    print(f"   오류: {file_result['error']}")
                    print()
        
        # 생성된 텍스트 파일들 보기
        text_files = list(test_text_dir.glob('*_google.txt'))
        if text_files:
            print(f"📂 생성된 텍스트 파일들 ({len(text_files)}개):")
            for text_file in text_files:
                file_size = text_file.stat().st_size
                print(f"   📄 {text_file.name} ({file_size:,}바이트)")
        
        return True
        
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        print("\n🔧 해결 방법:")
        print("1. Google Cloud Console에서 Speech-to-Text API 활성화")
        print("2. Service Account 키 생성 후 환경변수 설정:")
        print("   export GOOGLE_APPLICATION_CREDENTIALS='/path/to/service-account-key.json'")
        print("   export GOOGLE_CLOUD_PROJECT_ID='your-project-id'")
        print("3. 또는 gcloud CLI 설치 후: gcloud auth login")
        print("4. 프로젝트 설정: gcloud config set project YOUR_PROJECT_ID")
        return False

def show_setup_guide():
    """Google Cloud 설정 가이드 출력"""
    
    print("\n" + "=" * 60)
    print("🔧 Google Cloud Speech-to-Text 설정 가이드")
    print("=" * 60)
    
    print("\n1️⃣ Google Cloud Console 설정:")
    print("   • https://console.cloud.google.com/ 접속")
    print("   • 프로젝트 생성 (또는 기존 프로젝트 선택)")
    print("   • 'Speech-to-Text API' 활성화")
    print("   • 결제 정보 등록 (무료 크레딧 $300 제공)")
    
    print("\n2️⃣ Service Account 키 생성:")
    print("   • IAM & Admin > Service accounts")
    print("   • 'Create Service Account' 클릭")
    print("   • 역할: 'Speech-to-Text Client' 추가")
    print("   • 키 생성 (JSON 형식) 후 다운로드")
    
    print("\n3️⃣ 환경변수 설정:")
    print("   # 방법 1: JSON 키 파일 사용")
    print("   export GOOGLE_APPLICATION_CREDENTIALS='/path/to/service-account-key.json'")
    print("   export GOOGLE_CLOUD_PROJECT_ID='your-project-id'")
    print()
    print("   # 방법 2: JSON 문자열 직접 설정")
    print("   export GOOGLE_CLOUD_CREDENTIALS_JSON='{\"type\":\"service_account\",...}'")
    print("   export GOOGLE_CLOUD_PROJECT_ID='your-project-id'")
    
    print("\n4️⃣ 대안: gcloud CLI 사용:")
    print("   • gcloud CLI 설치: https://cloud.google.com/sdk/docs/install")
    print("   • gcloud auth login")
    print("   • gcloud config set project YOUR_PROJECT_ID")
    
    print("\n💡 참고사항:")
    print("   • 첫 300달러는 무료로 사용 가능")
    print("   • Speech-to-Text 가격: $0.006/분 (약 분당 8.4원)")
    print("   • 한국어 성능이 매우 뛰어남")
    print("   • 단어별 타임스탬프, 화자 구분 지원")

if __name__ == "__main__":
    print("🔊 Google Cloud Speech-to-Text 테스트")
    
    # 명령행 인수 확인
    if len(sys.argv) > 1 and sys.argv[1] in ['--help', '-h', 'help']:
        show_setup_guide()
    elif len(sys.argv) > 1 and sys.argv[1] in ['--setup', 'setup']:
        show_setup_guide()
    else:
        # 메인 테스트 실행
        success = main()
        
        if not success:
            print("\n" + "-" * 40)
            print("💡 설정 도움이 필요하시면:")
            print("python test_google_voice_to_text.py --setup") 