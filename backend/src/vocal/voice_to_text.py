import openai
import os
from pathlib import Path
import logging
from dotenv import load_dotenv
import ffmpeg
import tempfile
import shutil

# 환경변수 로드
load_dotenv()

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class VoiceToText:
    """OpenAI API Whisper를 사용한 음성-텍스트 변환 클래스 (파일 분할 지원)"""
    
    def __init__(self, api_key=None, max_file_size_mb=20):
        """
        초기화
        
        Args:
            api_key (str): OpenAI API 키 (None이면 환경변수에서 가져옴)
            max_file_size_mb (int): 분할 기준 크기 (MB) - OpenAI 제한 25MB보다 작게 설정
        """
        # API 키 설정
        if api_key:
            self.api_key = api_key
        else:
            self.api_key = os.getenv('OPENAI_API_KEY')
        
        if not self.api_key:
            raise ValueError(
                "OpenAI API 키가 필요합니다. "
                "환경변수 OPENAI_API_KEY를 설정하거나 api_key 매개변수를 제공해주세요."
            )
        
        # OpenAI 클라이언트 초기화
        self.client = openai.OpenAI(api_key=self.api_key)
        self.max_file_size_bytes = max_file_size_mb * 1024 * 1024  # MB to bytes
        logger.info(f"OpenAI API 클라이언트 초기화 완료 (분할 기준: {max_file_size_mb}MB)")
    
    def split_audio_file(self, audio_path, target_size_mb=20):
        """
        오디오 파일을 지정된 크기로 분할
        
        Args:
            audio_path (str): 분할할 오디오 파일 경로
            target_size_mb (int): 목표 분할 크기 (MB)
            
        Returns:
            list: 분할된 파일 경로 리스트
        """
        try:
            # 파일 정보 가져오기
            probe = ffmpeg.probe(audio_path)
            duration = float(probe['streams'][0]['duration'])  # 초 단위
            file_size = os.path.getsize(audio_path)
            
            # 분할이 필요한지 확인
            if file_size <= self.max_file_size_bytes:
                return [audio_path]  # 분할 불필요
            
            # 분할 개수 계산
            target_size_bytes = target_size_mb * 1024 * 1024
            num_parts = int(file_size / target_size_bytes) + 1
            segment_duration = duration / num_parts
            
            logger.info(f"파일 분할 시작: {num_parts}개 세그먼트 (각 {segment_duration:.1f}초)")
            
            # 임시 디렉토리 생성
            temp_dir = tempfile.mkdtemp(prefix="vocal_split_")
            split_files = []
            
            base_name = Path(audio_path).stem
            
            for i in range(num_parts):
                start_time = i * segment_duration
                output_path = os.path.join(temp_dir, f"{base_name}_part{i+1}.wav")
                
                # FFmpeg로 세그먼트 추출
                (
                    ffmpeg
                    .input(audio_path, ss=start_time, t=segment_duration)
                    .output(output_path, acodec='pcm_s16le', ar=16000)  # 16kHz, 16bit
                    .overwrite_output()
                    .run(quiet=True)
                )
                
                if os.path.exists(output_path):
                    split_files.append(output_path)
                    part_size = os.path.getsize(output_path) / (1024 * 1024)
                    logger.info(f"분할 완료: part {i+1}/{num_parts} ({part_size:.1f}MB)")
            
            return split_files
            
        except Exception as e:
            logger.error(f"파일 분할 실패: {e}")
            raise
    
    def transcribe_audio(self, audio_path, language='ko'):
        """
        오디오 파일을 텍스트로 변환 (OpenAI API 사용, 필요시 자동 분할)
        
        Args:
            audio_path (str): 변환할 오디오 파일 경로
            language (str): 언어 코드 (기본값: 'ko' - 한국어)
            
        Returns:
            dict: 변환 결과 (텍스트, 언어, 길이 정보 포함)
        """
        if not os.path.exists(audio_path):
            raise FileNotFoundError(f"오디오 파일을 찾을 수 없습니다: {audio_path}")
        
        logger.info(f"음성인식 시작: {os.path.basename(audio_path)}")
        
        try:
            file_size = os.path.getsize(audio_path)
            
            # 파일 크기 확인 및 분할 여부 결정
            if file_size > self.max_file_size_bytes:
                logger.info(f"파일이 큽니다 ({file_size/(1024*1024):.1f}MB > {self.max_file_size_bytes/(1024*1024)}MB). 분할 처리 시작...")
                return self._transcribe_large_file(audio_path, language)
            else:
                return self._transcribe_single_file(audio_path, language)
                
        except Exception as e:
            logger.error(f"음성인식 실패: {e}")
            raise
    
    def _transcribe_single_file(self, audio_path, language='ko'):
        """단일 파일 음성인식 처리"""
        with open(audio_path, 'rb') as audio_file:
            response = self.client.audio.transcriptions.create(
                model="whisper-1",
                file=audio_file,
                language=language,
                response_format="verbose_json"
            )
        
        text = response.text.strip()
        duration = getattr(response, 'duration', 0)
        language_detected = getattr(response, 'language', language)
        
        # 단어별 타임스탬프 정보 처리
        segments = self._process_word_timestamps(response, duration)
        
        logger.info(f"음성인식 완료: {len(text)}자 텍스트 생성")
        
        return {
            'text': text,
            'language': language_detected,
            'segments': segments,
            'duration': duration,
            'split_count': 1
        }
    
    def _transcribe_large_file(self, audio_path, language='ko'):
        """큰 파일을 분할하여 음성인식 처리"""
        split_files = None
        try:
            # 파일 분할
            split_files = self.split_audio_file(audio_path)
            
            if len(split_files) == 1:
                # 분할이 실제로 일어나지 않음
                return self._transcribe_single_file(audio_path, language)
            
            # 각 분할 파일 처리
            all_texts = []
            all_segments = []
            total_duration = 0
            current_offset = 0
            
            for i, split_file in enumerate(split_files):
                logger.info(f"분할 파일 처리 중: {i+1}/{len(split_files)}")
                
                result = self._transcribe_single_file(split_file, language)
                all_texts.append(result['text'])
                
                # 세그먼트 타임스탬프 오프셋 조정
                for segment in result['segments']:
                    adjusted_segment = segment.copy()
                    adjusted_segment['start'] += current_offset
                    adjusted_segment['end'] += current_offset
                    all_segments.append(adjusted_segment)
                
                current_offset += result['duration']
                total_duration += result['duration']
            
            # 결과 합치기
            combined_text = ' '.join(all_texts)
            
            logger.info(f"분할 처리 완료: {len(split_files)}개 파일, 총 {len(combined_text)}자")
            
            return {
                'text': combined_text,
                'language': language,
                'segments': all_segments,
                'duration': total_duration,
                'split_count': len(split_files)
            }
            
        finally:
            # 임시 파일 정리
            if split_files and len(split_files) > 1:
                self._cleanup_split_files(split_files)
    
    def _process_word_timestamps(self, response, duration):
        """응답에서 세그먼트 정보 추출"""
        segments = []
        if hasattr(response, 'segments') and response.segments:
            # OpenAI API의 기본 세그먼트 사용
            for segment in response.segments:
                segments.append({
                    'start': segment.get('start', 0),
                    'end': segment.get('end', duration),
                    'text': segment.get('text', '').strip()
                })
        else:
            # 세그먼트가 없으면 전체 텍스트를 하나의 세그먼트로 처리
            segments.append({
                'start': 0,
                'end': duration,
                'text': response.text.strip()
            })
        
        return segments
    
    def _cleanup_split_files(self, split_files):
        """분할된 임시 파일들 정리"""
        try:
            if split_files:
                temp_dir = os.path.dirname(split_files[0])
                if temp_dir and 'vocal_split_' in temp_dir:
                    shutil.rmtree(temp_dir)
                    logger.info("임시 분할 파일들 정리 완료")
        except Exception as e:
            logger.warning(f"임시 파일 정리 실패: {e}")
    
    def process_vocal_files(self, input_dir, output_dir):
        """
        입력 디렉토리의 모든 _vocal.wav 파일을 처리 (자동 분할 지원)
        
        Args:
            input_dir (str): _vocal.wav 파일들이 있는 디렉토리
            output_dir (str): 텍스트 파일을 저장할 디렉토리
            
        Returns:
            dict: 처리 결과 통계
        """
        input_path = Path(input_dir)
        output_path = Path(output_dir)
        
        # 출력 디렉토리 생성
        output_path.mkdir(parents=True, exist_ok=True)
        
        # _vocal.wav 파일들 찾기
        vocal_files = list(input_path.glob("*_vocal.wav"))
        
        if not vocal_files:
            logger.warning(f"{input_dir}에서 _vocal.wav 파일을 찾을 수 없습니다")
            return {'processed': 0, 'failed': 0, 'files': []}
        
        logger.info(f"처리할 보컬 파일 {len(vocal_files)}개 발견")
        
        results = []
        processed = 0
        failed = 0
        
        for vocal_file in vocal_files:
            try:
                logger.info(f"처리 중: {vocal_file.name}")
                
                file_size = vocal_file.stat().st_size
                
                # 음성인식 수행 (자동 분할 포함)
                transcription = self.transcribe_audio(str(vocal_file))
                
                # 출력 파일명 생성 (예: 가요1_vocal.wav -> 가요1_vocal.txt)
                output_filename = vocal_file.stem + '.txt'
                output_file_path = output_path / output_filename
                
                # 텍스트 파일로 저장
                with open(output_file_path, 'w', encoding='utf-8') as f:
                    f.write(f"파일명: {vocal_file.name}\n")
                    f.write(f"파일 크기: {file_size/(1024*1024):.1f}MB\n")
                    f.write(f"언어: {transcription['language']}\n")
                    f.write(f"길이: {transcription['duration']:.2f}초\n")
                    f.write(f"분할 처리: {'예' if transcription['split_count'] > 1 else '아니오'} ({transcription['split_count']}개 세그먼트)\n")
                    f.write(f"생성 시간: {self._get_current_time()}\n")
                    f.write(f"처리 방식: OpenAI API (whisper-1)\n")
                    f.write("-" * 50 + "\n\n")
                    f.write(transcription['text'])
                    
                    # 세그먼트별 상세 정보도 추가
                    if transcription['segments']:
                        f.write("\n\n" + "="*50 + "\n")
                        f.write("세그먼트별 상세 정보:\n")
                        f.write("="*50 + "\n\n")
                        
                        for i, segment in enumerate(transcription['segments'], 1):
                            start_time = segment['start']
                            end_time = segment['end']
                            text = segment['text']
                            f.write(f"[{i}] {start_time:.2f}s - {end_time:.2f}s: {text}\n")
                
                results.append({
                    'input_file': vocal_file.name,
                    'output_file': output_filename,
                    'text_length': len(transcription['text']),
                    'duration': transcription['duration'],
                    'file_size_mb': file_size/(1024*1024),
                    'split_count': transcription['split_count'],
                    'status': 'success'
                })
                
                processed += 1
                logger.info(f"완료: {output_filename} 저장")
                
            except Exception as e:
                logger.error(f"{vocal_file.name} 처리 실패: {e}")
                results.append({
                    'input_file': vocal_file.name,
                    'output_file': None,
                    'error': str(e),
                    'status': 'failed'
                })
                failed += 1
        
        # 통계 정보 로깅
        logger.info(f"처리 완료 - 성공: {processed}개, 실패: {failed}개")
        
        return {
            'processed': processed,
            'failed': failed,
            'files': results
        }
    
    def _get_current_time(self):
        """현재 시간을 문자열로 반환"""
        from datetime import datetime
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


