// 🎚️ 데시벨 임계값 상태 표시 위젯
// 하드코딩된 최적화된 임계값 상태와 현재 오디오 레벨을 표시합니다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recording_provider.dart';

/// 데시벨 임계값 상태 표시 위젯
/// 복잡한 조정 기능 대신 현재 상태만 표시하는 단순한 UI
class AudioThresholdControlWidget extends StatelessWidget {
  const AudioThresholdControlWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (context, recordingProvider, child) {
        final thresholdSettings = recordingProvider.thresholdSettings;
        
        return Card(
          margin: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === 제목 ===
                const Text(
                  '🎚️ 음성 감지 상태',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // === 현재 임계값 정보 (하드코딩됨) ===
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.settings, color: Colors.blue[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '최적화된 임계값: ${thresholdSettings.threshold.toStringAsFixed(0)}dB',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        thresholdSettings.thresholdDescription,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // === 실시간 오디오 레벨 표시 ===
                const AudioLevelIndicator(),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 실시간 오디오 레벨을 시각적으로 표시하는 위젯
class AudioLevelIndicator extends StatelessWidget {
  const AudioLevelIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (context, recordingProvider, child) {
        final currentLevel = recordingProvider.currentAudioLevel;
        final threshold = recordingProvider.thresholdSettings.threshold;
        final silenceThreshold = recordingProvider.thresholdSettings.silenceThreshold;
        final isMonitoring = recordingProvider.isLevelMonitoring;
        final isBelowThreshold = recordingProvider.isBelowThreshold;
        final thresholdSettings = recordingProvider.thresholdSettings;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === 현재 상태 표시 ===
            Row(
              children: [
                // 상태 아이콘
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: thresholdSettings.isAboveThreshold 
                        ? Colors.green
                        : thresholdSettings.isSilent 
                            ? Colors.grey
                            : Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  thresholdSettings.voiceStatusDescription,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: thresholdSettings.isAboveThreshold 
                        ? Colors.green[700]
                        : thresholdSettings.isSilent 
                            ? Colors.grey[600]
                            : Colors.orange[700],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // === 현재 레벨 숫자 표시 ===
            Text(
              '현재 레벨: ${currentLevel.toStringAsFixed(1)}dB (${thresholdSettings.levelDescription})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // === 시각적 레벨 바 ===
            Container(
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // 배경
                    Container(
                      width: double.infinity,
                      color: Colors.grey[100],
                    ),
                    
                    // 현재 레벨 바
                    FractionallySizedBox(
                      widthFactor: (currentLevel / 100).clamp(0.0, 1.0),
                      child: Container(
                        height: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green[300]!,
                              Colors.yellow[300]!,
                              Colors.red[300]!,
                            ],
                            stops: const [0.0, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                    
                    // 임계값 선들
                    Positioned(
                      left: (silenceThreshold / 100) * MediaQuery.of(context).size.width * 0.8,
                      child: Container(
                        width: 2,
                        height: double.infinity,
                        color: Colors.grey[400],
                      ),
                    ),
                    Positioned(
                      left: (threshold / 100) * MediaQuery.of(context).size.width * 0.8,
                      child: Container(
                        width: 2,
                        height: double.infinity,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // === 범례 ===
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLegendItem('0dB', Colors.grey[400]!),
                _buildLegendItem('무음 (${silenceThreshold.toInt()}dB)', Colors.grey[400]!),
                _buildLegendItem('음성 (${threshold.toInt()}dB)', Colors.blue[600]!),
                _buildLegendItem('100dB', Colors.grey[400]!),
              ],
            ),
            
            // === 모니터링 상태 ===
            if (isMonitoring) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '실시간 모니터링 중',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
  
  Widget _buildLegendItem(String label, Color color) {
    return Column(
      children: [
        Container(
          width: 2,
          height: 8,
          color: color,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
} 