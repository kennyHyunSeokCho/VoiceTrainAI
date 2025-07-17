"""
🎵 보컬 분리 알고리즘 모듈 (Demucs 사용)
Demucs를 사용하여 음악 파일에서 보컬과 반주를 분리하는 기능을 제공합니다.
"""

import os
import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import librosa
import numpy as np
import torch
import torchaudio
from demucs import pretrained
from demucs.apply import apply_model
from demucs.audio import convert_audio

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class VocalSeparator:
    """
    보컬 분리 클래스 (Demucs 기반)
    
    Demucs 모델을 사용하여 음악 파일에서 보컬과 반주를 분리합니다.
    지원하는 모델:
    - htdemucs: 기본 4-source 분리 (보컬, 드럼, 베이스, 기타)
    - htdemucs_ft: 파인튜닝된 버전
    - hdemucs_mmi: 보컬 품질에 최적화
    """
    
    def __init__(self, model_name: str = "htdemucs"):
        """
        보컬 분리기 초기화
        
        Args:
            model_name (str): 사용할 Demucs 모델 이름
                - "htdemucs": 기본 4-source 분리 (추천)
                - "htdemucs_ft": 파인튜닝된 버전
                - "hdemucs_mmi": 보컬 품질 우선
        """
        self.model_name = model_name
        self.model = None
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        
        # 모델 로드
        self._load_model()
    
    def _load_model(self) -> None:
        """
        Demucs 모델을 로드합니다.
        첫 번째 실행 시 모델을 다운로드하므로 시간이 걸릴 수 있습니다.
        """
        try:
            logger.info(f"🎵 {self.model_name} 모델 로드 중... (디바이스: {self.device})")
            self.model = pretrained.get_model(self.model_name)
            self.model.to(self.device)
            logger.info("✅ 모델 로드 완료!")
        except Exception as e:
            logger.error(f"❌ 모델 로드 실패: {e}")
            raise
    
    def separate_audio(self, 
                      input_path: str,
                      output_dir: str = None,
                      audio_format: str = "wav",
                      vocal_dir: str = None,
                      inst_dir: str = None) -> Dict[str, str]:
        """
        음악 파일에서 보컬과 반주를 분리합니다.
        
        Args:
            input_path (str): 입력 음악 파일 경로
            output_dir (str): (사용 안함, 호환성)
            vocal_dir (str): 보컬 저장 폴더 경로
            inst_dir (str): inst 저장 폴더 경로
            audio_format (str): 출력 오디오 포맷 (wav, mp3, flac 등)
        
        Returns:
            Dict[str, str]: 분리된 오디오 파일들의 경로
                - "vocal": 보컬 파일 경로
                - "inst": 반주(instrumental) 파일 경로
        
        Raises:
            FileNotFoundError: 입력 파일이 존재하지 않을 때
            Exception: 분리 과정에서 오류 발생 시
        """
        # 입력 파일 존재 확인
        if not os.path.exists(input_path):
            raise FileNotFoundError(f"입력 파일을 찾을 수 없습니다: {input_path}")
        
        # 분리 결과 폴더 지정
        base_filename = Path(input_path).stem
        vocal_dir = vocal_dir or "data/music_file/seperated_voice"
        inst_dir = inst_dir or "data/music_file/seperated_inst"
        Path(vocal_dir).mkdir(parents=True, exist_ok=True)
        Path(inst_dir).mkdir(parents=True, exist_ok=True)
        
        try:
            logger.info(f"🎧 음성 분리 시작: {input_path}")
            
            # 오디오 파일 로드
            wav, sr = torchaudio.load(input_path)
            logger.info(f"📊 원본 오디오: {wav.shape}, {sr}Hz")
            
            # 모델에 맞는 형식으로 변환
            wav = convert_audio(wav, sr, self.model.samplerate, self.model.audio_channels)
            wav = wav.to(self.device)
            
            # 보컬/악기 분리 실행
            with torch.no_grad():
                sources = apply_model(
                    self.model, 
                    wav[None], 
                    split=True,  # 메모리 효율성을 위한 청크 분할
                    overlap=0.25  # 청크 간 오버랩
                )[0]
            
            # 결과 파일 저장 (보컬과 반주만)
            result_paths = {}
            
            # Demucs 모델의 source 이름들
            source_names = self.model.sources
            
            # 보컬 찾기 및 저장
            if "vocals" in source_names:
                vocal_idx = source_names.index("vocals")
                
                # 1. 보컬 파일 저장
                vocal_filename = f"{base_filename}_vocal.{audio_format}"
                vocal_path = Path(vocal_dir) / vocal_filename
                
                torchaudio.save(
                    str(vocal_path),
                    sources[vocal_idx].cpu(),
                    self.model.samplerate,
                    format=audio_format.upper() if audio_format != "mp3" else None
                )
                
                result_paths["vocal"] = str(vocal_path)
                logger.info(f"✅ 보컬 저장 완료: {vocal_path}")
                
                # 2. 반주 (보컬 제외한 모든 것) 생성 및 저장
                accompaniment = torch.sum(
                    torch.stack([sources[i] for i in range(len(sources)) if i != vocal_idx]), 
                    dim=0
                )
                
                inst_filename = f"{base_filename}_inst.{audio_format}"
                inst_path = Path(inst_dir) / inst_filename
                
                torchaudio.save(
                    str(inst_path),
                    accompaniment.cpu(),
                    self.model.samplerate,
                    format=audio_format.upper() if audio_format != "mp3" else None
                )
                
                result_paths["inst"] = str(inst_path)
                logger.info(f"✅ 반주 저장 완료: {inst_path}")
            else:
                logger.error("❌ 보컬 트랙을 찾을 수 없습니다!")
                raise Exception("모델에서 보컬 트랙을 분리할 수 없습니다.")
            
            logger.info(f"🎉 보컬 분리 완료! 총 {len(result_paths)}개 파일 생성")
            return result_paths
            
        except Exception as e:
            logger.error(f"❌ 보컬 분리 실패: {e}")
            raise
    
    def _get_korean_instrument_name(self, instrument: str) -> str:
        """
        영어 악기명을 한글로 변환합니다.
        
        Args:
            instrument (str): 영어 악기명
            
        Returns:
            str: 한글 악기명
        """
        instrument_mapping = {
            "vocals": "보컬",
            "drums": "드럼",
            "bass": "베이스",
            "other": "기타악기",
            "accompaniment": "반주"
        }
        return instrument_mapping.get(instrument, instrument)
    
    def get_audio_info(self, audio_path: str) -> Dict[str, any]:
        """
        오디오 파일의 정보를 반환합니다.
        
        Args:
            audio_path (str): 오디오 파일 경로
            
        Returns:
            Dict[str, any]: 오디오 정보
                - duration: 재생 시간(초)
                - sample_rate: 샘플 레이트
                - channels: 채널 수
                - file_size: 파일 크기(bytes)
        """
        try:
            # torchaudio로 오디오 정보 추출
            wav, sr = torchaudio.load(audio_path)
            
            return {
                "duration": float(wav.shape[-1] / sr),
                "sample_rate": int(sr),
                "channels": int(wav.shape[0]),
                "file_size": os.path.getsize(audio_path),
                "format": Path(audio_path).suffix.lower(),
                "device_used": self.device
            }
        except Exception as e:
            logger.error(f"❌ 오디오 정보 추출 실패: {e}")
            raise
    
    def get_available_models(self) -> List[str]:
        """
        사용 가능한 Demucs 모델 목록을 반환합니다.
        
        Returns:
            List[str]: 사용 가능한 모델 이름들
        """
        try:
            return pretrained.list_models()
        except Exception as e:
            logger.error(f"❌ 모델 목록 조회 실패: {e}")
            return ["htdemucs", "htdemucs_ft", "hdemucs_mmi"]  # 기본 목록

