import 'dart:async';
import 'package:flutter/services.dart';

class AudioComparePlugin {
  static const MethodChannel _method = MethodChannel(
    'audio_compare_plugin/method',
  );
  static const EventChannel _scoreEvent = EventChannel(
    'audio_compare_plugin/score',
  );
  static const EventChannel _pitchEvent = EventChannel(
    'audio_compare_plugin/pitch',
  );
  static const EventChannel _onsetEvent = EventChannel(
    'audio_compare_plugin/onset',
  );

  // MethodChannel: Native에 명령 보내기
  static Future<void> startAnalysis(Map<String, dynamic> params) async {
    await _method.invokeMethod('startAnalysis', params);
  }

  static Future<void> stopAnalysis() async {
    await _method.invokeMethod('stopAnalysis');
  }

  // EventChannel: Native에서 실시간 데이터 받기
  static Stream<double> get scoreStream =>
      _scoreEvent.receiveBroadcastStream().map((event) => event as double);

  static Stream<double> get pitchStream =>
      _pitchEvent.receiveBroadcastStream().map((event) => event as double);

  static Stream<double> get onsetStream =>
      _onsetEvent.receiveBroadcastStream().map((event) => event as double);
}
