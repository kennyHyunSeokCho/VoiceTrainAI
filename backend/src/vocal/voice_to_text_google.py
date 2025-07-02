import os
import io
import json
from pathlib import Path
import logging
from typing import Optional, Dict, List
from dotenv import load_dotenv

from google.cloud import speech
from google.oauth2 import service_account
import ffmpeg

# 환경변수 로드
load_dotenv()

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class VoiceToTextGoogle:
    """Google Cloud Speech-to-Text API를 사용한 음성-텍스트 변환 클래스"""
    
    def __init__(self, credentials_path=None, project_id=None):
        """
        초기화
        
        Args:
            credentials_path (str): Google Cloud Service Account JSON 키 파일 경로
            project_id (str): Google Cloud Project ID
        """
        self.project_id = project_id or os.getenv('GOOGLE_CLOUD_PROJECT_ID')
        
        # 인증 설정
        if credentials_path:
            self.credentials = service_account.Credentials.from_service_account_file(credentials_path)
        elif os.getenv('GOOGLE_APPLICATION_CREDENTIALS'):
            credentials_path = os.getenv('GOOGLE_APPLICATION_CREDENTIALS')
            self.credentials = service_account.Credentials.from_service_account_file(credentials_path)
        elif os.getenv('GOOGLE_CLOUD_CREDENTIALS_JSON'):
            # JSON 문자열로 직접 설정하는 경우
            credentials_info = json.loads(os.getenv('GOOGLE_CLOUD_CREDENTIALS_JSON'))
            self.credentials = service_account.Credentials.from_service_account_info(credentials_info)
        else:
            # 기본 인증 사용 (gcloud CLI 또는 환경 인증)
            self.credentials = None
        
        try:
            # Speech 클라이언트 초기화
            if self.credentials:
                self.client = speech.SpeechClient(credentials=self.credentials)
                logger.info("✅ Google Cloud Speech 클라이언트 초기화 완료 (Service Account)")
            else:
                self.client = speech.SpeechClient()
                logger.info("✅ Google Cloud Speech 클라이언트 초기화 완료 (기본 인증)")
                
        except Exception as e:
            logger.error(f"Google Cloud Speech 클라이언트 초기화 실패: {e}")
            raise
    
    def _convert_to_supported_format(self, audio_path: str, target_format: str = "flac") -> str:
        """
        오디오 파일을 Google Speech API 지원 형식으로 변환
        
        Args:
            audio_path (str): 입력 오디오 파일 경로
            target_format (str): 목표 형식 (flac, wav, mp3)
            
        Returns:
            str: 변환된 파일 경로
        """
        input_path = Path(audio_path)
        output_path = input_path.with_suffix(f'.{target_format}')
        
        if output_path.exists():
            logger.info(f"이미 변환된 파일이 존재합니다: {output_path}")
            return str(output_path)
        
        try:
            logger.info(f"오디오 형식 변환 중: {input_path.name} -> {target_format}")
            
            # ffmpeg로 형식 변환 (단일 채널, 16kHz)
            (
                ffmpeg
                .input(str(input_path))
                .output(
                    str(output_path),
                    ac=1,  # 모노 채널
                    ar=16000,  # 16kHz 샘플레이트
                    acodec='flac' if target_format == 'flac' else 'pcm_s16le'
                )
                .overwrite_output()
                .run(quiet=True)
            )
            
            logger.info(f"변환 완료: {output_path}")
            return str(output_path)
            
        except Exception as e:
            logger.error(f"오디오 변환 실패: {e}")
            raise
    
    def transcribe_audio(self, audio_path: str, language_code: str = 'ko-KR') -> Dict:
        """
        오디오 파일을 텍스트로 변환
        
        Args:
            audio_path (str): 변환할 오디오 파일 경로
            language_code (str): 언어 코드 (기본값: 'ko-KR' - 한국어)
            
        Returns:
            dict: 변환 결과 (텍스트, 신뢰도, 타임스탬프 정보 포함)
        """
        if not os.path.exists(audio_path):
            raise FileNotFoundError(f"오디오 파일을 찾을 수 없습니다: {audio_path}")
        
        file_size = os.path.getsize(audio_path) / (1024 * 1024)  # MB
        logger.info(f"Google Speech 음성인식 시작: {os.path.basename(audio_path)} ({file_size:.1f}MB)")
        
        try:
            # Google Cloud Speech에 최적화된 형식으로 변환
            converted_audio = self._convert_to_supported_format(audio_path, "flac")
            
            # 오디오 파일 읽기
            with open(converted_audio, 'rb') as audio_file:
                content = audio_file.read()
            
            # Google Cloud Speech 설정
            audio = speech.RecognitionAudio(content=content)
            
            config = speech.RecognitionConfig(
                encoding=speech.RecognitionConfig.AudioEncoding.FLAC,
                sample_rate_hertz=16000,
                language_code=language_code,
                alternative_language_codes=['en-US'],  # 영어 백업 인식
                
                # 고급 기능들
                enable_automatic_punctuation=True,      # 자동 구두점 추가
                enable_word_time_offsets=True,          # 단어별 타임스탬프
                enable_word_confidence=True,            # 단어별 신뢰도
                profanity_filter=False,                 # 욕설 필터링 (음악이므로 비활성화)
                
                # 음성 향상 옵션
                use_enhanced=True,                      # 향상된 모델 사용
                model='latest_long',                    # 긴 오디오용 최신 모델
                
                # 화자 구분 (여러 보컬이 있는 경우)
                enable_speaker_diarization=True,
                diarization_speaker_count=2,            # 최대 2명의 화자
            )
            
            # 파일 크기에 따라 처리 방식 결정
            if file_size > 10:  # 10MB 이상은 Long Running Operation 사용
                logger.info("대용량 파일로 인해 비동기 처리를 사용합니다...")
                operation = self.client.long_running_recognize(config=config, audio=audio)
                response = operation.result(timeout=600)  # 최대 10분 대기
            else:
                # 작은 파일은 동기 처리
                response = self.client.recognize(config=config, audio=audio)
            
            # 결과 처리
            if not response.results:
                logger.warning("음성 인식 결과가 없습니다")
                return {
                    'text': '',
                    'confidence': 0.0,
                    'words': [],
                    'speakers': [],
                    'language': language_code,
                    'service': 'Google Cloud Speech'
                }
            
            # 모든 대안 텍스트와 최고 신뢰도 선택
            full_text = ""
            all_words = []
            all_speakers = []
            total_confidence = 0.0
            result_count = 0
            
            for result in response.results:
                if result.alternatives:
                    # 가장 신뢰도 높은 대안 선택
                    alternative = result.alternatives[0]
                    full_text += alternative.transcript + " "
                    total_confidence += alternative.confidence
                    result_count += 1
                    
                    # 단어별 상세 정보 수집
                    for word_info in alternative.words:
                        word_data = {
                            'word': word_info.word,
                            'start_time': word_info.start_time.total_seconds(),
                            'end_time': word_info.end_time.total_seconds(),
                            'confidence': getattr(word_info, 'confidence', 0.0),
                            'speaker_tag': getattr(word_info, 'speaker_tag', 0)
                        }
                        all_words.append(word_data)
                        
                        # 화자 정보 수집
                        speaker_tag = getattr(word_info, 'speaker_tag', 0)
                        if speaker_tag not in [s['tag'] for s in all_speakers]:
                            all_speakers.append({
                                'tag': speaker_tag,
                                'word_count': 0
                            })
                        
                        # 화자별 단어 수 계산
                        for speaker in all_speakers:
                            if speaker['tag'] == speaker_tag:
                                speaker['word_count'] += 1
            
            # 평균 신뢰도 계산
            avg_confidence = total_confidence / result_count if result_count > 0 else 0.0
            
            # 변환된 임시 파일 정리
            if converted_audio != audio_path:
                try:
                    os.remove(converted_audio)
                    logger.info(f"임시 변환 파일 삭제: {converted_audio}")
                except:
                    pass
            
            logger.info(f"Google Speech 인식 완료: {len(full_text.strip())}자, 신뢰도: {avg_confidence:.2f}")
            
            return {
                'text': full_text.strip(),
                'confidence': avg_confidence,
                'words': all_words,
                'speakers': all_speakers,
                'language': language_code,
                'service': 'Google Cloud Speech',
                'word_count': len(all_words),
                'speaker_count': len(all_speakers)
            }
            
        except Exception as e:
            logger.error(f"Google Speech 인식 실패: {e}")
            raise
    
    def process_vocal_files(self, input_dir: str, output_dir: str) -> Dict:
        """
        입력 디렉토리의 모든 _vocal.wav 파일을 처리
        
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
        total_cost = 0.0
        
        for vocal_file in vocal_files:
            try:
                logger.info(f"처리 중: {vocal_file.name}")
                
                file_size = vocal_file.stat().st_size
                duration_seconds = self._get_audio_duration(str(vocal_file))
                
                # 음성인식 수행
                transcription = self.transcribe_audio(str(vocal_file))
                
                # 비용 계산 (Google Cloud Speech: $0.006/분)
                cost = (duration_seconds / 60) * 0.006
                total_cost += cost
                
                # 출력 파일명 생성 (예: 가요1_vocal.wav -> 가요1_vocal_google.txt)
                output_filename = vocal_file.stem + '_google.txt'
                output_file_path = output_path / output_filename
                
                # 텍스트 파일로 저장
                with open(output_file_path, 'w', encoding='utf-8') as f:
                    f.write(f"파일명: {vocal_file.name}\n")
                    f.write(f"파일 크기: {file_size/(1024*1024):.1f}MB\n")
                    f.write(f"길이: {duration_seconds:.2f}초\n")
                    f.write(f"언어: {transcription['language']}\n")
                    f.write(f"서비스: {transcription['service']}\n")
                    f.write(f"평균 신뢰도: {transcription['confidence']:.2f}\n")
                    f.write(f"총 단어 수: {transcription['word_count']}개\n")
                    f.write(f"화자 수: {transcription['speaker_count']}명\n")
                    f.write(f"예상 비용: ${cost:.4f}\n")
                    f.write(f"생성 시간: {self._get_current_time()}\n")
                    f.write("-" * 50 + "\n\n")
                    f.write(transcription['text'])
                    
                    # 단어별 상세 정보
                    if transcription['words']:
                        f.write("\n\n" + "="*50 + "\n")
                        f.write("단어별 상세 정보 (신뢰도 및 타임스탬프):\n")
                        f.write("="*50 + "\n\n")
                        
                        for word_info in transcription['words']:
                            start = word_info['start_time']
                            end = word_info['end_time']
                            word = word_info['word']
                            confidence = word_info['confidence']
                            speaker = word_info['speaker_tag']
                            
                            f.write(f"{start:.2f}s-{end:.2f}s: '{word}' ")
                            f.write(f"(신뢰도: {confidence:.2f}, 화자: {speaker})\n")
                    
                    # 화자별 통계
                    if transcription['speakers'] and len(transcription['speakers']) > 1:
                        f.write("\n\n" + "="*50 + "\n")
                        f.write("화자별 통계:\n")
                        f.write("="*50 + "\n\n")
                        
                        for speaker in transcription['speakers']:
                            percentage = (speaker['word_count'] / transcription['word_count']) * 100
                            f.write(f"화자 {speaker['tag']}: {speaker['word_count']}단어 ({percentage:.1f}%)\n")
                
                results.append({
                    'input_file': vocal_file.name,
                    'output_file': output_filename,
                    'text_length': len(transcription['text']),
                    'duration': duration_seconds,
                    'file_size_mb': file_size/(1024*1024),
                    'confidence': transcription['confidence'],
                    'word_count': transcription['word_count'],
                    'speaker_count': transcription['speaker_count'],
                    'cost': cost,
                    'status': 'success'
                })
                
                processed += 1
                logger.info(f"완료: {output_filename} 저장 (신뢰도: {transcription['confidence']:.2f})")
                
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
        logger.info(f"Google Speech 처리 완료 - 성공: {processed}개, 실패: {failed}개, 총 비용: ${total_cost:.4f}")
        
        return {
            'processed': processed,
            'failed': failed,
            'total_cost': total_cost,
            'files': results
        }
    
    def _get_audio_duration(self, audio_path: str) -> float:
        """오디오 파일의 길이를 구함"""
        try:
            probe = ffmpeg.probe(audio_path)
            return float(probe['streams'][0]['duration'])
        except:
            return 0.0
    
    def _get_current_time(self):
        """현재 시간을 문자열로 반환"""
        from datetime import datetime
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


# 사용 예시
if __name__ == "__main__":
    try:
        # VoiceToTextGoogle 인스턴스 생성
        vtt_google = VoiceToTextGoogle()
        
        # test_result 폴더의 보컬 파일들을 test_text로 변환
        results = vtt_google.process_vocal_files(
            input_dir='test_result',
            output_dir='test_text'
        )
        
        print(f"\nGoogle Cloud Speech 처리 결과:")
        print(f"성공: {results['processed']}개")
        print(f"실패: {results['failed']}개")
        print(f"총 비용: ${results['total_cost']:.4f}")
        
        if results['files']:
            print("\n파일별 상세 결과:")
            for file_result in results['files']:
                if file_result['status'] == 'success':
                    print(f"✅ {file_result['input_file']} -> {file_result['output_file']}")
                    print(f"   📄 텍스트 길이: {file_result['text_length']}자")
                    print(f"   ⏱️  오디오 길이: {file_result['duration']:.1f}초")
                    print(f"   📦 파일 크기: {file_result['file_size_mb']:.1f}MB")
                    print(f"   🎯 평균 신뢰도: {file_result['confidence']:.2f}")
                    print(f"   📝 단어 수: {file_result['word_count']}개")
                    print(f"   🎤 화자 수: {file_result['speaker_count']}명")
                    print(f"   💰 비용: ${file_result['cost']:.4f}")
                    print()
                else:
                    print(f"❌ {file_result['input_file']}: {file_result['error']}")
                    print()
                    
    except Exception as e:
        print(f"❌ 오류: {e}")
        print("\n해결 방법:")
        print("1. Google Cloud Console에서 Speech-to-Text API 활성화")
        print("2. Service Account 키 생성 및 GOOGLE_APPLICATION_CREDENTIALS 환경변수 설정")
        print("3. 또는 gcloud auth login으로 인증")
        print("4. GOOGLE_CLOUD_PROJECT_ID 환경변수 설정") 