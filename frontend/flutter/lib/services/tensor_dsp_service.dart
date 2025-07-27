import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// TensorDSP 서비스 클래스
/// Android 네이티브 TensorDSP 기능을 Flutter에서 사용할 수 있도록 제공합니다.
class TensorDspService {
  static const MethodChannel _channel = MethodChannel('tensor_dsp_channel');

  /// TensorDSP 초기화
  static Future<bool> initialize() async {
    try {
      final bool result = await _channel.invokeMethod('initialize');
      print('✅ TensorDSP 초기화: $result');
      return result;
    } catch (e) {
      print('❌ TensorDSP 초기화 실패: $e');
      return false;
    }
  }

  /// 오디오 데이터에서 피치 추출
  static Future<List<double>> extractPitch(
    List<double> audioData, {
    int sampleRate = 44100,
    double minFreq = 50.0,
    double maxFreq = 800.0,
  }) async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('extractPitch', {
        'audioData': audioData,
        'sampleRate': sampleRate,
        'minFreq': minFreq,
        'maxFreq': maxFreq,
      });

      return result.cast<double>();
    } catch (e) {
      print('❌ 피치 추출 실패: $e');
      return [];
    }
  }

  /// 실시간 오디오 스트림에서 피치 분석
  static Stream<List<double>> analyzePitchStream({
    int sampleRate = 44100,
    int bufferSize = 1024,
  }) {
    return _channel
        .invokeMethod('startPitchAnalysis', {
          'sampleRate': sampleRate,
          'bufferSize': bufferSize,
        })
        .asStream()
        .map((data) => List<double>.from(data));
  }

  /// 실시간 오디오 분석 시작 (마이크 입력)
  static Future<bool> startRealTimeAnalysis({
    int sampleRate = 44100,
    int bufferSize = 1024,
  }) async {
    try {
      final bool result = await _channel.invokeMethod('startRealTimeAnalysis', {
        'sampleRate': sampleRate,
        'bufferSize': bufferSize,
      });
      print('✅ 실시간 오디오 분석 시작: $result');
      return result;
    } catch (e) {
      print('❌ 실시간 오디오 분석 시작 실패: $e');
      return false;
    }
  }

  /// 실시간 오디오 분석 중지
  static Future<bool> stopRealTimeAnalysis() async {
    try {
      final bool result = await _channel.invokeMethod('stopRealTimeAnalysis');
      print('✅ 실시간 오디오 분석 중지: $result');
      return result;
    } catch (e) {
      print('❌ 실시간 오디오 분석 중지 실패: $e');
      return false;
    }
  }

  /// 실시간 피치 스트림 (마이크에서)
  static Stream<double> get realTimePitchStream {
    return _channel
        .invokeMethod('getRealTimePitchStream')
        .asStream()
        .map((data) => data as double);
  }

  /// 실시간 점수 스트림 (피치 비교 결과)
  static Stream<double> get realTimeScoreStream {
    return _channel
        .invokeMethod('getRealTimeScoreStream')
        .asStream()
        .map((data) => data as double);
  }

  /// 원곡 피치 데이터 설정
  static Future<bool> setOriginalPitchData(List<double> originalPitches) async {
    try {
      final bool result = await _channel.invokeMethod('setOriginalPitchData', {
        'originalPitches': originalPitches,
      });
      print('✅ 원곡 피치 데이터 설정: ${originalPitches.length}개');
      return result;
    } catch (e) {
      print('❌ 원곡 피치 데이터 설정 실패: $e');
      return false;
    }
  }

  /// 피치 비교 및 점수 계산
  static Future<double> comparePitchAndScore({
    required double userPitch,
    required List<double> originalPitches,
    int currentIndex = 0,
  }) async {
    try {
      final double result = await _channel
          .invokeMethod('comparePitchAndScore', {
            'userPitch': userPitch,
            'originalPitches': originalPitches,
            'currentIndex': currentIndex,
          });
      return result;
    } catch (e) {
      print('❌ 피치 비교 및 점수 계산 실패: $e');
      return 0.0;
    }
  }

  /// MFCC (Mel-frequency Cepstral Coefficients) 추출
  /// 음성의 특징 벡터를 추출하여 음색 분석에 사용
  static Future<List<List<double>>> extractMFCC(
    List<double> audioData, {
    int sampleRate = 44100,
    int numCoefficients = 13,
    int numFrames = 40,
  }) async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('extractMFCC', {
        'audioData': audioData,
        'sampleRate': sampleRate,
        'numCoefficients': numCoefficients,
        'numFrames': numFrames,
      });

      return result
          .map<List<double>>((frame) => (frame as List<dynamic>).cast<double>())
          .toList();
    } catch (e) {
      print('❌ MFCC 추출 실패: $e');
      return [];
    }
  }

  /// 100ms마다 최신 점수/피치 값을 받아오는 메서드
  /// MIDI 노트 데이터 설정
  static Future<bool> setMidiNotes(List<Map<String, dynamic>> notes) async {
    try {
      final result = await _channel.invokeMethod('setMidiNotes', {
        'notes': notes,
      });
      return result as bool;
    } catch (e) {
      print('❌ setMidiNotes 실패: $e');
      return false;
    }
  }

  static Future<Map<String, double>> getCurrentPitchScore() async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'getCurrentPitchScore',
      );
      return {
        'score': (result['score'] as num?)?.toDouble() ?? 0.0,
        'pitch': (result['pitch'] as num?)?.toDouble() ?? 0.0,
        'timingScore': (result['timingScore'] as num?)?.toDouble() ?? 0.0,
        'audioLevel': (result['audioLevel'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e) {
      print('❌ getCurrentPitchScore 실패: $e');
      return {
        'score': 0.0,
        'pitch': 0.0,
        'timingScore': 0.0,
        'audioLevel': 0.0,
      };
    }
  }

  /// TensorDSP 정리
  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
      print('✅ TensorDSP 정리 완료');
    } catch (e) {
      print('❌ TensorDSP 정리 실패: $e');
    }
  }
}