# 사용 예시 및 테스트 함수
def test_vocal_separation():
    """
    보컬 분리 기능을 테스트하는 함수
    """
    # 테스트 파일 경로 (실제 파일로 교체 필요)
    test_input = "test_audio.mp3"  # 테스트용 음악 파일
    test_output = "output"  # 출력 디렉토리
    
    # 테스트 파일이 존재하는지 확인
    if not os.path.exists(test_input):
        print(f"⚠️ 테스트 파일이 없습니다: {test_input}")
        print("실제 음악 파일을 준비하고 경로를 수정해주세요.")
        return
    
    try:
        # 보컬 분리기 생성
        separator = VocalSeparator("htdemucs")
        
        # 사용 가능한 모델 출력
        models = separator.get_available_models()
        print(f"🤖 사용 가능한 모델들: {models}")
        
        # 오디오 정보 출력
        audio_info = separator.get_audio_info(test_input)
        print(f"📊 오디오 정보:")
        print(f"   재생시간: {audio_info['duration']:.2f}초")
        print(f"   샘플레이트: {audio_info['sample_rate']:,}Hz")
        print(f"   채널: {audio_info['channels']}")
        print(f"   파일크기: {audio_info['file_size']:,} bytes")
        print(f"   처리 디바이스: {audio_info['device_used']}")
        
        # 보컬 분리 실행
        result = separator.separate_audio(test_input, test_output)
        
        print(f"\n🎵 분리 결과:")
        for instrument, path in result.items():
            file_size = os.path.getsize(path)
            print(f"   {instrument}: {path} ({file_size:,} bytes)")
            
    except Exception as e:
        print(f"❌ 테스트 실패: {e}")

if __name__ == "__main__":
    """
    스크립트 직접 실행 시 테스트 함수 호출
    """
    print("🎵 보컬 분리 알고리즘 테스트 시작 (Demucs)")
    test_vocal_separation() 