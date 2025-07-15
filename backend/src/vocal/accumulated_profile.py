import statistics
from datetime import datetime
from typing import List, Dict, Optional
import numpy as np
import logging

logger = logging.getLogger(__name__)

def calculate_adaptive_weights(analysis_data: list) -> list:
    try:
        current_time = datetime.now()
        weighted_data = []
        for i, data in enumerate(analysis_data):
            analysis_time = datetime.fromisoformat(data['timestamp'])
            days_ago = (current_time - analysis_time).days
            time_weight = 0.5 ** (days_ago / 30.0)
            stability_score = data['stability']['stability_score']
            stability_weight = max(0.1, 1.0 - (stability_score / 100.0))
            frequency_weight = 1.0 / (1.0 + i * 0.1)
            jitter = data['stability']['jitter']
            shimmer = data['stability']['shimmer']
            jitter_weight = max(0.1, 1.0 - (jitter / 10.0))
            shimmer_weight = max(0.1, 1.0 - (shimmer / 20.0))
            quality_weight = (jitter_weight + shimmer_weight) / 2.0
            combined_weight = (
                time_weight * 0.3 +
                stability_weight * 0.25 +
                frequency_weight * 0.2 +
                quality_weight * 0.25
            )
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
        weighted_data.sort(key=lambda x: x['weights']['combined_weight'], reverse=True)
        return weighted_data
    except Exception as e:
        logger.error(f"가중치 계산 실패: {str(e)}")
        return []

def calculate_weighted_accumulated_profile(weighted_data: list, freq_to_note) -> Optional[Dict]:
    try:
        if not weighted_data:
            return None
        total_weight = sum(data['weights']['combined_weight'] for data in weighted_data)
        if total_weight == 0:
            return None
        comfortable_min_freqs = []
        comfortable_max_freqs = []
        comfortable_weights = []
        core_min_freqs = []
        core_max_freqs = []
        core_weights = []
        stability_scores = []
        jitter_scores = []
        shimmer_scores = []
        stability_weights = []
        for data in weighted_data:
            weight = data['weights']['combined_weight']
            comfortable_range = data['pitch_range']['comfortable_range']
            comfortable_min_freqs.append(comfortable_range['min_freq'])
            comfortable_max_freqs.append(comfortable_range['max_freq'])
            comfortable_weights.append(weight)
            core_range = data['pitch_range']['core_range']
            core_min_freqs.append(core_range['min_freq'])
            core_max_freqs.append(core_range['max_freq'])
            core_weights.append(weight)
            stability = data['stability']
            stability_scores.append(stability['stability_score'])
            jitter_scores.append(stability['jitter'])
            shimmer_scores.append(stability['shimmer'])
            stability_weights.append(weight)
        def weighted_average(values, weights):
            return sum(v * w for v, w in zip(values, weights)) / sum(weights)
        comfortable_min_avg = weighted_average(comfortable_min_freqs, comfortable_weights)
        comfortable_max_avg = weighted_average(comfortable_max_freqs, comfortable_weights)
        core_min_avg = weighted_average(core_min_freqs, core_weights)
        core_max_avg = weighted_average(core_max_freqs, core_weights)
        stability_avg = weighted_average(stability_scores, stability_weights)
        jitter_avg = weighted_average(jitter_scores, stability_weights)
        shimmer_avg = weighted_average(shimmer_scores, stability_weights)
        accumulated_profile = {
            'vocal_profile': {
                'comfortable_range': {
                    'min_freq': float(comfortable_min_avg),
                    'max_freq': float(comfortable_max_avg),
                    'min_note': freq_to_note(comfortable_min_avg),
                    'max_note': freq_to_note(comfortable_max_avg),
                    'range_semitones': float(12 * np.log2(comfortable_max_avg / comfortable_min_avg)) if comfortable_min_avg > 0 else 0
                },
                'core_range': {
                    'min_freq': float(core_min_avg),
                    'max_freq': float(core_max_avg),
                    'min_note': freq_to_note(core_min_avg),
                    'max_note': freq_to_note(core_max_avg),
                    'range_semitones': float(12 * np.log2(core_max_avg / core_min_avg)) if core_min_avg > 0 else 0
                },
                'stability_profile': {
                    'average_stability_score': float(stability_avg),
                    'average_jitter': float(jitter_avg),
                    'average_shimmer': float(shimmer_avg),
                    # confidence_level은 아래 함수에서 계산
                },
                'analysis_summary': {
                    'total_analyses': len(weighted_data),
                    'most_recent_analysis': weighted_data[0]['timestamp'],
                    'oldest_analysis': weighted_data[-1]['timestamp'],
                    'average_weight': float(total_weight / len(weighted_data)),
                    'weight_distribution': calculate_weight_distribution(weighted_data)
                }
            }
        }
        return accumulated_profile
    except Exception as e:
        logger.error(f"누적 프로필 계산 실패: {str(e)}")
        return None

def calculate_confidence_level(weighted_data: list) -> float:
    try:
        if not weighted_data:
            return 0.0
        data_count = len(weighted_data)
        quantity_score = min(100, data_count * 10)
        time_distribution_score = 50.0
        if len(weighted_data) > 1:
            days_ago_list = [data['days_ago'] for data in weighted_data]
            if len(set(days_ago_list)) > 1:
                time_std = statistics.stdev(days_ago_list)
                time_distribution_score = min(100.0, time_std * 2)
        stability_consistency_score = 50.0
        if len(weighted_data) > 1:
            stability_scores = [data['stability']['stability_score'] for data in weighted_data]
            stability_std = statistics.stdev(stability_scores)
            stability_consistency_score = max(0.0, 100.0 - stability_std)
        weight_distribution_score = 50.0
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

def calculate_weight_distribution(weighted_data: list) -> Dict:
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