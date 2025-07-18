#!/usr/bin/env python3
"""
🎵 간단한 보컬 분리 테스트 스크립트

test_data 폴더의 음악 파일들을 자동으로 찾아서 보컬 분리를 실행하고
test_result 폴더에 결과를 저장합니다.

사용법:
    cd backend/src/vocal
    python simple_test.py
"""

import os
import sys
from pathlib import Path
import time

# 현재 폴더에서 VocalSeparator import
from vocal_separation import VocalSeparator

def find_audio_files(directory: str) -> list:
    """
    디렉토리에서 지원되는 오디오 파일들을 찾습니다.
    
    Args:
        directory (str): 검색할 디렉토리 경로
        
    Returns:
        list: 오디오 파일 경로들의 리스트
    """
    audio_extensions = ['.mp3', '.wav', '.flac', '.m4a', '.aac']
    audio_files = []
    
    directory_path = Path(directory)
    if not directory_path.exists():
        return audio_files
    
    for file in directory_path.iterdir():
        if file.is_file() and file.suffix.lower() in audio_extensions:
            audio_files.append(str(file))
    
    return audio_files

def main():
    """
    메인 테스트 함수
    """
    print("🎵 간단한 보컬 분리 테스트 시작!")
    print("=" * 50)
    
    # 현재 스크립트 위치 기준으로 경로 설정
    current_dir = Path(__file__).parent
    test_data_dir = current_dir / "test_data"
    test_result_dir = current_dir / "test_result"
    
    print(f"📁 입력 폴더: {test_data_dir}")
    print(f"📁 출력 폴더: {test_result_dir}")
    
    # test_data 폴더에서 오디오 파일 찾기
    audio_files = find_audio_files(test_data_dir)
    
    if not audio_files:
        print("⚠️ test_data 폴더에 음악 파일이 없습니다!")
        print("📝 다음 중 하나를 수행해주세요:")
        print("   1. test_data 폴더에 .mp3, .wav, .flac 등의 음악 파일을 추가")
        print("   2. 예시: 노래1.wav, song.mp3 등")
        print("   3. 그 후 다시 이 스크립트를 실행")
        return
    
    print(f"🎧 발견된 음악 파일: {len(audio_files)}개")
    for i, file in enumerate(audio_files, 1):
        filename = Path(file).name
        print(f"   {i}. {filename}")
    print()
    
    try:
        # 보컬 분리기 초기화
        print("🤖 Demucs 모델 로딩 중...")
        separator = VocalSeparator("htdemucs")
        print("✅ 모델 로딩 완료!")
        print()
        
        # 각 파일에 대해 보컬 분리 실행
        total_files = len(audio_files)
        success_count = 0
        
        for i, audio_file in enumerate(audio_files, 1):
            filename = Path(audio_file).name
            print(f"🎵 [{i}/{total_files}] 처리 중: {filename}")
            
            start_time = time.time()
            
            try:
                # 보컬 분리 실행
                result = separator.separate_audio(
                    input_path=audio_file,
                    output_dir=str(test_result_dir),
                    audio_format="wav"
                )
                
                end_time = time.time()
                processing_time = end_time - start_time
                
                print(f"   ✅ 처리 완료 ({processing_time:.1f}초)")
                print(f"   📄 보컬: {Path(result['vocal']).name}")
                print(f"   📄 반주: {Path(result['inst']).name}")
                
                success_count += 1
                
            except Exception as e:
                print(f"   ❌ 처리 실패: {e}")
            
            print()
        
        # 결과 요약
        print("=" * 50)
        print(f"🎉 처리 완료!")
        print(f"   📊 총 파일: {total_files}개")
        print(f"   ✅ 성공: {success_count}개")
        print(f"   ❌ 실패: {total_files - success_count}개")
        
        if success_count > 0:
            print(f"📁 결과 파일들이 다음 폴더에 저장되었습니다:")
            print(f"   {test_result_dir}")
            
            # 결과 폴더의 파일들 나열
            result_files = list(test_result_dir.glob("*"))
            if result_files:
                print(f"📄 생성된 파일들:")
                for file in sorted(result_files):
                    file_size = file.stat().st_size / (1024 * 1024)  # MB
                    print(f"   - {file.name} ({file_size:.1f}MB)")
        
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        print("💡 해결 방법:")
        print("   1. 인터넷 연결 확인 (모델 다운로드 필요)")
        print("   2. 충분한 디스크 공간 확인")
        print("   3. 오디오 파일 형식 확인")

if __name__ == "__main__":
    main() 