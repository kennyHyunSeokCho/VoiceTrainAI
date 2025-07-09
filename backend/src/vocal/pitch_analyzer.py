"""
음성 파일에서 피치(F0) 추출 및 분석 모듈 - Task 9.1
YIN 및 Piptrack 알고리즘을 사용한 기본 주파수 추출, 음역대 분석, 피치 안정성 측정 기능 제공
S3 연동 및 누적 프로필 관리 기능 포함
"""

import numpy as np
import librosa
import librosa.display
import matplotlib.pyplot as plt
from typing import Dict, Tuple, Optional, Union
import json
from pathlib import Path
import logging
from datetime import datetime
import os
import uuid
import boto3
import tempfile
import statistics

# 로깅 설정
logger = logging.getLogger(__name__)

class PitchAnalyzer:
    """음성 파일의 피치(F0)를 분석하고 S3 연동 및 누적 프로필을 관리하는 클래스"""
    
    def __init__(self, sr: int = 22050, hop_length: int = 512, 
                 aws_access_key_id: Optional[str] = None, aws_secret_access_key: Optional[str] = None,
                 bucket_name: Optional[str] = None, region_name: str = 'ap-northeast-2'):
        """
        PitchAnalyzer 초기화
        
        Args:
            sr: 샘플링 레이트 (기본값: 22050Hz)
            hop_length: 홉 길이 (기본값: 512)
            aws_access_key_id: AWS 액세스 키 ID (선택사항)
            aws_secret_access_key: AWS 시크릿 액세스 키 (선택사항)
            bucket_name: S3 버킷 이름 (선택사항)
            region_name: AWS 리전 (기본값: ap-northeast-2)
        """
        self.sr = sr
        self.hop_length = hop_length
        self.frame_length = hop_length * 4  # 일반적으로 hop_length의 4배
        
        # S3 클라이언트 설정 (선택사항)
        self.s3_client = None
        self.bucket_name = bucket_name
        if aws_access_key_id is not None and aws_secret_access_key is not None and bucket_name is not None:
            try:
                # 타입 체크 후 안전하게 사용
                assert aws_access_key_id is not None
                assert aws_secret_access_key is not None
                self.s3_client = boto3.client(
                    's3',
                    aws_access_key_id=aws_access_key_id,
                    aws_secret_access_key=aws_secret_access_key,
                    region_name=region_name
                )
                logger.info(f"S3 클라이언트 초기화 완료 - 버킷: {bucket_name}")
            except Exception as e:
                logger.warning(f"S3 클라이언트 초기화 실패: {e}")
        
        # 로컬 저장 디렉토리 설정
        self.local_save_dir = Path("analysis_results")
        self.local_save_dir.mkdir(exist_ok=True)
        
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
    
    def download_from_s3(self, s3_key: str, local_path: Optional[str] = None) -> Optional[str]:
        """
        S3에서 파일을 다운로드합니다.
        
        Args:
            s3_key: S3 파일 키 (예: "audio/user123/가요1_vocal.wav")
            local_path: 로컬 저장 경로 (선택사항)
            
        Returns:
            다운로드된 파일의 로컬 경로 (성공시) 또는 None (실패시)
        """
        if not self.s3_client or not self.bucket_name:
            logger.error("S3 클라이언트가 초기화되지 않았습니다.")
            return None
        
        try:
            # 로컬 경로가 지정되지 않으면 임시 파일 생성
            if local_path is None:
                temp_dir = tempfile.mkdtemp()
                file_name = Path(s3_key).name
                local_path = os.path.join(temp_dir, file_name)
            
            print(f"⬇️ S3에서 다운로드 중...")
            print(f"   S3 경로: s3://{self.bucket_name}/{s3_key}")
            print(f"   로컬 경로: {local_path}")
            
            # 로컬 디렉토리 생성
            os.makedirs(os.path.dirname(local_path), exist_ok=True)
            
            # S3에서 파일 다운로드
            self.s3_client.download_file(
                self.bucket_name,
                s3_key,
                local_path
            )
            
            # 파일 크기 확인
            file_size = os.path.getsize(local_path)
            print(f"✅ 다운로드 완료! 파일 크기: {file_size / (1024*1024):.1f}MB")
            
            return local_path
            
        except Exception as e:
            print(f"❌ S3 다운로드 실패: {str(e)}")
            logger.error(f"S3 다운로드 실패: {str(e)}")
            return None
    
    def analyze_s3_audio(self, s3_key: str, user_id: str, 
                        song_name: str = "", section: str = "전체",
                        method: str = 'yin', update_profile: bool = True) -> Optional[Dict]:
        """
        S3에서 오디오 파일을 다운로드하고 음역대 분석을 수행합니다.
        
        Args:
            s3_key: S3 파일 키 (예: "audio/user123/가요1_vocal.wav")
            user_id: 사용자 ID
            song_name: 곡명 (선택사항)
            section: 구간명 (선택사항)
            method: F0 추출 방법 ('yin' 또는 'piptrack')
            update_profile: 누적 프로필 업데이트 여부
            
        Returns:
            분석 결과 딕셔너리 (성공시) 또는 None (실패시)
        """
        temp_audio_path = None
        try:
            print(f"🎵 S3 오디오 분석 시작")
            print(f"   S3 키: {s3_key}")
            print(f"   사용자: {user_id}")
            print(f"   곡명: {song_name}")
            print(f"   구간: {section}")
            print(f"   방법: {method}")
            print("=" * 50)
            
            # 1. S3에서 오디오 파일 다운로드
            temp_audio_path = self.download_from_s3(s3_key)
            if not temp_audio_path:
                return None
            
            # 2. 음역대 분석 실행
            print(f"\n🔍 음역대 분석 시작...")
            analysis_result = self.analyze_and_save(
                temp_audio_path, 
                user_id, 
                song_name, 
                section, 
                method
            )
            
            if not analysis_result:
                print("❌ 음역대 분석 실패")
                return None
            
            # 3. S3 관련 메타데이터 추가
            analysis_result['metadata']['s3_info'] = {
                'bucket': self.bucket_name,
                's3_key': s3_key,
                'download_time': datetime.now().isoformat(),
                'temp_path': temp_audio_path
            }
            
            # 4. 누적 프로필 업데이트
            if update_profile:
                print(f"\n📊 누적 프로필 업데이트 중...")
                profile_result = self.update_accumulated_profile(user_id)
                if profile_result:
                    analysis_result['accumulated_profile'] = profile_result
                    print(f"✅ 누적 프로필 업데이트 완료")
            
            # 5. 분석 결과 요약 출력
            self._print_analysis_summary(analysis_result)
            
            return analysis_result
            
        except Exception as e:
            print(f"❌ S3 오디오 분석 실패: {str(e)}")
            logger.error(f"S3 오디오 분석 오류: {str(e)}")
            return None
            
        finally:
            # 임시 파일 정리
            if temp_audio_path and os.path.exists(temp_audio_path):
                try:
                    os.remove(temp_audio_path)
                    # 임시 디렉토리가 비어있으면 제거
                    temp_dir = os.path.dirname(temp_audio_path)
                    if os.path.exists(temp_dir) and not os.listdir(temp_dir):
                        os.rmdir(temp_dir)
                except Exception as e:
                    logger.warning(f"임시 파일 정리 실패: {str(e)}")
    
    def update_accumulated_profile(self, user_id: str) -> Optional[Dict]:
        """
        adaptive weight를 적용한 누적 프로필을 계산하고 로컬에 저장합니다.
        
        Args:
            user_id: 사용자 ID
            
        Returns:
            누적 프로필 데이터 (성공시) 또는 None (실패시)
        """
        try:
            print("\n📊 Adaptive Weight 누적 프로필 업데이트...")
            
            # 1. 사용자의 모든 분석 데이터 수집
            analysis_data = self._collect_user_analysis_data(user_id)
            
            if not analysis_data:
                print("❌ 분석 데이터를 찾을 수 없습니다.")
                return None
            
            print(f"📋 총 {len(analysis_data)}개의 분석 데이터 발견")
            
            # 2. Adaptive Weight 계산
            weighted_data = self._calculate_adaptive_weights(analysis_data)
            
            # 3. 누적 프로필 계산
            accumulated_profile = self._calculate_weighted_accumulated_profile(weighted_data)
            
            if not accumulated_profile:
                print("❌ 누적 프로필 계산 실패")
                return None
            
            # 4. 메타데이터 추가
            accumulated_profile['metadata'] = {
                'user_id': user_id,
                'last_updated': datetime.now().isoformat(),
                'total_analyses': len(analysis_data),
                'profile_type': 'adaptive_weighted_accumulated',
                'weight_strategy': 'time_stability_frequency'
            }
            
            # 5. 로컬에 누적 프로필 저장
            profile_path = self._save_profile_to_local(accumulated_profile, user_id)
            
            if profile_path:
                print(f"💾 누적 프로필 로컬 저장 완료: {profile_path}")
                accumulated_profile['local_profile_path'] = str(profile_path)
            
            # 6. 누적 프로필 요약 출력
            self._print_adaptive_profile_summary(accumulated_profile)
            
            return accumulated_profile
            
        except Exception as e:
            print(f"❌ 누적 프로필 업데이트 실패: {str(e)}")
            logger.error(f"누적 프로필 업데이트 오류: {str(e)}")
            return None
    
    def _collect_user_analysis_data(self, user_id: str) -> list:
        """
        사용자의 모든 분석 데이터를 수집합니다.
        
        Args:
            user_id: 사용자 ID
            
        Returns:
            분석 데이터 리스트
        """
        try:
            user_dir = self.local_save_dir / user_id
            if not user_dir.exists():
                return []
            
            analysis_data = []
            
            # JSON 파일들을 읽어서 분석 데이터 수집
            for json_file in user_dir.glob("*.json"):
                # 누적 프로필 파일은 제외
                if "accumulated_profile" in json_file.name:
                    continue
                    
                try:
                    with open(json_file, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                        
                        # 필요한 데이터만 추출
                        if all(key in data for key in ['metadata', 'pitch_range', 'stability']):
                            analysis_data.append({
                                'analysis_id': data['metadata']['analysis_id'],
                                'timestamp': data['metadata']['timestamp'],
                                'song_name': data['metadata']['song_name'],
                                'section': data['metadata']['section'],
                                'pitch_range': data['pitch_range'],
                                'stability': data['stability'],
                                'file_path': str(json_file)
                            })
                            
                except Exception as e:
                    logger.warning(f"분석 파일 읽기 실패: {json_file}, {str(e)}")
            
            # 시간순으로 정렬 (최신 순)
            analysis_data.sort(key=lambda x: x['timestamp'], reverse=True)
            
            return analysis_data
            
        except Exception as e:
            logger.error(f"분석 데이터 수집 실패: {str(e)}")
            return []
    
    def _calculate_adaptive_weights(self, analysis_data: list) -> list:
        """
        Adaptive Weight를 계산합니다.
        
        Args:
            analysis_data: 분석 데이터 리스트
            
        Returns:
            가중치가 적용된 데이터 리스트
        """
        try:
            current_time = datetime.now()
            weighted_data = []
            
            for i, data in enumerate(analysis_data):
                # 1. 시간 가중치 (최신일수록 높음)
                analysis_time = datetime.fromisoformat(data['timestamp'])
                days_ago = (current_time - analysis_time).days
                
                # 지수 감소 함수 적용 (30일 반감기)
                time_weight = 0.5 ** (days_ago / 30.0)
                
                # 2. 안정성 가중치 (안정성이 높을수록 높음)
                stability_score = data['stability']['stability_score']
                
                # 안정성 점수를 0-1 범위로 정규화 (낮을수록 안정함)
                # 안정성 점수가 낮을수록 가중치가 높음
                stability_weight = max(0.1, 1.0 - (stability_score / 100.0))
                
                # 3. 빈도 가중치 (분석 순서에 따른 가중치)
                # 최신 분석에 더 높은 가중치, 하지만 급격히 감소하지 않게
                frequency_weight = 1.0 / (1.0 + i * 0.1)
                
                # 4. 지터/셰머 기반 품질 가중치
                jitter = data['stability']['jitter']
                shimmer = data['stability']['shimmer']
                
                # 낮은 지터/셰머 값은 높은 품질을 의미
                jitter_weight = max(0.1, 1.0 - (jitter / 10.0))  # 10% 지터를 최대로 가정
                shimmer_weight = max(0.1, 1.0 - (shimmer / 20.0))  # 20% 셰머를 최대로 가정
                
                quality_weight = (jitter_weight + shimmer_weight) / 2.0
                
                # 5. 종합 가중치 계산
                combined_weight = (
                    time_weight * 0.3 +           # 시간 가중치 30%
                    stability_weight * 0.25 +     # 안정성 가중치 25%
                    frequency_weight * 0.2 +      # 빈도 가중치 20%
                    quality_weight * 0.25         # 품질 가중치 25%
                )
                
                # 최소 가중치 보장
                combined_weight = max(0.05, combined_weight)
                
                weighted_data.append({
                    **data,
                    'weights': {
                        'time_weight': time_weight,
                        'stability_weight': stability_weight,
                        'frequency_weight': frequency_weight,
                        'quality_weight': quality_weight,
                        'combined_weight': combined_weight
                    },
                    'days_ago': days_ago
                })
            
            # 가중치로 정렬 (높은 가중치 순)
            weighted_data.sort(key=lambda x: x['weights']['combined_weight'], reverse=True)
            
            return weighted_data
            
        except Exception as e:
            logger.error(f"가중치 계산 실패: {str(e)}")
            return []
    
    def _calculate_weighted_accumulated_profile(self, weighted_data: list) -> Optional[Dict]:
        """
        가중치가 적용된 누적 프로필을 계산합니다.
        
        Args:
            weighted_data: 가중치가 적용된 데이터 리스트
            
        Returns:
            누적 프로필 딕셔너리
        """
        try:
            if not weighted_data:
                return None
            
            # 가중치 합계 계산
            total_weight = sum(data['weights']['combined_weight'] for data in weighted_data)
            
            if total_weight == 0:
                return None
            
            # 1. 편안한 음역대 가중 평균
            comfortable_min_freqs = []
            comfortable_max_freqs = []
            comfortable_weights = []
            
            # 2. 핵심 음역대 가중 평균
            core_min_freqs = []
            core_max_freqs = []
            core_weights = []
            
            # 3. 안정성 지표 가중 평균
            stability_scores = []
            jitter_scores = []
            shimmer_scores = []
            stability_weights = []
            
            for data in weighted_data:
                weight = data['weights']['combined_weight']
                
                # 편안한 음역대 데이터 수집
                comfortable_range = data['pitch_range']['comfortable_range']
                comfortable_min_freqs.append(comfortable_range['min_freq'])
                comfortable_max_freqs.append(comfortable_range['max_freq'])
                comfortable_weights.append(weight)
                
                # 핵심 음역대 데이터 수집
                core_range = data['pitch_range']['core_range']
                core_min_freqs.append(core_range['min_freq'])
                core_max_freqs.append(core_range['max_freq'])
                core_weights.append(weight)
                
                # 안정성 데이터 수집
                stability = data['stability']
                stability_scores.append(stability['stability_score'])
                jitter_scores.append(stability['jitter'])
                shimmer_scores.append(stability['shimmer'])
                stability_weights.append(weight)
            
            # 가중 평균 계산
            def weighted_average(values, weights):
                return sum(v * w for v, w in zip(values, weights)) / sum(weights)
            
            # 편안한 음역대 가중 평균
            comfortable_min_avg = weighted_average(comfortable_min_freqs, comfortable_weights)
            comfortable_max_avg = weighted_average(comfortable_max_freqs, comfortable_weights)
            
            # 핵심 음역대 가중 평균
            core_min_avg = weighted_average(core_min_freqs, core_weights)
            core_max_avg = weighted_average(core_max_freqs, core_weights)
            
            # 안정성 지표 가중 평균
            stability_avg = weighted_average(stability_scores, stability_weights)
            jitter_avg = weighted_average(jitter_scores, stability_weights)
            shimmer_avg = weighted_average(shimmer_scores, stability_weights)
            
            # 누적 프로필 구성
            accumulated_profile = {
                'vocal_profile': {
                    'comfortable_range': {
                        'min_freq': float(comfortable_min_avg),
                        'max_freq': float(comfortable_max_avg),
                        'min_note': self.freq_to_note(comfortable_min_avg),
                        'max_note': self.freq_to_note(comfortable_max_avg),
                        'range_semitones': float(12 * np.log2(comfortable_max_avg / comfortable_min_avg)) if comfortable_min_avg > 0 else 0
                    },
                    'core_range': {
                        'min_freq': float(core_min_avg),
                        'max_freq': float(core_max_avg),
                        'min_note': self.freq_to_note(core_min_avg),
                        'max_note': self.freq_to_note(core_max_avg),
                        'range_semitones': float(12 * np.log2(core_max_avg / core_min_avg)) if core_min_avg > 0 else 0
                    },
                    'stability_profile': {
                        'average_stability_score': float(stability_avg),
                        'average_jitter': float(jitter_avg),
                        'average_shimmer': float(shimmer_avg),
                        'confidence_level': self._calculate_confidence_level(weighted_data)
                    },
                    'analysis_summary': {
                        'total_analyses': len(weighted_data),
                        'most_recent_analysis': weighted_data[0]['timestamp'],
                        'oldest_analysis': weighted_data[-1]['timestamp'],
                        'average_weight': float(total_weight / len(weighted_data)),
                        'weight_distribution': self._calculate_weight_distribution(weighted_data)
                    }
                }
            }
            
            return accumulated_profile
            
        except Exception as e:
            logger.error(f"누적 프로필 계산 실패: {str(e)}")
            return None
    
    def _calculate_confidence_level(self, weighted_data: list) -> float:
        """
        누적 프로필의 신뢰도를 계산합니다.
        
        Args:
            weighted_data: 가중치가 적용된 데이터 리스트
            
        Returns:
            신뢰도 점수 (0-100)
        """
        try:
            if not weighted_data:
                return 0.0
            
            # 1. 데이터 수량 점수 (많을수록 높음)
            data_count = len(weighted_data)
            quantity_score = min(100, data_count * 10)  # 10개 이상이면 100점
            
            # 2. 시간 분포 점수 (고르게 분포할수록 높음)
            time_distribution_score = 50.0  # 기본값
            if len(weighted_data) > 1:
                days_ago_list = [data['days_ago'] for data in weighted_data]
                if len(set(days_ago_list)) > 1:
                    time_std = statistics.stdev(days_ago_list)
                    time_distribution_score = min(100.0, time_std * 2)
            
            # 3. 안정성 일관성 점수
            stability_consistency_score = 50.0  # 기본값
            if len(weighted_data) > 1:
                stability_scores = [data['stability']['stability_score'] for data in weighted_data]
                stability_std = statistics.stdev(stability_scores)
                stability_consistency_score = max(0.0, 100.0 - stability_std)
            
            # 4. 가중치 분포 점수
            weight_distribution_score = 50.0  # 기본값
            if len(weighted_data) > 1:
                weights = [data['weights']['combined_weight'] for data in weighted_data]
                weight_std = statistics.stdev(weights)
                weight_mean = statistics.mean(weights)
                cv = weight_std / weight_mean if weight_mean > 0 else 0
                
                if 0.3 <= cv <= 0.7:
                    weight_distribution_score = 100.0
                elif cv < 0.3:
                    weight_distribution_score = 100.0 - (0.3 - cv) * 200
                else:
                    weight_distribution_score = 100.0 - (cv - 0.7) * 100
            
            # 종합 신뢰도 계산
            confidence = (
                quantity_score * 0.3 +
                time_distribution_score * 0.25 +
                stability_consistency_score * 0.25 +
                weight_distribution_score * 0.2
            )
            
            return min(100.0, max(0.0, confidence))
            
        except Exception as e:
            logger.error(f"신뢰도 계산 실패: {str(e)}")
            return 0.0
    
    def _calculate_weight_distribution(self, weighted_data: list) -> Dict:
        """가중치 분포 분석을 계산합니다."""
        try:
            weights = [data['weights']['combined_weight'] for data in weighted_data]
            
            return {
                'mean': statistics.mean(weights),
                'median': statistics.median(weights),
                'std': statistics.stdev(weights) if len(weights) > 1 else 0,
                'min': min(weights),
                'max': max(weights)
            }
            
        except Exception:
            return {'mean': 0, 'median': 0, 'std': 0, 'min': 0, 'max': 0}
    
    def _save_profile_to_local(self, profile_data: Dict, user_id: str) -> Optional[Path]:
        """
        누적 프로필을 로컬 파일로 저장합니다.
        
        Args:
            profile_data: 누적 프로필 데이터
            user_id: 사용자 ID
            
        Returns:
            저장된 파일 경로 (성공시) 또는 None (실패시)
        """
        try:
            # 사용자별 디렉토리 생성
            user_dir = self.local_save_dir / user_id
            user_dir.mkdir(exist_ok=True)
            
            # 프로필 파일명 생성
            profile_filename = f"{user_id}_accumulated_profile.json"
            profile_path = user_dir / profile_filename
            
            # JSON 파일로 저장
            with open(profile_path, 'w', encoding='utf-8') as f:
                json.dump(profile_data, f, ensure_ascii=False, indent=2)
            
            logger.info(f"누적 프로필 로컬 저장 완료: {profile_path}")
            return profile_path
            
        except Exception as e:
            logger.error(f"누적 프로필 로컬 저장 실패: {str(e)}")
            return None
    
    def _print_analysis_summary(self, analysis_result: Dict) -> None:
        """
        분석 결과 요약을 출력합니다.
        
        Args:
            analysis_result: 분석 결과 딕셔너리
        """
        try:
            print(f"\n🎉 음역대 분석 완료!")
            print("=" * 50)
            
            # 기본 정보
            metadata = analysis_result['metadata']
            print(f"📋 분석 정보:")
            print(f"   분석 ID: {metadata['analysis_id']}")
            print(f"   사용자: {metadata['user_id']}")
            print(f"   곡명: {metadata['song_name']}")
            print(f"   구간: {metadata['section']}")
            print(f"   방법: {metadata['method']}")
            print(f"   분석 시간: {metadata['timestamp']}")
            
            # 음역대 정보
            pitch_range = analysis_result['pitch_range']
            print(f"\n🎵 음역대 분석 결과:")
            print(f"   전체 음역대: {pitch_range['total_range']['min_note']} ~ {pitch_range['total_range']['max_note']}")
            print(f"   편안한 구간: {pitch_range['comfortable_range']['min_note']} ~ {pitch_range['comfortable_range']['max_note']}")
            print(f"   핵심 구간: {pitch_range['core_range']['min_note']} ~ {pitch_range['core_range']['max_note']}")
            
            # 안정성 정보
            stability = analysis_result['stability']
            print(f"\n📊 안정성 분석:")
            print(f"   안정성 점수: {stability['stability_score']:.1f}")
            print(f"   지터: {stability['jitter']:.2f}%")
            print(f"   셰머: {stability['shimmer']:.2f}%")
            print(f"   종합 평가: {analysis_result['summary']['stability_rating']}")
            
            # 추천 구간
            print(f"\n💡 추천사항:")
            print(f"   {analysis_result['summary']['recommended_range']}")
            
        except Exception as e:
            logger.error(f"분석 결과 출력 실패: {str(e)}")
    
    def _print_adaptive_profile_summary(self, profile_data: Dict) -> None:
        """
        Adaptive Weight 누적 프로필 요약을 출력합니다.
        
        Args:
            profile_data: 누적 프로필 데이터
        """
        try:
            print(f"\n🎭 Adaptive Weight 누적 프로필 요약:")
            print("=" * 50)
            
            if 'vocal_profile' in profile_data:
                vocal_profile = profile_data['vocal_profile']
                
                # 편안한 음역대
                if 'comfortable_range' in vocal_profile:
                    comfort = vocal_profile['comfortable_range']
                    print(f"📊 편안한 음역대: {comfort['min_note']} ~ {comfort['max_note']}")
                    print(f"   주파수: {comfort['min_freq']:.1f}Hz ~ {comfort['max_freq']:.1f}Hz")
                    print(f"   범위: {comfort['range_semitones']:.1f} 반음")
                
                # 핵심 음역대
                if 'core_range' in vocal_profile:
                    core = vocal_profile['core_range']
                    print(f"🎯 핵심 음역대: {core['min_note']} ~ {core['max_note']}")
                    print(f"   주파수: {core['min_freq']:.1f}Hz ~ {core['max_freq']:.1f}Hz")
                    print(f"   범위: {core['range_semitones']:.1f} 반음")
                
                # 안정성 프로필
                if 'stability_profile' in vocal_profile:
                    stability = vocal_profile['stability_profile']
                    print(f"📈 평균 안정성 점수: {stability['average_stability_score']:.1f}")
                    print(f"🎵 평균 지터: {stability['average_jitter']:.2f}%")
                    print(f"🎶 평균 셰머: {stability['average_shimmer']:.2f}%")
                    print(f"🔒 신뢰도: {stability['confidence_level']:.1f}%")
                
                # 분석 요약
                if 'analysis_summary' in vocal_profile:
                    summary = vocal_profile['analysis_summary']
                    print(f"📋 총 분석 횟수: {summary['total_analyses']}회")
                    print(f"📅 최근 분석: {summary['most_recent_analysis'][:19]}")
                    print(f"⚖️ 평균 가중치: {summary['average_weight']:.3f}")
            
            # 메타데이터
            if 'metadata' in profile_data:
                metadata = profile_data['metadata']
                print(f"🔧 가중치 전략: {metadata['weight_strategy']}")
                print(f"🕐 업데이트 시간: {metadata['last_updated'][:19]}")
            
        except Exception as e:
            logger.error(f"누적 프로필 요약 출력 실패: {str(e)}")
    
    def get_user_analysis_history(self, user_id: str) -> list:
        """
        사용자의 분석 기록을 조회합니다.
        
        Args:
            user_id: 사용자 ID
            
        Returns:
            분석 기록 리스트
        """
        try:
            user_dir = self.local_save_dir / user_id
            if not user_dir.exists():
                return []
            
            history = []
            for json_file in user_dir.glob("*.json"):
                # 누적 프로필 파일은 제외
                if "accumulated_profile" in json_file.name:
                    continue
                    
                try:
                    with open(json_file, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                        history.append({
                            'analysis_id': data['metadata']['analysis_id'],
                            'song_name': data['metadata']['song_name'],
                            'section': data['metadata']['section'],
                            'timestamp': data['metadata']['timestamp'],
                            'file_path': str(json_file),
                            'vocal_range': data['summary']['total_range_note'],
                            'stability': data['summary']['stability_rating']
                        })
                except Exception as e:
                    logger.warning(f"분석 파일 읽기 실패: {json_file}, {str(e)}")
            
            # 최신 순으로 정렬
            history.sort(key=lambda x: x['timestamp'], reverse=True)
            return history
            
        except Exception as e:
            logger.error(f"분석 기록 조회 실패: {str(e)}")
            return []
    
    def list_s3_files(self, prefix: str = "") -> list:
        """
        S3 버킷의 파일 목록을 가져옵니다.
        
        Args:
            prefix: 파일 경로 접두사 (예: "audio/user123/")
            
        Returns:
            파일 정보 리스트
        """
        if not self.s3_client or not self.bucket_name:
            logger.error("S3 클라이언트가 초기화되지 않았습니다.")
            return []
        
        try:
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name,
                Prefix=prefix
            )
            
            files = []
            if 'Contents' in response:
                for obj in response['Contents']:
                    files.append({
                        'key': obj['Key'],
                        'size': obj['Size'],
                        'last_modified': obj['LastModified'],
                        'url': f"https://{self.bucket_name}.s3.{self.s3_client.meta.region_name}.amazonaws.com/{obj['Key']}"
                    })
            
            logger.info(f"S3 파일 목록 조회 완료: {len(files)}개 파일")
            return files
            
        except Exception as e:
            logger.error(f"S3 파일 목록 조회 실패: {str(e)}")
            return []
    
    def analyze_multiple_s3_files(self, 
                                  s3_keys: list, 
                                  user_id: str, 
                                  song_names: Optional[list] = None,
                                  method: str = 'yin') -> Dict:
        """
        여러 S3 파일을 일괄 분석합니다.
        
        Args:
            s3_keys: S3 파일 키 목록
            user_id: 사용자 ID
            song_names: 곡명 목록 (선택사항)
            method: F0 추출 방법
            
        Returns:
            일괄 분석 결과 딕셔너리
        """
        if not self.s3_client or not self.bucket_name:
            logger.error("S3 클라이언트가 초기화되지 않았습니다.")
            return {'error': 'S3 클라이언트가 초기화되지 않았습니다.'}
        
        results = {
            'user_id': user_id,
            'total_files': len(s3_keys),
            'successful_analyses': [],
            'failed_analyses': [],
            'summary': {}
        }
        
        if song_names is None:
            song_names = [f"곡{i+1}" for i in range(len(s3_keys))]
        
        print(f"🔄 일괄 분석 시작 - {len(s3_keys)}개 파일")
        print("=" * 50)
        
        for i, s3_key in enumerate(s3_keys):
            song_name = song_names[i] if i < len(song_names) else f"곡{i+1}"
            
            print(f"\n📁 {i+1}/{len(s3_keys)} - {song_name}")
            analysis_result = self.analyze_s3_audio(
                s3_key=s3_key,
                user_id=user_id,
                song_name=song_name,
                method=method
            )
            
            if analysis_result:
                results['successful_analyses'].append({
                    's3_key': s3_key,
                    'song_name': song_name,
                    'analysis_id': analysis_result['metadata']['analysis_id'],
                    'local_json_path': analysis_result.get('local_json_path')
                })
            else:
                results['failed_analyses'].append({
                    's3_key': s3_key,
                    'song_name': song_name,
                    'error': '분석 실패'
                })
        
        # 결과 요약
        success_count = len(results['successful_analyses'])
        fail_count = len(results['failed_analyses'])
        
        results['summary'] = {
            'success_count': success_count,
            'fail_count': fail_count,
            'success_rate': f"{success_count/len(s3_keys)*100:.1f}%",
            'completed_at': datetime.now().isoformat()
        }
        
        print(f"\n🎯 일괄 분석 완료!")
        print(f"   성공: {success_count}개")
        print(f"   실패: {fail_count}개")
        print(f"   성공률: {results['summary']['success_rate']}")
        
        return results
    
    def get_latest_user_vocal_s3_key(self, user_id: str, audio_prefix: str = "audio/") -> Optional[str]:
        """
        사용자의 가장 최근 vocal 파일의 S3 키를 찾습니다.
        
        Args:
            user_id: 사용자 ID
            audio_prefix: 오디오 파일이 저장된 S3 경로 접두사
            
        Returns:
            가장 최근 vocal 파일의 S3 키 (성공시) 또는 None (실패시)
        """
        if not self.s3_client or not self.bucket_name:
            logger.error("S3 클라이언트가 초기화되지 않았습니다.")
            return None
        
        try:
            # 사용자별 오디오 파일 경로 설정
            user_audio_prefix = f"{audio_prefix}{user_id}/"
            
            print(f"🔍 사용자 {user_id}의 최신 vocal 파일 검색 중...")
            print(f"   검색 경로: s3://{self.bucket_name}/{user_audio_prefix}")
            
            # S3에서 사용자의 오디오 파일 목록 조회
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name,
                Prefix=user_audio_prefix
            )
            
            if 'Contents' not in response:
                print(f"❌ 사용자 {user_id}의 오디오 파일을 찾을 수 없습니다.")
                return None
            
            # 오디오 파일 확장자 필터링
            audio_extensions = ['.wav', '.mp3', '.flac', '.m4a', '.aac', '.ogg']
            audio_files = []
            
            for obj in response['Contents']:
                key = obj['Key']
                if any(key.lower().endswith(ext) for ext in audio_extensions):
                    audio_files.append({
                        'key': key,
                        'last_modified': obj['LastModified'],
                        'size': obj['Size']
                    })
            
            if not audio_files:
                print(f"❌ 사용자 {user_id}의 오디오 파일을 찾을 수 없습니다.")
                return None
            
            # 최신 파일 찾기 (LastModified 기준)
            latest_file = max(audio_files, key=lambda x: x['last_modified'])
            
            print(f"✅ 최신 vocal 파일 발견:")
            print(f"   파일: {latest_file['key']}")
            print(f"   수정일: {latest_file['last_modified']}")
            print(f"   크기: {latest_file['size'] / (1024*1024):.1f}MB")
            
            return latest_file['key']
            
        except Exception as e:
            print(f"❌ 최신 vocal 파일 검색 실패: {str(e)}")
            logger.error(f"최신 vocal 파일 검색 실패: {str(e)}")
            return None
    
    def analyze_latest_user_vocal(self, 
                                 user_id: str, 
                                 audio_prefix: str = "audio/",
                                 method: str = 'yin',
                                 auto_song_name: bool = True) -> Optional[Dict]:
        """
        사용자의 가장 최근 vocal 파일을 자동으로 찾아서 분석합니다.
        
        Args:
            user_id: 사용자 ID
            audio_prefix: 오디오 파일이 저장된 S3 경로 접두사
            method: F0 추출 방법 ('yin' 또는 'piptrack')
            auto_song_name: 파일명에서 자동으로 곡명 추출 여부
            
        Returns:
            분석 결과 딕셔너리 (성공시) 또는 None (실패시)
        """
        try:
            print(f"🎵 사용자 {user_id}의 최신 vocal 분석 시작")
            print("=" * 50)
            
            # 1. 가장 최근 vocal 파일 찾기
            latest_s3_key = self.get_latest_user_vocal_s3_key(user_id, audio_prefix)
            
            if not latest_s3_key:
                print(f"❌ 사용자 {user_id}의 vocal 파일을 찾을 수 없습니다.")
                return None
            
            # 2. 곡명 자동 추출 (파일명에서)
            if auto_song_name:
                song_name = self._extract_song_name_from_s3_key(latest_s3_key)
            else:
                song_name = "최신 녹음"
            
            print(f"📝 곡명: {song_name}")
            
            # 3. 분석 실행
            result = self.analyze_s3_audio(
                s3_key=latest_s3_key,
                user_id=user_id,
                song_name=song_name,
                section="전체",
                method=method,
                update_profile=True  # 누적 프로필 자동 업데이트
            )
            
            if result:
                print(f"\n🎉 최신 vocal 분석 완료!")
                print(f"📄 분석 ID: {result['metadata']['analysis_id']}")
                print(f"🎵 음역대: {result['summary']['total_range_note']}")
                print(f"📊 안정성: {result['summary']['stability_rating']}")
                
                return result
            else:
                print(f"❌ 최신 vocal 분석 실패")
                return None
                
        except Exception as e:
            print(f"❌ 최신 vocal 분석 중 오류: {str(e)}")
            logger.error(f"최신 vocal 분석 오류: {str(e)}")
            return None
    
    def _extract_song_name_from_s3_key(self, s3_key: str) -> str:
        """
        S3 키에서 곡명을 추출합니다.
        
        Args:
            s3_key: S3 파일 키
            
        Returns:
            추출된 곡명
        """
        try:
            # 파일명만 추출
            filename = Path(s3_key).name
            
            # 확장자 제거
            song_name = Path(filename).stem
            
            # 일반적인 패턴 처리
            # 예: "가요1_vocal_20241201_123456.wav" -> "가요1"
            # 예: "song_title_vocal.wav" -> "song_title"
            
            # "_vocal"이 포함된 경우
            if "_vocal" in song_name:
                song_name = song_name.split("_vocal")[0]
            
            # 날짜 패턴 제거 (YYYYMMDD 형태)
            import re
            song_name = re.sub(r'_\d{8}_\d{6}', '', song_name)
            song_name = re.sub(r'_\d{8}', '', song_name)
            song_name = re.sub(r'_\d{6}', '', song_name)
            
            # 빈 문자열이면 기본값 사용
            if not song_name.strip():
                song_name = "녹음곡"
            
            return song_name.strip()
            
        except Exception as e:
            logger.warning(f"곡명 추출 실패: {str(e)}")
            return "녹음곡"
    
    def analyze_user_vocal_auto(self, user_id: str) -> Optional[Dict]:
        """
        사용자 ID만으로 최신 vocal을 자동 분석하는 간편 메서드
        
        Args:
            user_id: 사용자 ID
            
        Returns:
            분석 결과 딕셔너리 (성공시) 또는 None (실패시)
        """
        return self.analyze_latest_user_vocal(user_id)

    def load_audio(self, file_path: Union[str, Path]) -> Tuple[np.ndarray, float]:
        """
        오디오 파일을 로드합니다.
        
        Args:
            file_path: 오디오 파일 경로
            
        Returns:
            (audio_data, sample_rate): 오디오 데이터와 샘플링 레이트
        """
        try:
            audio, sr = librosa.load(file_path, sr=self.sr)
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
                sr=self.sr,
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
                sr=self.sr,
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
    
    def freq_to_semitone(self, freq: float) -> float:
        """
        주파수를 세미톤으로 변환합니다 (A4=440Hz를 기준으로).
        
        Args:
            freq: 주파수 (Hz)
            
        Returns:
            A4(440Hz)를 기준으로 한 세미톤 수
        """
        if freq <= 0:
            return 0.0
        
        # A4 = 440Hz를 기준 (69번째 MIDI 노트)
        # 12 * log2(freq/440) + 69
        semitone = 12 * np.log2(freq / 440.0) + 69
        return float(semitone)
    
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
                    'stability': float(100 - min(float(variability), 100.0)),  # 100점 만점
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
                vibrato_rate = self.sr / (vibrato_period * self.hop_length)  # Hz
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
                sr=self.sr,
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
    
    def plot_pitch_analysis(self, result: Dict, output_path: Optional[Union[str, Path]] = None) -> None:
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

    def analyze_and_save(self, file_path: Union[str, Path], user_id: str, 
                        song_name: str = "", section: str = "전체", 
                        method: str = 'yin') -> Dict:
        """
        오디오 파일을 분석하고 메타데이터와 함께 저장합니다.
        
        Args:
            file_path: 오디오 파일 경로
            user_id: 사용자 고유 ID  
            song_name: 곡명 (선택사항)
            section: 구간명 (선택사항)
            method: F0 추출 방법 ('yin' 또는 'piptrack')
            
        Returns:
            메타데이터가 포함된 분석 결과
        """
        try:
            # 기존 분석 수행
            result = self.analyze_audio_file(file_path, method)
            
            # 고유 분석 ID 생성
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            analysis_id = f"{user_id}_{timestamp}_{str(uuid.uuid4())[:8]}"
            
            # 메타데이터 추가
            result['metadata'] = {
                'analysis_id': analysis_id,
                'user_id': user_id,
                'song_name': song_name,
                'section': section,
                'timestamp': datetime.now().isoformat(),
                'original_file': str(file_path),
                'method': method
            }
            
            # 결과 저장 디렉토리 생성
            results_dir = Path("analysis_results")
            results_dir.mkdir(exist_ok=True)
            
            # 사용자별 하위 디렉토리 생성
            user_dir = results_dir / user_id
            user_dir.mkdir(exist_ok=True)
            
            # 파일로 저장
            save_path = user_dir / f"{analysis_id}.json"
            self.save_analysis(result, save_path)
            
            logger.info(f"분석 결과 저장 완료: {save_path}")
            return result
            
        except Exception as e:
            logger.error(f"분석 및 저장 실패: {e}")
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