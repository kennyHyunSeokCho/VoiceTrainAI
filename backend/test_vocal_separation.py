#!/usr/bin/env python3
"""
🎵 보컬 분리 테스트 스크립트 (Demucs 기반)

사용법:
    python test_vocal_separation.py --input "test.mp3" --output "results"
    
또는:
    python test_vocal_separation.py  # 기본값 사용
"""

import argparse
import os
import sys
from pathlib import Path

# src 폴더를 파이썬 경로에 추가
sys.path.append(os.path.join(os.path.dirname(__file__), 'src'))

from vocal import VocalSeparator

def main():
    parser = argparse.ArgumentParser(description="🎵 보컬 분리 테스트 (Demucs 기반)")
    parser.add_argument(
        "--input", "-i", 
        default="test_audio.mp3",
        help="입력 음악 파일 경로 (기본값: test_audio.mp3)"
    )
    parser.add_argument(
        "--output", "-o", 
        default="separated_audio",
        help="출력 디렉토리 경로 (기본값: separated_audio)"
    )
    parser.add_argument(
        "--model", "-m", 
        default="htdemucs",
        choices=["htdemucs", "htdemucs_ft", "hdemucs_mmi"],
        help="사용할 Demucs 모델 (기본값: htdemucs)"
    )
    parser.add_argument(
        "--format", "-f", 
        default="wav",
        choices=["wav", "mp3", "flac"],
        help="출력 오디오 포맷 (기본값: wav)"
    )
    parser.add_argument(
        "--info", 
        action="store_true",
        help="오디오 파일 정보만 출력하고 종료"
    )
    parser.add_argument(
        "--list-models", 
        action="store_true",
        help="사용 가능한 모델 목록 출력"
    )
    
    args = parser.parse_args()
    
    # 사용 가능한 모델 목록 출력
    if args.list_models:
        print("🤖 사용 가능한 Demucs 모델들:")
        try:
            separator = VocalSeparator()
            models = separator.get_available_models()
            for i, model in enumerate(models, 1):
                print(f"   {i}. {model}")
        except Exception as e:
            print(f"❌ 모델 목록 조회 실패: {e}")
        return
    
    # 입력 파일 확인
    if not os.path.exists(args.input):
        print(f"❌ 입력 파일을 찾을 수 없습니다: {args.input}")
        print("🎵 테스트용 음악 파일을 준비해주세요.")
        print("   지원 형식: .mp3, .wav, .flac, .m4a 등")
        
        # 현재 디렉토리의 오디오 파일들 찾기
        audio_extensions = ['.mp3', '.wav', '.flac', '.m4a', '.aac']
        current_dir = Path('.')
        audio_files = []
        
        for ext in audio_extensions:
            audio_files.extend(current_dir.glob(f'*{ext}'))
            audio_files.extend(current_dir.glob(f'*{ext.upper()}'))
        
        if audio_files:
            print("\n📁 현재 디렉토리의 오디오 파일들:")
            for file in audio_files[:5]:  # 최대 5개만 표시
                print(f"   - {file}")
            print(f"\n💡 예시: python {sys.argv[0]} --input \"{audio_files[0]}\"")
        
        return
    
    try:
        print(f"🎵 보컬 분리 시작!")
        print(f"   입력: {args.input}")
        print(f"   출력: {args.output}")
        print(f"   모델: {args.model}")
        print(f"   포맷: {args.format}")
        print("="*50)
        
        # 보컬 분리기 생성
        separator = VocalSeparator(args.model)
        
        # 오디오 정보 출력
        print("📊 오디오 파일 분석 중...")
        audio_info = separator.get_audio_info(args.input)
        
        print(f"📝 입력 파일 정보:")
        print(f"   파일명: {Path(args.input).name}")
        print(f"   크기: {audio_info['file_size']:,} bytes ({audio_info['file_size']/1024/1024:.1f} MB)")
        print(f"   재생시간: {audio_info['duration']:.2f}초 ({audio_info['duration']/60:.1f}분)")
        print(f"   샘플레이트: {audio_info['sample_rate']:,}Hz")
        print(f"   채널: {audio_info['channels']}ch")
        print(f"   포맷: {audio_info['format']}")
        print(f"   처리 디바이스: {audio_info['device_used']}")
        
        # 정보만 출력하고 종료
        if args.info:
            print("\n✅ 오디오 파일 정보 출력 완료!")
            return
        
        print("\n🔄 보컬 분리 처리 중...")
        print("   (첫 실행 시 모델 다운로드로 시간이 걸릴 수 있습니다)")
        
        # 보컬 분리 실행
        start_time = __import__('time').time()
        result = separator.separate_audio(args.input, args.output, args.format)
        end_time = __import__('time').time()
        
        processing_time = end_time - start_time
        
        print(f"\n🎉 보컬 분리 완료! (처리시간: {processing_time:.1f}초)")
        print("="*50)
        print("📁 생성된 파일들:")
        
        total_size = 0
        for i, (instrument, path) in enumerate(result.items(), 1):
            file_size = os.path.getsize(path)
            total_size += file_size
            korean_name = separator._get_korean_instrument_name(instrument)
            print(f"   {i}. {korean_name} ({instrument})")
            print(f"      📄 {Path(path).name}")
            print(f"      📊 {file_size:,} bytes ({file_size/1024/1024:.1f} MB)")
        
        print(f"\n📊 처리 통계:")
        print(f"   원본 크기: {audio_info['file_size']:,} bytes ({audio_info['file_size']/1024/1024:.1f} MB)")
        print(f"   출력 총 크기: {total_size:,} bytes ({total_size/1024/1024:.1f} MB)")
        print(f"   처리 시간: {processing_time:.1f}초")
        print(f"   처리 속도: {audio_info['duration']/processing_time:.1f}x 실시간")
        
        print(f"\n💡 사용 팁:")
        print(f"   • 보컬 연습: '{korean_name}' 파일 사용")
        print(f"   • 반주 연습: '반주' 파일 사용") 
        print(f"   • 개별 악기: 각각의 악기 파일들 활용")
        
    except KeyboardInterrupt:
        print("\n⏹️ 사용자가 중단했습니다.")
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        print("💡 해결 방법:")
        print("   1. 입력 파일이 올바른 오디오 파일인지 확인")
        print("   2. 충분한 디스크 공간이 있는지 확인")
        print("   3. 인터넷 연결 상태 확인 (모델 다운로드)")
        print("   4. Python 패키지가 올바르게 설치되었는지 확인")

if __name__ == "__main__":
    main() 