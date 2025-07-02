#!/usr/bin/env python3
"""
음성인식 테스트 스크립트
test_result의 _vocal.wav 파일들을 텍스트로 변환 (OpenAI API 사용)
"""

import os
import sys
from voice_to_text import VoiceToText

def main():
    """메인 테스트 함수"""
    print("=" * 60)
    print("🎤 음성인식 테스트 시작 (OpenAI API)")
    print("=" * 60)
    
    # 디렉토리 확인
    input_dir = "test_result"
    output_dir = "test_text"
    
    if not os.path.exists(input_dir):
        print(f"❌ 입력 디렉토리가 없습니다: {input_dir}")
        return
    
    # _vocal.wav 파일 개수 확인
    vocal_files = [f for f in os.listdir(input_dir) if f.endswith('_vocal.wav')]
    
    if not vocal_files:
        print(f"❌ {input_dir}에서 _vocal.wav 파일을 찾을 수 없습니다")
        return
    
    print(f"📁 입력 디렉토리: {input_dir}")
    print(f"📁 출력 디렉토리: {output_dir}")
    print(f"🎵 처리할 보컬 파일: {len(vocal_files)}개")
    print()
    
    # 파일 정보 표시
    for i, filename in enumerate(vocal_files, 1):
        file_path = os.path.join(input_dir, filename)
        file_size = os.path.getsize(file_path) / (1024 * 1024)  # MB
        print(f"  {i}. {filename} ({file_size:.1f}MB)")
    
    print()
    
    # OpenAI API 제한 안내
    print("📌 OpenAI API 정보:")
    print("   • 모델: whisper-1 (최신 버전)")
    print("   • 파일 제한: 25MB")
    print("   • 비용: $0.006/분")
    print("   • 예상 비용: 약 $0.02-0.05 (총 3개 파일)")
    print()
    
    # 사용자 확인
    response = input("음성인식을 시작하시겠습니까? (y/N): ").strip().lower()
    if response not in ['y', 'yes', 'ㅇ']:
        print("취소되었습니다.")
        return
    
    try:
        # VoiceToText 인스턴스 생성 (OpenAI API 사용)
        print("\n🤖 OpenAI API 클라이언트 초기화 중...")
        vtt = VoiceToText()  # API 키는 환경변수에서 자동으로 가져옴
        
        # 음성인식 수행
        print("\n🎯 음성인식 시작...")
        results = vtt.process_vocal_files(
            input_dir=input_dir,
            output_dir=output_dir
        )
        
        # 결과 출력
        print("\n" + "=" * 60)
        print("📊 처리 결과")
        print("=" * 60)
        print(f"✅ 성공: {results['processed']}개")
        print(f"❌ 실패: {results['failed']}개")
        print(f"📝 총 텍스트 파일: {len([f for f in results['files'] if f['status'] == 'success'])}개")
        
        if results['files']:
            print("\n📋 파일별 상세 결과:")
            print("-" * 60)
            
            total_cost = 0
            for file_result in results['files']:
                if file_result['status'] == 'success':
                    # 예상 비용 계산 (1분당 $0.006)
                    cost = (file_result['duration'] / 60) * 0.006
                    total_cost += cost
                    
                    print(f"✅ {file_result['input_file']}")
                    print(f"   -> {file_result['output_file']}")
                    print(f"   📄 텍스트 길이: {file_result['text_length']}자")
                    print(f"   ⏱️  오디오 길이: {file_result['duration']:.1f}초")
                    print(f"   📦 파일 크기: {file_result['file_size_mb']:.1f}MB")
                    print(f"   💰 예상 비용: ${cost:.4f}")
                    print()
                else:
                    print(f"❌ {file_result['input_file']}")
                    print(f"   오류: {file_result['error']}")
                    print()
            
            if total_cost > 0:
                print(f"💰 총 예상 비용: ${total_cost:.4f}")
                print()
        
        # 출력 디렉토리 내용 확인
        if os.path.exists(output_dir):
            text_files = [f for f in os.listdir(output_dir) if f.endswith('.txt')]
            if text_files:
                print(f"📂 {output_dir} 폴더에 생성된 파일들:")
                for txt_file in text_files:
                    file_path = os.path.join(output_dir, txt_file)
                    file_size = os.path.getsize(file_path)
                    print(f"   📄 {txt_file} ({file_size:,} bytes)")
        
        print("\n🎉 음성인식 테스트 완료!")
        
    except ValueError as e:
        print(f"\n❌ API 키 설정 오류: {e}")
        print("\n해결 방법:")
        print("1. backend/.env 파일에서 OPENAI_API_KEY 확인")
        print("2. OpenAI API 키가 유효한지 확인")
        print("3. API 키에 충분한 크레딧이 있는지 확인")
    except KeyboardInterrupt:
        print("\n\n⚠️  사용자에 의해 중단되었습니다.")
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main() 