import numpy as np
import librosa
from typing import Dict, Tuple, Union
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

def load_audio(file_path: Union[str, Path], sr: int = 22050) -> Tuple[np.ndarray, float]:
    try:
        audio, sr = librosa.load(file_path, sr=sr)
        logger.info(f"오디오 로드 완료: {file_path}, 길이: {len(audio)/sr:.2f}초")
        return audio, sr
    except Exception as e:
        logger.error(f"오디오 로드 실패: {e}")
        raise

def extract_f0_yin(audio: np.ndarray, sr: int, hop_length: int, frame_length: int, fmin: float = 80.0, fmax: float = 800.0) -> np.ndarray:
    try:
        f0 = librosa.yin(
            audio,
            fmin=fmin,
            fmax=fmax,
            sr=sr,
            hop_length=hop_length,
            frame_length=frame_length
        )
        logger.info(f"YIN 알고리즘으로 F0 추출 완료: {len(f0)} 프레임")
        return f0
    except Exception as e:
        logger.error(f"F0 추출 실패: {e}")
        raise

# ... (추가적으로 analyze_pitch_range, analyze_pitch_stability 등 분석 함수도 이 파일에 분리) ... 