# 사용 예시
if __name__ == "__main__":
    try:
        # VoiceToText 인스턴스 생성 (OpenAI API 사용, 20MB 기준으로 분할)
        vtt = VoiceToText(max_file_size_mb=20)
        
        # test_result 폴더의 보컬 파일들을 test_text로 변환
        results = vtt.process_vocal_files(
            input_dir='test_result',
            output_dir='test_text'
        )
        
        print(f"\n처리 결과:")
        print(f"성공: {results['processed']}개")
        print(f"실패: {results['failed']}개")
        
        if results['files']:
            print("\n파일별 상세 결과:")
            for file_result in results['files']:
                if file_result['status'] == 'success':
                    # 예상 비용 계산 (1분당 $0.006)
                    cost = (file_result['duration'] / 60) * 0.006
                    split_info = f" (분할: {file_result['split_count']}개)" if file_result['split_count'] > 1 else ""
                    
                    print(f"✅ {file_result['input_file']} -> {file_result['output_file']}{split_info}")
                    print(f"   📄 텍스트 길이: {file_result['text_length']}자")
                    print(f"   ⏱️  오디오 길이: {file_result['duration']:.1f}초")
                    print(f"   📦 파일 크기: {file_result['file_size_mb']:.1f}MB")
                    print(f"   💰 예상 비용: ${cost:.4f}")
                    print()
                else:
                    print(f"❌ {file_result['input_file']}: {file_result['error']}")
                    print()
                    
    except ValueError as e:
        print(f"❌ 설정 오류: {e}")
        print("\n해결 방법:")
        print("1. .env 파일에 OPENAI_API_KEY=your_api_key_here 추가")
        print("2. 또는 환경변수로 export OPENAI_API_KEY=your_api_key_here") 