"""
음성 파일에서 피치(F0) 추출 및 분석 모듈 - Task 9.1
YIN 및 Piptrack 알고리즘을 사용한 기본 주파수 추출, 음역대 분석, 피치 안정성 측정 기능 제공
"""

import numpy as np
import librosa
import librosa.display
import matplotlib.pyplot as plt
from typing import Dict, Tuple, Optional, Union
import json
from pathlib import Path
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class PitchAnalyzer:
    """음성 파일의 피치 분석을 위한 클래스"""
    
    def __init__(self, sample_rate: int = 22050, hop_length: int = 512):
        """
        피치 분석기 초기화
        
        Args:
            sample_rate: 오디오 샘플링 레이트
            hop_length: 프레임 간 간격
        """
        self.sample_rate = sample_rate
        self.hop_length = hop_length
        self.frame_length = hop_length * 4  # 프레임 길이
        
        # 음악적 기준 주파수들 (Hz)
        self.note_frequencies = {
            'C2': 65.41, 'C#2': 69.30, 'D2': 73.42, 'D#2': 77.78, 'E2': 82.41,
            'F2': 87.31, 'F#2': 92.50, 'G2': 98.00, 'G#2': 103.83, 'A2': 110.00,
            'A#2': 116.54, 'B2': 123.47,
            'C3': 130.81, 'C#3': 138.59, 'D3': 146.83, 'D#3': 155.56, 'E3': 164.81,
            'F3': 174.61, 'F#3': 185.00, 'G3': 196.00, 'G#3': 207.65, 'A3': 220.00,
            'A#3': 233.08, 'B3': 246.94,
            'C4': 261.63, 'C#4': 277.18, 'D4': 293.66, 'D#4': 311.13, 'E4': 329.63,
            'F4': 349.23, 'F#4': 369.99, 'G4': 392.00, 'G#4': 415.30, 'A4': 440.00,
            'A#4': 466.16, 'B4': 493.88,
            'C5': 523.25, 'C#5': 554.37, 'D5': 587.33, 'D#5': 622.25, 'E5': 659.25,
            'F5': 698.46, 'F#5': 739.99, 'G5': 783.99, 'G#5': 830.61, 'A5': 880.00,
            'A#5': 932.33, 'B5': 987.77,
            'C6': 1046.50
        }
    
    def load_audio(self, file_path: Union[str, Path]) -> Tuple[np.ndarray, int]:
        """
        오디오 파일을 로드합니다.
        
        Args:
            file_path: 오디오 파일 경로
            
        Returns:
            (audio_data, sample_rate): 오디오 데이터와 샘플링 레이트
        """
        try:
            audio, sr = librosa.load(file_path, sr=self.sample_rate)
            logger.info(f"오디오 로드 완료: {file_path}, 길이: {len(audio)/sr:.2f}초")
            return audio, sr
        except Exception as e:
            logger.error(f"오디오 로드 실패: {e}")
            raise
    
    def extract_f0_yin(self, audio: np.ndarray, fmin: float = 80.0, fmax: float = 800.0) -> np.ndarray:
        """
        YIN 알고리즘을 사용하여 F0를 추출합니다.
        
        Args:
            audio: 오디오 신호
            fmin: 최소 주파수 (Hz)
            fmax: 최대 주파수 (Hz)
            
        Returns:
            f0: 기본 주파수 배열
        """
        try:
            f0 = librosa.yin(
                audio,
                fmin=fmin,
                fmax=fmax,
                sr=self.sample_rate,
                hop_length=self.hop_length,
                frame_length=self.frame_length
            )
            logger.info(f"YIN 알고리즘으로 F0 추출 완료: {len(f0)} 프레임")
            return f0
        except Exception as e:
            logger.error(f"F0 추출 실패: {e}")
            raise
    
    def extract_f0_piptrack(self, audio: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """
        Piptrack 알고리즘을 사용하여 F0와 magnitude를 추출합니다.
        
        Args:
            audio: 오디오 신호
            
        Returns:
            (f0, magnitudes): 기본 주파수와 크기 배열
        """
        try:
            # STFT 계산
            stft = librosa.stft(audio, hop_length=self.hop_length)
            
            # Piptrack으로 피치 추출
            pitches, magnitudes = librosa.piptrack(
                S=np.abs(stft),
                sr=self.sample_rate,
                hop_length=self.hop_length,
                threshold=0.1,
                ref=np.max
            )
            
            # 가장 강한 피치 선택
            f0 = []
            for t in range(pitches.shape[1]):
                index = magnitudes[:, t].argmax()
                pitch = pitches[index, t]
                f0.append(pitch if pitch > 0 else 0)
            
            f0 = np.array(f0)
            logger.info(f"Piptrack으로 F0 추출 완료: {len(f0)} 프레임")
            return f0, magnitudes
        except Exception as e:
            logger.error(f"Piptrack F0 추출 실패: {e}")
            raise
    
    def smooth_f0(self, f0: np.ndarray, window_size: int = 5) -> np.ndarray:
        """
        F0 신호를 스무딩합니다.
        
        Args:
            f0: 기본 주파수 배열
            window_size: 스무딩 윈도우 크기
            
        Returns:
            smoothed_f0: 스무딩된 F0 배열
        """
        # 0이 아닌 값들만 스무딩
        smoothed_f0 = f0.copy()
        valid_indices = f0 > 0
        
        if np.sum(valid_indices) > window_size:
            # 이동 평균 필터 적용
            kernel = np.ones(window_size) / window_size
            smoothed_values = np.convolve(f0[valid_indices], kernel, mode='same')
            smoothed_f0[valid_indices] = smoothed_values
        
        return smoothed_f0
    
    def analyze_pitch_range(self, f0: np.ndarray) -> Dict:
        """
        음역대를 분석합니다.
        
        Args:
            f0: 기본 주파수 배열
            
        Returns:
            음역대 분석 결과
        """
        valid_f0 = f0[f0 > 0]
        
        if len(valid_f0) < 2:
            return {'error': 'Not enough valid frequency data'}
        
        # 1. 전체 물리적 범위 (참고용)
        total_min = np.min(valid_f0)
        total_max = np.max(valid_f0)
        total_range_semitones = 12 * np.log2(total_max / total_min)
        
        # 2. 편안한 발성 구간 분석 (상하위 10% 제외) - 기존 방식
        percentile_10 = np.percentile(valid_f0, 10)
        percentile_90 = np.percentile(valid_f0, 90)
        comfortable_range_semitones = 12 * np.log2(percentile_90 / percentile_10)
        
        # 3. 핵심 발성 구간 (상하위 25% 제외 - 가장 자주 사용) - 기존 방식
        percentile_25 = np.percentile(valid_f0, 25)
        percentile_75 = np.percentile(valid_f0, 75)
        core_range_semitones = 12 * np.log2(percentile_75 / percentile_25)
        
        # 4. 안정성 기반 분석 (새로운 방식)
        stability_analysis = self._analyze_frequency_stability(valid_f0)
        stability_ranges = self._analyze_stability_based_ranges(valid_f0)
        
        # 5. 통계적 정보
        mean_freq = np.mean(valid_f0)
        median_freq = np.median(valid_f0)
        std_freq = np.std(valid_f0)
        
        # 6. 음표 변환
        total_min_note = self.freq_to_note(float(total_min))
        total_max_note = self.freq_to_note(float(total_max))
        comfortable_min_note = self.freq_to_note(float(percentile_10))
        comfortable_max_note = self.freq_to_note(float(percentile_90))
        core_min_note = self.freq_to_note(float(percentile_25))
        core_max_note = self.freq_to_note(float(percentile_75))
        mean_note = self.freq_to_note(float(mean_freq))
        
        return {
            # 전체 물리적 범위 (참고용)
            'total_range': {
                'min_freq': float(total_min),
                'max_freq': float(total_max),
                'min_note': total_min_note,
                'max_note': total_max_note,
                'range_semitones': float(total_range_semitones),
                'description': '물리적 최대 음역대 (극한값 포함)'
            },
            
            # 편안한 발성 구간 (기존 시간 기반 방식)
            'comfortable_range': {
                'min_freq': float(percentile_10),
                'max_freq': float(percentile_90),
                'min_note': comfortable_min_note,
                'max_note': comfortable_max_note,
                'range_semitones': float(comfortable_range_semitones),
                'description': '안정적으로 발성 가능한 구간 (상하위 10% 제외 - 시간 기준)'
            },
            
            # 핵심 발성 구간 (기존 시간 기반 방식)
            'core_range': {
                'min_freq': float(percentile_25),
                'max_freq': float(percentile_75),
                'min_note': core_min_note,
                'max_note': core_max_note,
                'range_semitones': float(core_range_semitones),
                'description': '가장 자주 사용하는 음역대 (중간 50% - 시간 기준)'
            },
            
            # 안정성 기반 편안한 구간 (새로운 방식)
            'stability_comfortable_range': stability_ranges['stability_comfortable_range'],
            
            # 안정성 기반 핵심 구간 (새로운 방식) 
            'stability_core_range': stability_ranges['stability_core_range'],
            
            # 중심 음역대 정보
            'central_pitch': {
                'mean_freq': float(mean_freq),
                'median_freq': float(median_freq),
                'mean_note': mean_note,
                'std_freq': float(std_freq),
                'description': '가장 편안한 발성 위치'
            },
            
            # 안정성 정보
            'stability_analysis': stability_analysis,
            
            # 상세 안정성 구간 정보
            'detailed_stability_regions': stability_ranges['detailed_stability_regions'],
            
            # 기본 통계
            'statistics': {
                'valid_frames': len(valid_f0),
                'total_frames': len(f0),
                'voice_ratio': len(valid_f0) / len(f0),
                'frequency_distribution': self._analyze_frequency_distribution(valid_f0)
            }
        }
    
    def freq_to_note(self, freq: float) -> str:
        """
        주파수를 가장 가까운 음표로 변환합니다.
        
        Args:
            freq: 주파수 (Hz)
            
        Returns:
            가장 가까운 음표명
        """
        if freq <= 0:
            return 'N/A'
        
        min_diff = float('inf')
        closest_note = 'N/A'
        
        for note, note_freq in self.note_frequencies.items():
            diff = abs(freq - note_freq)
            if diff < min_diff:
                min_diff = diff
                closest_note = note
        
        return closest_note
    
    def _analyze_frequency_stability(self, valid_f0: np.ndarray) -> Dict:
        """
        주파수별 안정성을 분석합니다.
        
        Args:
            valid_f0: 유효한 F0 배열
            
        Returns:
            주파수 구간별 안정성 분석 결과
        """
        if len(valid_f0) < 10:
            return {
                'stable_range': {'min_freq': 0, 'max_freq': 0},
                'unstable_regions': [],
                'overall_stability': 0
            }
        
        # 주파수를 구간별로 나누어 안정성 분석
        freq_bins = np.histogram_bin_edges(valid_f0, bins=20)
        stability_scores = []
        
        for i in range(len(freq_bins) - 1):
            bin_mask = (valid_f0 >= freq_bins[i]) & (valid_f0 < freq_bins[i + 1])
            bin_freqs = valid_f0[bin_mask]
            
            if len(bin_freqs) > 3:  # 충분한 데이터가 있는 구간만
                # 해당 구간의 변동성 계산 (낮을수록 안정)
                variability = np.std(bin_freqs) / np.mean(bin_freqs) * 100
                stability_scores.append({
                    'freq_range': (float(freq_bins[i]), float(freq_bins[i + 1])),
                    'stability': float(100 - min(variability, 100)),  # 100점 만점
                    'sample_count': len(bin_freqs)
                })
        
        # 가장 안정적인 구간 찾기 (70점 이상)
        stable_regions = [s for s in stability_scores if s['stability'] > 70 and s['sample_count'] > 5]
        
        if stable_regions:
            stable_freqs = [s['freq_range'] for s in stable_regions]
            stable_min = min(f[0] for f in stable_freqs)
            stable_max = max(f[1] for f in stable_freqs)
        else:
            stable_min = stable_max = 0
        
        # 불안정한 구간 (50점 이하)
        unstable_regions = [s for s in stability_scores if s['stability'] < 50]
        
        # 전체 안정성 점수
        if stability_scores:
            overall_stability = np.mean([s['stability'] for s in stability_scores])
        else:
            overall_stability = 0
        
        return {
            'stable_range': {
                'min_freq': float(stable_min),
                'max_freq': float(stable_max),
                'min_note': self.freq_to_note(stable_min) if stable_min > 0 else 'N/A',
                'max_note': self.freq_to_note(stable_max) if stable_max > 0 else 'N/A'
            },
            'unstable_regions': unstable_regions,
            'overall_stability': float(overall_stability),
            'detailed_analysis': stability_scores
        }
    
    def _analyze_frequency_distribution(self, valid_f0: np.ndarray) -> Dict:
        """
        주파수 분포를 분석합니다.
        
        Args:
            valid_f0: 유효한 F0 배열
            
        Returns:
            주파수 분포 분석 결과
        """
        if len(valid_f0) == 0:
            return {'distribution_type': 'empty', 'peak_frequency': 0}
        
        # 히스토그램 생성
        counts, bin_edges = np.histogram(valid_f0, bins=30)
        bin_centers = (bin_edges[:-1] + bin_edges[1:]) / 2
        
        # 가장 자주 사용되는 주파수 (모드)
        peak_idx = np.argmax(counts)
        peak_frequency = float(bin_centers[peak_idx])
        
        # 분포 형태 분석
        mean_freq = np.mean(valid_f0)
        median_freq = np.median(valid_f0)
        
        if abs(mean_freq - median_freq) < np.std(valid_f0) * 0.1:
            distribution_type = 'normal'  # 정규분포에 가까움
        elif mean_freq > median_freq:
            distribution_type = 'low_skewed'  # 낮은 음이 많음
        else:
            distribution_type = 'high_skewed'  # 높은 음이 많음
        
        return {
            'distribution_type': distribution_type,
            'peak_frequency': peak_frequency,
            'peak_note': self.freq_to_note(peak_frequency),
            'usage_concentration': float(np.max(counts) / np.sum(counts) * 100)  # 특정 음역 집중도
        }
    
    def analyze_pitch_stability(self, f0: np.ndarray) -> Dict:
        """
        피치 안정성을 분석합니다.
        
        Args:
            f0: 추출된 기본 주파수 배열
            
        Returns:
            피치 안정성 분석 결과
        """
        valid_f0 = f0[f0 > 0]
        
        if len(valid_f0) < 2:
            return {
                'jitter': 0, 'shimmer': 0, 'stability_score': 0,
                'vibrato_rate': 0, 'vibrato_extent': 0
            }
        
        # Jitter 계산 (주기 간 변화율)
        f0_diff = np.diff(valid_f0)
        jitter = np.mean(np.abs(f0_diff)) / np.mean(valid_f0) * 100
        
        # Shimmer 계산 (진폭 변화율) - 간접적으로 F0 변화로 추정
        shimmer = np.std(f0_diff) / np.mean(valid_f0) * 100
        
        # 안정성 점수 (낮을수록 안정)
        stability_score = np.std(valid_f0) / np.mean(valid_f0) * 100
        
        # 비브라토 분석 (간단한 주기 검출)
        vibrato_rate = 0
        vibrato_extent = 0
        
        if len(valid_f0) > 100:  # 충분한 데이터가 있을 때만
            # 자기상관을 통한 주기 검출
            autocorr = np.correlate(f0_diff, f0_diff, mode='full')
            autocorr = autocorr[autocorr.size // 2:]
            
            # 피크 검출로 비브라토 주기 찾기
            peaks = []
            for i in range(1, min(50, len(autocorr) - 1)):  # 최대 50프레임까지만 검사
                if autocorr[i] > autocorr[i-1] and autocorr[i] > autocorr[i+1]:
                    peaks.append((i, autocorr[i]))
            
            if peaks:
                # 가장 강한 피크로 비브라토 율 계산
                vibrato_period = max(peaks, key=lambda x: x[1])[0]
                vibrato_rate = self.sample_rate / (vibrato_period * self.hop_length)  # Hz
                vibrato_extent = np.max(valid_f0) - np.min(valid_f0)  # Hz

        return {
            'jitter': float(jitter),
            'shimmer': float(shimmer),
            'stability_score': float(stability_score),
            'vibrato_rate': float(vibrato_rate),
            'vibrato_extent': float(vibrato_extent)
        }
    
    def analyze_audio_file(self, file_path: Union[str, Path], method: str = 'yin') -> Dict:
        """
        오디오 파일을 전체적으로 분석합니다.
        
        Args:
            file_path: 오디오 파일 경로
            method: F0 추출 방법 ('yin' 또는 'piptrack')
            
        Returns:
            전체 분석 결과 딕셔너리
        """
        try:
            # 오디오 로드
            audio, sr = self.load_audio(file_path)
            
            # F0 추출
            if method == 'yin':
                f0 = self.extract_f0_yin(audio)
            elif method == 'piptrack':
                f0, _ = self.extract_f0_piptrack(audio)
            else:
                raise ValueError(f"지원하지 않는 방법: {method}")
            
            # F0 스무딩
            smoothed_f0 = self.smooth_f0(f0)
            
            # 시간 축 생성
            times = librosa.frames_to_time(
                np.arange(len(f0)),
                sr=self.sample_rate,
                hop_length=self.hop_length
            )
            
            # 음역대 분석
            pitch_range = self.analyze_pitch_range(smoothed_f0)
            
            # 피치 안정성 분석
            stability = self.analyze_pitch_stability(smoothed_f0)
            
            # 결과 종합
            result = {
                'file_info': {
                    'path': str(file_path),
                    'duration': float(len(audio) / sr),
                    'sample_rate': sr,
                    'method': method
                },
                'pitch_data': {
                    'times': times.tolist(),
                    'f0_raw': f0.tolist(),
                    'f0_smoothed': smoothed_f0.tolist()
                },
                'pitch_range': pitch_range,
                'stability': stability,
                'summary': {
                    'total_range_note': f"{pitch_range['total_range']['min_note']} - {pitch_range['total_range']['max_note']}",
                    'comfortable_range_note': f"{pitch_range['comfortable_range']['min_note']} - {pitch_range['comfortable_range']['max_note']}",
                    'core_range_note': f"{pitch_range['core_range']['min_note']} - {pitch_range['core_range']['max_note']}",
                    'vocal_range_hz': f"{pitch_range['total_range']['min_freq']:.1f} - {pitch_range['total_range']['max_freq']:.1f} Hz",
                    'comfortable_range_hz': f"{pitch_range['comfortable_range']['min_freq']:.1f} - {pitch_range['comfortable_range']['max_freq']:.1f} Hz",
                    'mean_pitch': f"{pitch_range['central_pitch']['mean_freq']:.1f} Hz ({pitch_range['central_pitch']['mean_note']})",
                    'total_range_semitones': f"{pitch_range['total_range']['range_semitones']:.1f} 반음",
                    'comfortable_range_semitones': f"{pitch_range['comfortable_range']['range_semitones']:.1f} 반음",
                    'core_range_semitones': f"{pitch_range['core_range']['range_semitones']:.1f} 반음",
                    'voice_activity': f"{pitch_range['statistics']['voice_ratio']*100:.1f}%",
                    'stability_rating': self._get_stability_rating(
                        stability['stability_score'], 
                        stability['jitter'], 
                        stability['shimmer']
                    ),
                    'recommended_range': f"편안한 구간: {pitch_range['comfortable_range']['min_note']} - {pitch_range['comfortable_range']['max_note']}"
                }
            }
            
            logger.info(f"분석 완료: {file_path}")
            return result
            
        except Exception as e:
            logger.error(f"분석 실패: {e}")
            raise
    
    def _get_stability_rating(self, stability_score: float, jitter: float = 0, shimmer: float = 0) -> str:
        """
        안정성 점수를 등급으로 변환 (음성학적 기준 적용)
        
        Args:
            stability_score: 피치 변동성 점수
            jitter: 지터 값 (%)
            shimmer: 셰머 값 (%)
        """
        # 지터 기반 평가 (음성학적 기준)
        jitter_score = 0
        if jitter < 1.0:
            jitter_score = 5  # 우수
        elif jitter < 2.0:
            jitter_score = 4  # 양호
        elif jitter < 5.0:
            jitter_score = 3  # 보통
        elif jitter < 8.0:
            jitter_score = 2  # 약간 불안정
        else:
            jitter_score = 1  # 불안정
        
        # 셰머 기반 평가 (음성학적 기준)
        shimmer_score = 0
        if shimmer < 3.0:
            shimmer_score = 5  # 우수
        elif shimmer < 6.0:
            shimmer_score = 4  # 양호
        elif shimmer < 12.0:
            shimmer_score = 3  # 보통
        elif shimmer < 20.0:
            shimmer_score = 2  # 약간 불안정
        else:
            shimmer_score = 1  # 불안정
        
        # 안정성 점수 기반 평가 (더 관대한 기준)
        stability_base_score = 0
        if stability_score < 15:
            stability_base_score = 5  # 매우 안정
        elif stability_score < 25:
            stability_base_score = 4  # 안정
        elif stability_score < 40:
            stability_base_score = 3  # 보통
        elif stability_score < 60:
            stability_base_score = 2  # 약간 불안정
        else:
            stability_base_score = 1  # 불안정
        
        # 종합 점수 (가중 평균)
        total_score = (jitter_score * 0.3 + shimmer_score * 0.3 + stability_base_score * 0.4)
        
        if total_score >= 4.5:
            return "매우 안정 (우수)"
        elif total_score >= 3.5:
            return "안정 (양호)"
        elif total_score >= 2.5:
            return "보통"
        elif total_score >= 1.5:
            return "약간 불안정"
        else:
            return "불안정"
    
    def save_analysis(self, result: Dict, output_path: Union[str, Path]) -> None:
        """
        분석 결과를 JSON 파일로 저장합니다.
        
        Args:
            result: 분석 결과
            output_path: 저장할 파일 경로
        """
        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(result, f, ensure_ascii=False, indent=2)
            logger.info(f"분석 결과 저장 완료: {output_path}")
        except Exception as e:
            logger.error(f"결과 저장 실패: {e}")
            raise
    
    def plot_pitch_analysis(self, result: Dict, output_path: Union[str, Path] = None) -> None:
        """
        피치 분석 결과를 시각화합니다.
        
        Args:
            result: 분석 결과
            output_path: 그래프 저장 경로 (선택사항)
        """
        try:
            plt.figure(figsize=(15, 10))
            
            times = np.array(result['pitch_data']['times'])
            f0_raw = np.array(result['pitch_data']['f0_raw'])
            f0_smoothed = np.array(result['pitch_data']['f0_smoothed'])
            
            # 서브플롯 1: 원본 F0
            plt.subplot(3, 1, 1)
            valid_mask = f0_raw > 0
            plt.plot(times[valid_mask], f0_raw[valid_mask], 'b.', alpha=0.3, label='원본 F0')
            plt.ylabel('주파수 (Hz)')
            plt.title(f"피치 분석 결과 - {Path(result['file_info']['path']).name}")
            plt.legend()
            plt.grid(True, alpha=0.3)
            
            # 서브플롯 2: 스무딩된 F0
            plt.subplot(3, 1, 2)
            valid_mask_smooth = f0_smoothed > 0
            plt.plot(times[valid_mask_smooth], f0_smoothed[valid_mask_smooth], 'r-', linewidth=2, label='스무딩된 F0')
            
            # 음역대 표시
            pitch_range = result['pitch_range']
            plt.axhline(y=pitch_range['min_freq'], color='g', linestyle='--', alpha=0.7, label=f"최저음: {pitch_range['min_note']}")
            plt.axhline(y=pitch_range['max_freq'], color='orange', linestyle='--', alpha=0.7, label=f"최고음: {pitch_range['max_note']}")
            plt.axhline(y=pitch_range['mean_freq'], color='purple', linestyle=':', alpha=0.7, label=f"평균음: {pitch_range['mean_freq']:.1f}Hz")
            
            plt.ylabel('주파수 (Hz)')
            plt.legend()
            plt.grid(True, alpha=0.3)
            
            # 서브플롯 3: 통계 정보
            plt.subplot(3, 1, 3)
            plt.text(0.1, 0.8, f"음역대: {result['summary']['vocal_range_note']} ({result['summary']['range_semitones']})", fontsize=12, transform=plt.gca().transAxes)
            plt.text(0.1, 0.6, f"평균 피치: {result['summary']['mean_pitch']}", fontsize=12, transform=plt.gca().transAxes)
            plt.text(0.1, 0.4, f"음성 활동: {result['summary']['voice_activity']}", fontsize=12, transform=plt.gca().transAxes)
            plt.text(0.1, 0.2, f"안정성: {result['summary']['stability_rating']}", fontsize=12, transform=plt.gca().transAxes)
            
            stability = result['stability']
            plt.text(0.6, 0.8, f"지터: {stability['jitter']:.2f}%", fontsize=12, transform=plt.gca().transAxes)
            plt.text(0.6, 0.6, f"셰머: {stability['shimmer']:.2f}%", fontsize=12, transform=plt.gca().transAxes)
            plt.text(0.6, 0.4, f"비브라토: {stability['vibrato_rate']:.1f}Hz", fontsize=12, transform=plt.gca().transAxes)
            
            plt.axis('off')
            plt.xlabel('시간 (초)')
            
            plt.tight_layout()
            
            if output_path:
                plt.savefig(output_path, dpi=300, bbox_inches='tight')
                logger.info(f"그래프 저장 완료: {output_path}")
            else:
                plt.show()
            
        except Exception as e:
            logger.error(f"시각화 실패: {e}")
            raise

    def _analyze_stability_based_ranges(self, valid_f0: np.ndarray) -> Dict:
        """
        안정성 기반으로 편안한 구간과 핵심 구간을 계산합니다.
        
        Args:
            valid_f0: 유효한 F0 배열
            
        Returns:
            안정성 기반 음역대 분석 결과
        """
        if len(valid_f0) < 10:
            return {
                'stability_comfortable_range': {'min_freq': 0, 'max_freq': 0, 'stability_score': 0},
                'stability_core_range': {'min_freq': 0, 'max_freq': 0, 'stability_score': 0}
            }

        # 주파수를 더 세밀하게 나누어 안정성 분석
        freq_bins = np.histogram_bin_edges(valid_f0, bins=30)
        stability_regions = []
        
        for i in range(len(freq_bins) - 1):
            bin_mask = (valid_f0 >= freq_bins[i]) & (valid_f0 < freq_bins[i + 1])
            bin_freqs = valid_f0[bin_mask]
            
            if len(bin_freqs) > 5:  # 충분한 데이터가 있는 구간만
                # 안정성 점수 계산 (변동계수의 역수)
                mean_freq = np.mean(bin_freqs)
                std_freq = np.std(bin_freqs)
                cv = std_freq / mean_freq if mean_freq > 0 else float('inf')
                
                # 안정성 점수 (0-100, 높을수록 안정)
                stability_score = max(0.0, 100.0 - float(cv * 1000))
                
                # 사용 빈도도 고려 (더 많이 사용된 구간에 가산점)
                usage_weight = len(bin_freqs) / len(valid_f0) * 100
                weighted_stability = stability_score * (1 + usage_weight / 100)
                
                stability_regions.append({
                    'freq_range': (float(freq_bins[i]), float(freq_bins[i + 1])),
                    'min_freq': float(freq_bins[i]),
                    'max_freq': float(freq_bins[i + 1]),
                    'stability_score': float(stability_score),
                    'weighted_stability': float(weighted_stability),
                    'sample_count': len(bin_freqs),
                    'usage_ratio': float(usage_weight)
                })
        
        if not stability_regions:
            return {
                'stability_comfortable_range': {'min_freq': 0, 'max_freq': 0, 'stability_score': 0},
                'stability_core_range': {'min_freq': 0, 'max_freq': 0, 'stability_score': 0}
            }
        
        # 안정성 점수로 정렬
        stability_regions.sort(key=lambda x: x['weighted_stability'], reverse=True)
        
        # 편안한 구간: 안정성 70점 이상이고 충분한 사용량이 있는 구간들
        comfortable_threshold = 70
        comfortable_regions = [
            r for r in stability_regions 
            if r['stability_score'] >= comfortable_threshold and r['sample_count'] >= len(valid_f0) * 0.01
        ]
        
        # 핵심 구간: 안정성 85점 이상이고 사용 빈도가 높은 구간들
        core_threshold = 85
        core_regions = [
            r for r in stability_regions 
            if r['stability_score'] >= core_threshold and r['usage_ratio'] >= 2.0
        ]
        
        # 편안한 구간 범위 계산
        if comfortable_regions:
            comfortable_freqs = []
            for region in comfortable_regions:
                comfortable_freqs.extend([region['min_freq'], region['max_freq']])
            comfortable_min = min(comfortable_freqs)
            comfortable_max = max(comfortable_freqs)
            comfortable_avg_stability = np.mean([r['stability_score'] for r in comfortable_regions])
        else:
            # 안정성 기준을 낮춰서 재시도
            comfortable_regions = stability_regions[:max(1, int(len(stability_regions)//3))]
            if comfortable_regions:
                comfortable_freqs = []
                for region in comfortable_regions:
                    comfortable_freqs.extend([region['min_freq'], region['max_freq']])
                comfortable_min = min(comfortable_freqs)
                comfortable_max = max(comfortable_freqs)
                comfortable_avg_stability = np.mean([r['stability_score'] for r in comfortable_regions])
            else:
                comfortable_min = comfortable_max = comfortable_avg_stability = 0
        
        # 핵심 구간 범위 계산
        if core_regions:
            core_freqs = []
            for region in core_regions:
                core_freqs.extend([region['min_freq'], region['max_freq']])
            core_min = min(core_freqs)
            core_max = max(core_freqs)
            core_avg_stability = np.mean([r['stability_score'] for r in core_regions])
        else:
            # 핵심 구간을 찾지 못하면 가장 안정적인 상위 20% 구간 사용
            top_regions = stability_regions[:max(1, int(len(stability_regions)//5))]
            if top_regions:
                core_freqs = []
                for region in top_regions:
                    core_freqs.extend([region['min_freq'], region['max_freq']])
                core_min = min(core_freqs)
                core_max = max(core_freqs)
                core_avg_stability = np.mean([r['stability_score'] for r in top_regions])
            else:
                core_min = core_max = core_avg_stability = 0
        
        return {
            'stability_comfortable_range': {
                'min_freq': float(comfortable_min),
                'max_freq': float(comfortable_max),
                'min_note': self.freq_to_note(comfortable_min) if comfortable_min > 0 else 'N/A',
                'max_note': self.freq_to_note(comfortable_max) if comfortable_max > 0 else 'N/A',
                'range_semitones': float(12 * np.log2(comfortable_max / comfortable_min)) if comfortable_min > 0 and comfortable_max > 0 else 0,
                'stability_score': float(comfortable_avg_stability),
                'description': f'안정성 기반 편안한 구간 (안정성: {comfortable_avg_stability:.1f}점)'
            },
            'stability_core_range': {
                'min_freq': float(core_min),
                'max_freq': float(core_max),
                'min_note': self.freq_to_note(core_min) if core_min > 0 else 'N/A',
                'max_note': self.freq_to_note(core_max) if core_max > 0 else 'N/A',
                'range_semitones': float(12 * np.log2(core_max / core_min)) if core_min > 0 and core_max > 0 else 0,
                'stability_score': float(core_avg_stability),
                'description': f'안정성 기반 핵심 구간 (안정성: {core_avg_stability:.1f}점)'
            },
            'detailed_stability_regions': stability_regions
        }

    def analyze_audio_file_simple(self, file_path: Union[str, Path], method: str = 'yin') -> Dict:
        """
        오디오 파일을 분석하여 4가지 핵심 항목만 반환합니다.
        
        Args:
            file_path: 오디오 파일 경로
            method: F0 추출 방법 ('yin' 또는 'piptrack')
            
        Returns:
            간단한 분석 결과 (4가지 항목)
        """
        try:
            # 기본 분석 실행
            full_result = self.analyze_audio_file(file_path, method)
            
            # 안정성 기반 음역대 분석
            audio, sr = self.load_audio(file_path)
            if method == 'yin':
                f0 = self.extract_f0_yin(audio)
            elif method == 'piptrack':
                f0, _ = self.extract_f0_piptrack(audio)
            else:
                raise ValueError(f"지원하지 않는 방법: {method}")
            
            smoothed_f0 = self.smooth_f0(f0)
            valid_f0 = smoothed_f0[smoothed_f0 > 0]
            
            if len(valid_f0) > 0:
                stability_ranges = self._analyze_stability_based_ranges(valid_f0)
            else:
                stability_ranges = {
                    'stability_comfortable_range': {'min_freq': 0, 'max_freq': 0, 'stability_score': 0},
                    'stability_core_range': {'min_freq': 0, 'max_freq': 0, 'stability_score': 0}
                }
            
            # 4가지 핵심 항목만 반환
            simple_result = {
                # 1. 지터/세버 데이터
                "stability": full_result['stability'],
                
                # 2. 안정성 기반 편안한 음역대
                "stability_comfortable_range": stability_ranges['stability_comfortable_range'],
                
                # 3. 안정성 기반 핵심 음역대
                "stability_core_range": stability_ranges['stability_core_range'],
                
                # 4. 종합 평가
                "summary": {
                    "stability_rating": full_result['summary']['stability_rating'],
                    "recommended_range": f"편안한 구간: {stability_ranges['stability_comfortable_range']['min_note']} - {stability_ranges['stability_comfortable_range']['max_note']}"
                }
            }
            
            logger.info(f"간단 분석 완료: {file_path}")
            return simple_result
            
        except Exception as e:
            logger.error(f"간단 분석 실패: {e}")
            raise


def main():
    """테스트용 메인 함수"""
    analyzer = PitchAnalyzer()
    
    # 테스트 파일 경로 (실제 파일로 교체 필요)
    test_file = "test_audio.wav"
    
    try:
        # 분석 실행
        result = analyzer.analyze_audio_file(test_file, method='yin')
        
        # 결과 출력
        print("=== 피치 분석 결과 ===")
        print(f"파일: {result['file_info']['path']}")
        print(f"길이: {result['file_info']['duration']:.2f}초")
        print(f"음역대: {result['summary']['vocal_range_note']}")
        print(f"음역대(Hz): {result['summary']['vocal_range_hz']}")
        print(f"평균 피치: {result['summary']['mean_pitch']}")
        print(f"음성 활동: {result['summary']['voice_activity']}")
        print(f"안정성: {result['summary']['stability_rating']}")
        
        # 결과 저장
        analyzer.save_analysis(result, "pitch_analysis_result.json")
        
        # 시각화
        analyzer.plot_pitch_analysis(result, "pitch_analysis_plot.png")
        
    except FileNotFoundError:
        print(f"테스트 파일을 찾을 수 없습니다: {test_file}")
        print("실제 오디오 파일 경로로 test_file 변수를 수정해주세요.")


if __name__ == "__main__":
    main() 