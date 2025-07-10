"""
사용자 음역대 프로필 누적 관리 모듈
여러 번의 pitch_analyzer 결과를 누적하여 점진적으로 정확한 음역대 프로필을 구축
"""

import json
import numpy as np
import os
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime, timedelta
import logging

# 로깅 설정
logger = logging.getLogger(__name__)

class VocalProfileManager:
    """사용자의 음역대 분석 결과를 누적 관리하는 클래스"""
    
    def __init__(self, user_id: str):
        """
        VocalProfileManager 초기화
        
        Args:
            user_id: 사용자 고유 ID
        """
        self.user_id = user_id
        self.results_dir = Path("analysis_results") / user_id
        
    def get_all_user_analyses(self, days_limit: Optional[int] = None) -> List[Dict]:
        """
        해당 사용자의 모든 분석 결과를 로드합니다.
        
        Args:
            days_limit: 최근 며칠간의 결과만 로드 (None이면 전체)
            
        Returns:
            분석 결과 리스트 (시간순 정렬)
        """
        analyses = []
        
        if not self.results_dir.exists():
            logger.warning(f"사용자 결과 디렉토리가 없습니다: {self.results_dir}")
            return analyses
        
        # 사용자 디렉토리의 모든 JSON 파일 로드
        for json_file in self.results_dir.glob("*.json"):
            try:
                with open(json_file, 'r', encoding='utf-8') as f:
                    result = json.load(f)
                
                # 날짜 필터링
                if days_limit:
                    analysis_date = datetime.fromisoformat(result['metadata']['timestamp'])
                    cutoff_date = datetime.now() - timedelta(days=days_limit)
                    if analysis_date < cutoff_date:
                        continue
                
                analyses.append(result)
                
            except Exception as e:
                logger.error(f"분석 결과 로드 실패 {json_file}: {e}")
                continue
        
        # 시간순 정렬 (오래된 것부터)
        analyses.sort(key=lambda x: x['metadata']['timestamp'])
        
        logger.info(f"로드된 분석 결과: {len(analyses)}개 (사용자: {self.user_id})")
        return analyses
    
    def calculate_accumulated_profile(self, days_limit: Optional[int] = None) -> Dict:
        """
        여러 분석 결과를 합쳐서 누적 음역대 프로필을 계산합니다.
        
        Args:
            days_limit: 최근 며칠간의 결과만 사용 (None이면 전체)
            
        Returns:
            누적된 음역대 프로필
        """
        analyses = self.get_all_user_analyses(days_limit)
        
        if not analyses:
            return self._empty_profile()
        
        # 각 분석에서 핵심 음역대 데이터 추출
        all_min_freqs = []
        all_max_freqs = []
        all_comfortable_min_freqs = []
        all_comfortable_max_freqs = []
        all_core_min_freqs = []
        all_core_max_freqs = []
        all_stability_scores = []
        
        # 안정성 기반 음역대 데이터
        all_stability_comfortable_min = []
        all_stability_comfortable_max = []
        all_stability_core_min = []
        all_stability_core_max = []
        
        for analysis in analyses:
            try:
                pitch_range = analysis['pitch_range']
                stability = analysis['stability']
                
                # 기본 음역대 (시간 기반)
                all_min_freqs.append(pitch_range['total_range']['min_freq'])
                all_max_freqs.append(pitch_range['total_range']['max_freq'])
                all_comfortable_min_freqs.append(pitch_range['comfortable_range']['min_freq'])
                all_comfortable_max_freqs.append(pitch_range['comfortable_range']['max_freq'])
                all_core_min_freqs.append(pitch_range['core_range']['min_freq'])
                all_core_max_freqs.append(pitch_range['core_range']['max_freq'])
                
                # 안정성 기반 음역대
                if 'stability_comfortable_range' in pitch_range:
                    stable_comfortable = pitch_range['stability_comfortable_range']
                    if stable_comfortable['min_freq'] > 0:
                        all_stability_comfortable_min.append(stable_comfortable['min_freq'])
                        all_stability_comfortable_max.append(stable_comfortable['max_freq'])
                
                if 'stability_core_range' in pitch_range:
                    stable_core = pitch_range['stability_core_range']
                    if stable_core['min_freq'] > 0:
                        all_stability_core_min.append(stable_core['min_freq'])
                        all_stability_core_max.append(stable_core['max_freq'])
                
                # 안정성 점수
                all_stability_scores.append(stability['stability_score'])
                
            except KeyError as e:
                logger.warning(f"분석 결과에서 필수 데이터 누락: {e}")
                continue
        
        # 누적 계산 (아웃라이어 제거 적용)
        accumulated = self._calculate_robust_ranges(
            all_min_freqs, all_max_freqs,
            all_comfortable_min_freqs, all_comfortable_max_freqs,
            all_core_min_freqs, all_core_max_freqs,
            all_stability_comfortable_min, all_stability_comfortable_max,
            all_stability_core_min, all_stability_core_max,
            all_stability_scores
        )
        
        # 메타데이터 추가
        accumulated['metadata'] = {
            'user_id': self.user_id,
            'total_analyses': len(analyses),
            'date_range': {
                'first_analysis': analyses[0]['metadata']['timestamp'] if analyses else None,
                'last_analysis': analyses[-1]['metadata']['timestamp'] if analyses else None
            },
            'confidence_level': self._calculate_confidence_level(len(analyses)),
            'calculated_at': datetime.now().isoformat()
        }
        
        return accumulated
    
    def _calculate_robust_ranges(self, min_freqs, max_freqs, 
                                comfortable_mins, comfortable_maxs,
                                core_mins, core_maxs,
                                stability_comfortable_mins, stability_comfortable_maxs,
                                stability_core_mins, stability_core_maxs,
                                stability_scores) -> Dict:
        """
        아웃라이어를 제거하고 robust한 음역대를 계산합니다.
        """
        from pitch_analyzer import PitchAnalyzer
        analyzer = PitchAnalyzer()
        
        def robust_range(values):
            """아웃라이어 제거 후 범위 계산"""
            if not values:
                return 0, 0
            arr = np.array(values)
            # IQR 방식으로 아웃라이어 제거
            q25, q75 = np.percentile(arr, [25, 75])
            iqr = q75 - q25
            lower_bound = q25 - 1.5 * iqr
            upper_bound = q75 + 1.5 * iqr
            
            # 아웃라이어 제거
            filtered = arr[(arr >= lower_bound) & (arr <= upper_bound)]
            if len(filtered) == 0:
                filtered = arr  # 모두 아웃라이어면 원본 사용
            
            return float(np.min(filtered)), float(np.max(filtered))
        
        def robust_mean(values):
            """아웃라이어 제거 후 평균 계산"""
            if not values:
                return 0
            arr = np.array(values)
            q25, q75 = np.percentile(arr, [25, 75])
            iqr = q75 - q25
            lower_bound = q25 - 1.5 * iqr
            upper_bound = q75 + 1.5 * iqr
            
            filtered = arr[(arr >= lower_bound) & (arr <= upper_bound)]
            if len(filtered) == 0:
                filtered = arr
            
            return float(np.mean(filtered))
        
        # 각 범위별로 robust 계산
        total_min, total_max = robust_range(min_freqs + max_freqs)
        comfortable_min, comfortable_max = robust_range(comfortable_mins + comfortable_maxs)
        core_min, core_max = robust_range(core_mins + core_maxs)
        
        # 안정성 기반 범위
        if stability_comfortable_mins and stability_comfortable_maxs:
            stability_comfortable_min, stability_comfortable_max = robust_range(
                stability_comfortable_mins + stability_comfortable_maxs
            )
        else:
            stability_comfortable_min = stability_comfortable_max = 0
            
        if stability_core_mins and stability_core_maxs:
            stability_core_min, stability_core_max = robust_range(
                stability_core_mins + stability_core_maxs
            )
        else:
            stability_core_min = stability_core_max = 0
        
        # 평균 안정성
        avg_stability = robust_mean(stability_scores)
        
        return {
            'accumulated_ranges': {
                'total_range': {
                    'min_freq': total_min,
                    'max_freq': total_max,
                    'min_note': analyzer.freq_to_note(total_min) if total_min > 0 else 'N/A',
                    'max_note': analyzer.freq_to_note(total_max) if total_max > 0 else 'N/A',
                    'range_semitones': 12 * np.log2(total_max / total_min) if total_min > 0 and total_max > 0 else 0,
                    'description': '누적된 전체 음역대 (아웃라이어 제거)'
                },
                'comfortable_range': {
                    'min_freq': comfortable_min,
                    'max_freq': comfortable_max,
                    'min_note': analyzer.freq_to_note(comfortable_min) if comfortable_min > 0 else 'N/A',
                    'max_note': analyzer.freq_to_note(comfortable_max) if comfortable_max > 0 else 'N/A',
                    'range_semitones': 12 * np.log2(comfortable_max / comfortable_min) if comfortable_min > 0 and comfortable_max > 0 else 0,
                    'description': '누적된 편안한 발성 구간'
                },
                'core_range': {
                    'min_freq': core_min,
                    'max_freq': core_max,
                    'min_note': analyzer.freq_to_note(core_min) if core_min > 0 else 'N/A',
                    'max_note': analyzer.freq_to_note(core_max) if core_max > 0 else 'N/A',
                    'range_semitones': 12 * np.log2(core_max / core_min) if core_min > 0 and core_max > 0 else 0,
                    'description': '누적된 핵심 발성 구간'
                },
                'stability_comfortable_range': {
                    'min_freq': stability_comfortable_min,
                    'max_freq': stability_comfortable_max,
                    'min_note': analyzer.freq_to_note(stability_comfortable_min) if stability_comfortable_min > 0 else 'N/A',
                    'max_note': analyzer.freq_to_note(stability_comfortable_max) if stability_comfortable_max > 0 else 'N/A',
                    'range_semitones': 12 * np.log2(stability_comfortable_max / stability_comfortable_min) if stability_comfortable_min > 0 and stability_comfortable_max > 0 else 0,
                    'description': '누적된 안정성 기반 편안한 구간'
                },
                'stability_core_range': {
                    'min_freq': stability_core_min,
                    'max_freq': stability_core_max,
                    'min_note': analyzer.freq_to_note(stability_core_min) if stability_core_min > 0 else 'N/A',
                    'max_note': analyzer.freq_to_note(stability_core_max) if stability_core_max > 0 else 'N/A',
                    'range_semitones': 12 * np.log2(stability_core_max / stability_core_min) if stability_core_min > 0 and stability_core_max > 0 else 0,
                    'description': '누적된 안정성 기반 핵심 구간'
                }
            },
            'accumulated_stability': {
                'average_stability_score': avg_stability,
                'stability_trend': self._calculate_stability_trend(stability_scores),
                'stability_rating': self._get_accumulated_stability_rating(avg_stability)
            }
        }
    
    def _calculate_confidence_level(self, num_analyses: int) -> Dict:
        """
        측정 횟수 기반 신뢰도를 계산합니다.
        """
        if num_analyses == 0:
            level = "없음"
            percentage = 0
            recommendation = "노래를 불러서 음역대를 측정해보세요."
        elif num_analyses < 3:
            level = "낮음"
            percentage = min(30, num_analyses * 15)
            recommendation = f"더 정확한 분석을 위해 {3 - num_analyses}회 더 측정해보세요."
        elif num_analyses < 5:
            level = "보통"
            percentage = 30 + (num_analyses - 2) * 20
            recommendation = "좋습니다! 몇 번 더 측정하면 더 정확해집니다."
        elif num_analyses < 10:
            level = "높음"
            percentage = 70 + (num_analyses - 4) * 5
            recommendation = "안정적인 음역대 프로필이 형성되었습니다."
        else:
            level = "매우 높음"
            percentage = min(95, 85 + (num_analyses - 9) * 2)
            recommendation = "매우 정확한 음역대 프로필입니다!"
        
        return {
            'level': level,
            'percentage': percentage,
            'total_measurements': num_analyses,
            'recommendation': recommendation
        }
    
    def _calculate_stability_trend(self, stability_scores: List[float]) -> str:
        """
        시간에 따른 안정성 변화 추세를 계산합니다.
        """
        if len(stability_scores) < 3:
            return "데이터 부족"
        
        # 최근 3개와 이전 데이터들 비교
        recent_avg = np.mean(stability_scores[-3:])
        if len(stability_scores) >= 6:
            previous_avg = np.mean(stability_scores[-6:-3])
            improvement = recent_avg - previous_avg
            
            if improvement > 5:
                return "크게 개선됨"
            elif improvement > 2:
                return "개선됨"
            elif improvement > -2:
                return "안정적"
            elif improvement > -5:
                return "약간 하락"
            else:
                return "하락"
        else:
            return "안정적"
    
    def _get_accumulated_stability_rating(self, avg_stability: float) -> str:
        """
        누적 안정성 평점을 반환합니다.
        """
        if avg_stability < 15:
            return "매우 안정 (우수)"
        elif avg_stability < 25:
            return "안정 (양호)"  
        elif avg_stability < 40:
            return "보통"
        elif avg_stability < 60:
            return "약간 불안정"
        else:
            return "불안정"
    
    def _empty_profile(self) -> Dict:
        """빈 프로필을 반환합니다."""
        return {
            'accumulated_ranges': {
                'total_range': {'min_freq': 0, 'max_freq': 0, 'min_note': 'N/A', 'max_note': 'N/A'},
                'comfortable_range': {'min_freq': 0, 'max_freq': 0, 'min_note': 'N/A', 'max_note': 'N/A'},
                'core_range': {'min_freq': 0, 'max_freq': 0, 'min_note': 'N/A', 'max_note': 'N/A'}
            },
            'accumulated_stability': {
                'average_stability_score': 0,
                'stability_trend': '데이터 없음',
                'stability_rating': '측정 필요'
            },
            'metadata': {
                'user_id': self.user_id,
                'total_analyses': 0,
                'confidence_level': self._calculate_confidence_level(0),
                'calculated_at': datetime.now().isoformat()
            }
        }
    
    def get_progress_over_time(self, days_limit: Optional[int] = None) -> Dict:
        """
        시간별 음역대 변화 추이를 반환합니다.
        
        Args:
            days_limit: 최근 며칠간의 결과만 분석
            
        Returns:
            시간별 변화 추이 데이터
        """
        analyses = self.get_all_user_analyses(days_limit)
        
        if len(analyses) < 2:
            return {
                'trend': '데이터 부족',
                'data_points': [],
                'summary': '최소 2회 이상의 측정이 필요합니다.'
            }
        
        data_points = []
        for analysis in analyses:
            try:
                data_points.append({
                    'timestamp': analysis['metadata']['timestamp'],
                    'song_name': analysis['metadata'].get('song_name', ''),
                    'total_min': analysis['pitch_range']['total_range']['min_freq'],
                    'total_max': analysis['pitch_range']['total_range']['max_freq'],
                    'comfortable_min': analysis['pitch_range']['comfortable_range']['min_freq'],
                    'comfortable_max': analysis['pitch_range']['comfortable_range']['max_freq'],
                    'stability_score': analysis['stability']['stability_score']
                })
            except KeyError:
                continue
        
        # 변화 추이 분석
        if len(data_points) >= 3:
            recent_range = data_points[-1]['total_max'] - data_points[-1]['total_min']
            initial_range = data_points[0]['total_max'] - data_points[0]['total_min']
            range_change = recent_range - initial_range
            
            if range_change > 50:  # Hz 기준
                trend = "음역대 확장"
            elif range_change < -50:
                trend = "음역대 축소"
            else:
                trend = "안정적 유지"
        else:
            trend = "변화 추세 분석 중"
        
        return {
            'trend': trend,
            'data_points': data_points,
            'summary': f"총 {len(data_points)}회 측정, 추세: {trend}"
        }
    
    def get_song_based_analysis(self) -> Dict:
        """
        곡별 음역대 분석을 반환합니다.
        """
        analyses = self.get_all_user_analyses()
        
        song_groups = {}
        for analysis in analyses:
            song_name = analysis['metadata'].get('song_name', '알 수 없음')
            if song_name not in song_groups:
                song_groups[song_name] = []
            song_groups[song_name].append(analysis)
        
        song_analysis = {}
        for song_name, song_analyses in song_groups.items():
            if len(song_analyses) >= 1:
                # 해당 곡의 평균 음역대 계산
                total_mins = [a['pitch_range']['total_range']['min_freq'] for a in song_analyses]
                total_maxs = [a['pitch_range']['total_range']['max_freq'] for a in song_analyses]
                
                song_analysis[song_name] = {
                    'measurement_count': len(song_analyses),
                    'avg_min_freq': float(np.mean(total_mins)),
                    'avg_max_freq': float(np.mean(total_maxs)),
                    'range_stability': float(np.std(total_maxs) + np.std(total_mins)),  # 낮을수록 안정
                    'last_measured': song_analyses[-1]['metadata']['timestamp']
                }
        
        return song_analysis
    
    def save_accumulated_profile(self, output_path: Optional[str] = None) -> str:
        """
        누적 프로필을 파일로 저장합니다.
        
        Args:
            output_path: 저장 경로 (None이면 자동 생성)
            
        Returns:
            저장된 파일 경로
        """
        accumulated = self.calculate_accumulated_profile()
        
        if output_path is None:
            profiles_dir = Path("user_profiles")
            profiles_dir.mkdir(exist_ok=True)
            output_path = str(profiles_dir / f"{self.user_id}_accumulated_profile.json")
        
        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(accumulated, f, ensure_ascii=False, indent=2)
            
            logger.info(f"누적 프로필 저장 완료: {output_path}")
            return output_path
            
        except Exception as e:
            logger.error(f"누적 프로필 저장 실패: {e}")
            raise

    def calculate_weighted_profile(self, weighting_strategy: str = "composite", days_limit: Optional[int] = None) -> Dict:
        """
        가중치를 적용하여 누적 음역대 프로필을 계산합니다.
        
        Args:
            weighting_strategy: 가중치 전략 ("time", "stability", "duration", "composite", "adaptive")
            days_limit: 최근 며칠간의 결과만 사용 (None이면 전체)
            
        Returns:
            가중치가 적용된 누적 음역대 프로필
        """
        analyses = self.get_all_user_analyses(days_limit)
        
        if not analyses:
            return self._empty_profile()
        
        # 가중치 계산
        if weighting_strategy == "time":
            weights = self._calculate_time_weights(analyses)
        elif weighting_strategy == "stability":
            weights = self._calculate_stability_weights(analyses)
        elif weighting_strategy == "duration":
            weights = self._calculate_duration_weights(analyses)
        elif weighting_strategy == "composite":
            weights = self._calculate_composite_weights(analyses)
        elif weighting_strategy == "adaptive":
            weights = self._calculate_adaptive_weights(analyses)
        else:
            weights = [1.0] * len(analyses)  # 동일 가중치
        
        # 가중치 정규화
        total_weight = sum(weights)
        weights = [w / total_weight for w in weights]
        
        # 각 분석에서 핵심 음역대 데이터 추출 (가중치와 함께)
        weighted_data = {
            'min_freqs': [], 'max_freqs': [],
            'comfortable_mins': [], 'comfortable_maxs': [],
            'core_mins': [], 'core_maxs': [],
            'stability_scores': [],
            'weights': weights
        }
        
        for i, analysis in enumerate(analyses):
            try:
                pitch_range = analysis['pitch_range']
                stability = analysis['stability']
                weight = weights[i]
                
                # 가중치와 함께 데이터 저장
                weighted_data['min_freqs'].append((pitch_range['total_range']['min_freq'], weight))
                weighted_data['max_freqs'].append((pitch_range['total_range']['max_freq'], weight))
                weighted_data['comfortable_mins'].append((pitch_range['comfortable_range']['min_freq'], weight))
                weighted_data['comfortable_maxs'].append((pitch_range['comfortable_range']['max_freq'], weight))
                weighted_data['core_mins'].append((pitch_range['core_range']['min_freq'], weight))
                weighted_data['core_maxs'].append((pitch_range['core_range']['max_freq'], weight))
                weighted_data['stability_scores'].append((stability['stability_score'], weight))
                
            except KeyError as e:
                logger.warning(f"분석 결과에서 필수 데이터 누락: {e}")
                continue
        
        # 가중치 기반 계산
        accumulated = self._calculate_weighted_ranges(weighted_data)
        
        # 메타데이터 추가
        accumulated['metadata'] = {
            'user_id': self.user_id,
            'total_analyses': len(analyses),
            'weighting_strategy': weighting_strategy,
            'weights_used': weights,
            'date_range': {
                'first_analysis': analyses[0]['metadata']['timestamp'] if analyses else None,
                'last_analysis': analyses[-1]['metadata']['timestamp'] if analyses else None
            },
            'confidence_level': self._calculate_confidence_level(len(analyses)),
            'calculated_at': datetime.now().isoformat()
        }
        
        return accumulated
    
    def _calculate_time_weights(self, analyses: List[Dict]) -> List[float]:
        """시간 기반 가중치: 최근 측정일수록 높은 가중치"""
        if len(analyses) <= 1:
            return [1.0] * len(analyses)
        
        now = datetime.now()
        weights = []
        
        for analysis in analyses:
            timestamp = datetime.fromisoformat(analysis['metadata']['timestamp'])
            days_ago = (now - timestamp).days
            
            # 지수 감소: 30일 반감기
            weight = np.exp(-days_ago / 30.0)
            weights.append(weight)
        
        return weights
    
    def _calculate_stability_weights(self, analyses: List[Dict]) -> List[float]:
        """안정성 기반 가중치: 안정성 점수가 높을수록 높은 가중치"""
        weights = []
        
        for analysis in analyses:
            stability_score = analysis['stability']['stability_score']
            
            # Sigmoid 함수로 가중치 변환 (0.5를 중심으로)
            weight = 1 / (1 + np.exp(-(stability_score - 0.5) * 10))
            weights.append(weight)
        
        return weights
    
    def _calculate_duration_weights(self, analyses: List[Dict]) -> List[float]:
        """측정 길이 기반 가중치: 더 긴 오디오일수록 높은 가중치"""
        weights = []
        
        for analysis in analyses:
            duration = analysis['audio_info']['duration']
            
            # 30초를 기준으로 정규화, 최대 2배까지
            weight = min(2.0, duration / 30.0)
            # 최소 가중치 0.3 보장
            weight = max(0.3, weight)
            weights.append(weight)
        
        return weights
    
    def _calculate_composite_weights(self, analyses: List[Dict]) -> List[float]:
        """복합 가중치: 시간 + 안정성 + 길이를 조합"""
        time_weights = self._calculate_time_weights(analyses)
        stability_weights = self._calculate_stability_weights(analyses)  
        duration_weights = self._calculate_duration_weights(analyses)
        
        composite_weights = []
        for i in range(len(analyses)):
            # 각 가중치의 비중 설정 (합계 = 1.0)
            composite = (
                0.4 * time_weights[i] +      # 시간: 40%
                0.4 * stability_weights[i] +  # 안정성: 40%  
                0.2 * duration_weights[i]     # 길이: 20%
            )
            composite_weights.append(composite)
        
        return composite_weights
    
    def _calculate_adaptive_weights(self, analyses: List[Dict]) -> List[float]:
        """적응형 가중치: 측정 횟수에 따라 전략 변경"""
        num_analyses = len(analyses)
        
        if num_analyses <= 3:
            # 초기: 모든 데이터가 소중
            return [1.0] * num_analyses
        elif num_analyses <= 7:
            # 중기: 안정성 중심
            return self._calculate_stability_weights(analyses)
        else:
            # 후기: 복합 전략
            return self._calculate_composite_weights(analyses)
    
    def _calculate_weighted_ranges(self, weighted_data: Dict) -> Dict:
        """가중치를 적용한 음역대 계산"""
        from pitch_analyzer import PitchAnalyzer
        analyzer = PitchAnalyzer()
        
        def weighted_percentile(values_weights, percentile):
            """가중치 적용 백분위수 계산"""
            if not values_weights:
                return 0
            
            values, weights = zip(*values_weights)
            values = np.array(values)
            weights = np.array(weights)
            
            # 정렬
            sorted_indices = np.argsort(values)
            sorted_values = values[sorted_indices]
            sorted_weights = weights[sorted_indices]
            
            # 누적 가중치 계산
            cumsum_weights = np.cumsum(sorted_weights)
            total_weight = cumsum_weights[-1]
            
            # 백분위수에 해당하는 가중치 위치
            target_weight = total_weight * percentile / 100.0
            
            # 해당 위치 찾기
            idx = np.searchsorted(cumsum_weights, target_weight)
            if idx >= len(sorted_values):
                idx = len(sorted_values) - 1
            
            return float(sorted_values[idx])
        
        def weighted_mean(values_weights):
            """가중 평균 계산"""
            if not values_weights:
                return 0
            
            values, weights = zip(*values_weights)
            return float(np.average(values, weights=weights))
        
        # 가중치 기반 음역대 계산
        total_range_min = weighted_percentile(weighted_data['min_freqs'], 10)
        total_range_max = weighted_percentile(weighted_data['max_freqs'], 90)
        
        comfortable_range_min = weighted_percentile(weighted_data['comfortable_mins'], 20)
        comfortable_range_max = weighted_percentile(weighted_data['comfortable_maxs'], 80)
        
        core_range_min = weighted_percentile(weighted_data['core_mins'], 25)
        core_range_max = weighted_percentile(weighted_data['core_maxs'], 75)
        
        avg_stability = weighted_mean(weighted_data['stability_scores'])
        
        # 결과 구성
        return {
            'pitch_range': {
                'total_range': {
                    'min_freq': total_range_min,
                    'max_freq': total_range_max,
                    'min_note': analyzer.freq_to_note(total_range_min) if total_range_min > 0 else "N/A",
                    'max_note': analyzer.freq_to_note(total_range_max) if total_range_max > 0 else "N/A",
                    'range_semitones': analyzer.freq_to_semitone(total_range_max) - analyzer.freq_to_semitone(total_range_min) if total_range_min > 0 and total_range_max > 0 else 0
                },
                'comfortable_range': {
                    'min_freq': comfortable_range_min,
                    'max_freq': comfortable_range_max,
                    'min_note': analyzer.freq_to_note(comfortable_range_min) if comfortable_range_min > 0 else "N/A",
                    'max_note': analyzer.freq_to_note(comfortable_range_max) if comfortable_range_max > 0 else "N/A",
                    'range_semitones': analyzer.freq_to_semitone(comfortable_range_max) - analyzer.freq_to_semitone(comfortable_range_min) if comfortable_range_min > 0 and comfortable_range_max > 0 else 0
                },
                'core_range': {
                    'min_freq': core_range_min,
                    'max_freq': core_range_max,
                    'min_note': analyzer.freq_to_note(core_range_min) if core_range_min > 0 else "N/A",
                    'max_note': analyzer.freq_to_note(core_range_max) if core_range_max > 0 else "N/A",
                    'range_semitones': analyzer.freq_to_semitone(core_range_max) - analyzer.freq_to_semitone(core_range_min) if core_range_min > 0 and core_range_max > 0 else 0
                }
            },
            'stability': {
                'stability_score': avg_stability,
                'stability_rating': self._get_accumulated_stability_rating(avg_stability)
            }
        }

    def get_recommended_weighting_strategy(self) -> Dict:
        """
        사용자 상황에 맞는 추천 가중치 전략을 반환합니다.
        
        Returns:
            추천 전략과 이유
        """
        analyses = self.get_all_user_analyses()
        num_analyses = len(analyses)
        
        # 기본 추천: adaptive (가장 범용적)
        primary_recommendation = "adaptive"
        reason = "측정 횟수에 따라 자동 최적화되는 가장 스마트한 전략"
        
        # 상황별 추가 추천
        alternatives = []
        
        if num_analyses == 0:
            return {
                "primary": "adaptive",
                "reason": "첫 측정이므로 adaptive 전략으로 시작하세요",
                "alternatives": []
            }
        
        elif num_analyses <= 3:
            alternatives = [
                {"strategy": "composite", "reason": "초기부터 균형잡힌 분석을 원한다면"},
                {"strategy": "stability", "reason": "안정성 높은 측정만 신뢰하고 싶다면"}
            ]
            
        elif num_analyses <= 7:
            alternatives = [
                {"strategy": "stability", "reason": "안정성을 더 중시하고 싶다면"},
                {"strategy": "time", "reason": "최근 성장을 더 반영하고 싶다면"}
            ]
            
        else:  # 8회 이상
            alternatives = [
                {"strategy": "composite", "reason": "일관된 복합 전략을 선호한다면"},
                {"strategy": "time", "reason": "최근 실력 향상을 강조하고 싶다면"},
                {"strategy": "stability", "reason": "가장 안정적인 측정만 중시한다면"}
            ]
        
        # 최근 측정의 안정성 추세 분석
        if num_analyses >= 3:
            recent_analyses = analyses[-3:]  # 최근 3개
            recent_stabilities = [a['stability']['stability_score'] for a in recent_analyses]
            avg_stability = sum(recent_stabilities) / len(recent_stabilities)
            
            if avg_stability < 0.5:
                reason += f" (최근 안정성 {avg_stability:.1%} - 더 안정적인 측정이 필요)"
            elif avg_stability > 0.8:
                reason += f" (최근 안정성 {avg_stability:.1%} - 매우 좋은 측정 품질)"
        
        return {
            "primary": primary_recommendation,
            "reason": reason,
            "alternatives": alternatives,
            "current_analyses": num_analyses
        }
    
    def auto_select_best_strategy(self) -> str:
        """
        현재 상황에서 가장 적절한 가중치 전략을 자동 선택합니다.
        
        Returns:
            추천 가중치 전략명
        """
        recommendation = self.get_recommended_weighting_strategy()
        return recommendation["primary"]


def main():
    """테스트용 메인 함수"""
    
    # 예시 사용법
    manager = VocalProfileManager("user123")
    
    # 1. 자동으로 최적 전략 선택
    best_strategy = manager.auto_select_best_strategy()
    profile = manager.calculate_weighted_profile(best_strategy)

    # 2. 추천 이유와 대안 확인
    recommendation = manager.get_recommended_weighting_strategy()
    print(f"추천 전략: {recommendation['primary']}")
    print(f"이유: {recommendation['reason']}")
    print(f"측정 횟수: {recommendation['current_analyses']}회")

    for alt in recommendation['alternatives']:
        print(f"  대안: {alt['strategy']} - {alt['reason']}")


if __name__ == "__main__":
    main() 