import 'dart:async';
import 'package:flutter/services.dart';

class TensorDspService {
  static const MethodChannel _channel = MethodChannel('tensor_dsp_channel');

  static Future<bool> initialize() async {
    try {
      final bool result = await _channel.invokeMethod('initialize');
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> startRealTimeAnalysis({
    int sampleRate = 44100,
    int bufferSize = 1024,
  }) async {
    try {
      final bool result = await _channel.invokeMethod('startRealTimeAnalysis', {
        'sampleRate': sampleRate,
        'bufferSize': bufferSize,
      });
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> stopRealTimeAnalysis() async {
    try {
      final bool result = await _channel.invokeMethod('stopRealTimeAnalysis');
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, double>> getCurrentPitchScore() async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'getCurrentPitchScore',
      );
      return {
        'pitch': (result['pitch'] as num?)?.toDouble() ?? 0.0,
        'score': (result['score'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e) {
      return {'pitch': 0.0, 'score': 0.0};
    }
  }

  // ... 나머지 기능(피치 추출, MFCC 등)은 그대로 유지 ...
}
