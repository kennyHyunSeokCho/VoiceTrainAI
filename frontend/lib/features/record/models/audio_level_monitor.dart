// 🎵 실시간 오디오 레벨 모니터링 클래스
// record 패키지의 amplitude 스트림을 활용하여 실시간으로 오디오 레벨을 감지하고
// 데시벨 단위로 변환하여 임계값 판단에 사용합니다.
//
// 이 클래스는 마이크로 입력되는 소리의 크기를 실시간으로 측정하여
// 음성 인식 시스템이 "지금 사용자가 말하고 있는가?"를 판단할 수 있게 해줍니다.

import 'dart:async';
import 'dart:math' as math;
import 'package:record/record.dart';
import 'package:flutter/foundation.dart';

/// 오디오 레벨을 실시간으로 모니터링하는 클래스
/// 
/// 이 클래스는 음성 녹음 앱의 핵심 구성 요소로, 다음과 같은 역할을 합니다:
/// 
/// 1. **실시간 오디오 레벨 감지**: 마이크로 입력되는 소리의 크기를 실시간으로 측정
/// 2. **데시벨 변환**: raw amplitude 값을 실제 환경 데시벨로 변환
/// 3. **임계값 비교**: 설정된 임계값과 비교하여 음성/배경음 구분
/// 4. **콜백 알림**: 상태 변화 시 즉시 알림을 통해 UI 업데이트 지원
/// 
/// **사용 흐름**:
/// 1. startMonitoring() 호출로 모니터링 시작
/// 2. 100ms마다 amplitude 값 수신
/// 3. amplitude → 데시벨 변환 
/// 4. 임계값과 비교하여 상태 판단
/// 5. 콜백을 통해 UI 업데이트
/// 6. stopMonitoring() 호출로 모니터링 중지
class AudioLevelMonitor {
  
  // === 모니터링 관련 핵심 객체들 ===
  
  /// record 패키지의 녹음 객체
  /// 
  /// 이 객체는 실제 녹음 기능과는 별도로 amplitude 스트림만을 위해 사용됩니다.
  /// amplitude 스트림: 마이크 입력의 크기를 실시간으로 제공하는 데이터 스트림
  final AudioRecorder _recorder = AudioRecorder();
  
  /// amplitude 스트림 구독 객체
  /// 
  /// record 패키지에서 제공하는 amplitude 스트림을 구독하여
  /// 100ms마다 새로운 오디오 레벨 데이터를 받아옵니다.
  /// 이 구독은 모니터링을 중지할 때 적절히 해제되어야 합니다.
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  
  // === 콜백 함수들 - 외부와의 통신 인터페이스 ===
  
  /// 레벨이 업데이트될 때 호출될 콜백 함수
  /// 
  /// 매개변수: double (현재 데시벨 레벨)
  /// 호출 빈도: 100ms마다
  /// 용도: UI의 실시간 레벨 바 업데이트, 현재 레벨 표시
  Function(double)? onLevelUpdate;
  
  /// 임계값 통과 여부가 변경될 때 호출될 콜백 함수
  /// 
  /// 매개변수: bool (true: 임계값 초과, false: 임계값 미달)
  /// 호출 조건: 상태가 실제로 변경되었을 때만 (노이즈 감소)
  /// 용도: 녹음 상태 제어, 음성 감지/미감지 알림
  Function(bool)? onThresholdChange;
  
  // === 현재 상태 추적 변수들 ===
  
  /// 현재 raw amplitude 값 (0.0 ~ 1.0 범위)
  /// 
  /// record 패키지에서 직접 제공하는 원시 값입니다.
  /// 0.0: 완전한 무음 상태
  /// 1.0: 최대 입력 레벨 (마이크가 감지할 수 있는 최대 크기)
  double _currentAmplitude = 0.0;
  
  /// 현재 데시벨 값 (실제 환경 dB)
  /// 
  /// amplitude 값을 실제 환경에서 측정되는 데시벨로 변환한 값입니다.
  /// 범위: 20dB(매우 조용함) ~ 90dB(매우 큰 소리)
  /// 이 값이 임계값과 비교되어 음성/배경음을 구분합니다.
  double _currentDecibel = -100.0;
  
  /// 현재 모니터링 중인지 여부
  /// 
  /// true: amplitude 스트림을 구독하여 실시간 모니터링 중
  /// false: 모니터링 중지 상태 (리소스 절약)
  bool _isMonitoring = false;
  
  /// 이전 상태에서 임계값을 넘었는지 여부 (상태 변화 감지용)
  /// 
  /// 이 변수는 상태 변화를 감지하기 위해 사용됩니다.
  /// 예: false → true (임계값 미달에서 초과로 변경)
  /// 상태가 변경되었을 때만 콜백을 호출하여 불필요한 알림을 방지합니다.
  bool _wasAboveThreshold = false;
  
  // === 데시벨 변환 설정 상수들 ===
  
  /// 최소 데시벨 값: 20dB (매우 조용한 환경)
  /// 
  /// 일반적인 실내 환경에서 측정되는 최소 소음 레벨입니다.
  /// 예: 깊은 밤 조용한 방, 도서관 내부
  static const double _minDecibel = 20.0;
  
  /// 최대 데시벨 값: 90dB (매우 큰 소리)
  /// 
  /// 일반적인 마이크가 왜곡 없이 감지할 수 있는 최대 레벨입니다.
  /// 예: 큰 소리로 외치기, 음악 스피커 근처
  /// 참고: 실제 환경에서는 더 큰 소리도 있지만, 음성 인식 목적으로는 90dB면 충분
  static const double _maxDecibel = 90.0;
  
  // === 외부에서 현재 상태를 확인하기 위한 Getter들 ===
  
  /// 현재 raw amplitude 값 반환 (0.0 ~ 1.0)
  /// 
  /// 디버깅이나 고급 사용자를 위한 원시 데이터입니다.
  /// 일반적으로는 currentDecibel을 사용하는 것이 더 직관적입니다.
  double get currentAmplitude => _currentAmplitude;
  
  /// 현재 데시벨 값 반환 (실제 환경 dB)
  /// 
  /// UI 표시나 임계값 비교에 사용되는 주요 값입니다.
  /// 이 값이 사용자에게 표시되는 "현재 소리 크기"입니다.
  double get currentDecibel => _currentDecibel;
  
  /// 현재 모니터링 중인지 여부 반환
  /// 
  /// UI에서 "실시간 모니터링 중" 표시를 위해 사용됩니다.
  bool get isMonitoring => _isMonitoring;

  /// 오디오 레벨 모니터링을 시작합니다
  /// 
  /// 이 메서드는 실시간 오디오 레벨 감지를 시작하는 핵심 메서드입니다.
  /// 마이크 권한이 필요하며, 이미 모니터링 중이라면 중복 시작을 방지합니다.
  /// 
  /// **동작 과정**:
  /// 1. 이미 모니터링 중인지 확인 (중복 방지)
  /// 2. 마이크 권한 확인
  /// 3. amplitude 스트림 구독 시작
  /// 4. 100ms마다 콜백 처리 설정
  /// 5. 모니터링 상태 활성화
  /// 
  /// [thresholdDecibel]: 음성/배경음을 구분할 임계값 (데시벨 단위)
  ///                     예: 60dB (일반적인 대화 수준)
  /// [onLevelUpdate]: 레벨이 업데이트될 때마다 호출될 함수
  ///                  매개변수: double (현재 데시벨 레벨)
  /// [onThresholdChange]: 임계값 통과 여부가 변경될 때 호출될 함수
  ///                      매개변수: bool (true: 초과, false: 미달)
  Future<void> startMonitoring({
    required double thresholdDecibel,
    Function(double)? onLevelUpdate,
    Function(bool)? onThresholdChange,
  }) async {
    try {
      // 1단계: 중복 시작 방지
      if (_isMonitoring) {
        print('⚠️ 이미 모니터링 중입니다');
        return;
      }

      print('🎵 오디오 레벨 모니터링 시작...');
      
      // 2단계: 콜백 함수들 저장 (나중에 호출하기 위해)
      this.onLevelUpdate = onLevelUpdate;
      this.onThresholdChange = onThresholdChange;
      
      // 3단계: 마이크 권한 확인
      if (await _recorder.hasPermission()) {
        // 4단계: amplitude 스트림 구독 시작
        // Duration(milliseconds: 100): 100ms마다 새로운 데이터 수신
        _amplitudeSubscription = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100))
            .listen((Amplitude amplitude) {
          // 새로운 amplitude 데이터가 도착할 때마다 처리
          _handleAmplitudeUpdate(amplitude, thresholdDecibel);
        }, onError: (error) {
          // 스트림에서 오류가 발생한 경우 로깅
          print('❌ Amplitude 스트림 오류: $error');
        });

        // 5단계: 모니터링 상태 활성화
        _isMonitoring = true;
        print('✅ 오디오 레벨 모니터링 시작 완료');
      } else {
        // 마이크 권한이 없는 경우 예외 발생
        throw Exception('마이크 권한이 필요합니다');
      }
    } catch (e) {
      print('❌ 오디오 레벨 모니터링 시작 오류: $e');
      throw e; // 상위 레벨에서 처리할 수 있도록 예외 전파
    }
  }

  /// 오디오 레벨 모니터링을 중지합니다
  /// 
  /// 이 메서드는 모니터링을 안전하게 중지하고 모든 리소스를 정리합니다.
  /// 메모리 누수 방지를 위해 반드시 호출되어야 합니다.
  /// 
  /// **정리 작업**:
  /// 1. amplitude 스트림 구독 해제
  /// 2. 모니터링 상태 비활성화  
  /// 3. 모든 상태 변수 초기화
  /// 4. 메모리 정리
  Future<void> stopMonitoring() async {
    try {
      print('🛑 오디오 레벨 모니터링 중지...');
      
      // 1단계: 스트림 구독 해제 (메모리 누수 방지)
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
      
      // 2단계: 모든 상태 변수 초기화
      _isMonitoring = false;           // 모니터링 중지
      _currentAmplitude = 0.0;         // amplitude 초기화
      _currentDecibel = _minDecibel;   // 데시벨을 최소값으로 설정
      _wasAboveThreshold = false;      // 임계값 상태 초기화
      
      print('✅ 오디오 레벨 모니터링 중지 완료');
    } catch (e) {
      print('❌ 오디오 레벨 모니터링 중지 오류: $e');
    }
  }

  /// Amplitude 업데이트를 처리하는 핵심 내부 메서드
  /// 
  /// 이 메서드는 100ms마다 호출되어 새로운 amplitude 데이터를 처리합니다.
  /// 음성 인식 시스템의 핵심 로직이 여기에 구현되어 있습니다.
  /// 
  /// **처리 과정**:
  /// 1. raw amplitude 값 추출 및 정규화
  /// 2. amplitude → 데시벨 변환
  /// 3. 레벨 업데이트 콜백 호출
  /// 4. 임계값 비교 및 상태 변화 감지
  /// 5. 상태 변화 시 콜백 호출
  /// 
  /// [amplitude]: record 패키지에서 제공하는 amplitude 객체
  ///              current: 현재 순간 amplitude
  ///              max: 측정 구간 내 최대 amplitude
  /// [thresholdDecibel]: 비교할 임계값 (데시벨 단위)
  void _handleAmplitudeUpdate(Amplitude amplitude, double thresholdDecibel) {
    try {
      // 1단계: raw amplitude 값 추출
      // current와 max 중 더 큰 값을 사용하여 더 정확한 레벨 감지
      // 이렇게 하면 순간적인 큰 소리도 놓치지 않을 수 있습니다
      double rawAmplitude = math.max(amplitude.current, amplitude.max);
      
      // 2단계: amplitude 값 정규화 (0.0 ~ 1.0 범위로 제한)
      // 간혹 1.0을 초과하는 값이 올 수 있어 안전하게 제한합니다
      _currentAmplitude = rawAmplitude.clamp(0.0, 1.0);
      
      // 3단계: amplitude를 실제 환경 데시벨로 변환
      _currentDecibel = _amplitudeToDecibel(_currentAmplitude);
      
      // 4단계: 레벨 업데이트 콜백 호출 (UI 업데이트용)
      // UI의 실시간 레벨 바가 여기서 업데이트됩니다
      onLevelUpdate?.call(_currentDecibel);
      
      // 5단계: 임계값 통과 여부 확인
      bool currentlyAboveThreshold = _currentDecibel > thresholdDecibel;
      
      // 6단계: 상태 변화 감지 및 콜백 호출
      // 중요: 상태가 실제로 변경되었을 때만 콜백 호출 (노이즈 감소)
      // 예: false → true (임계값 미달에서 초과로 변경)
      if (currentlyAboveThreshold != _wasAboveThreshold) {
        _wasAboveThreshold = currentlyAboveThreshold;
        
        // 상태 변화 콜백 호출 (녹음 제어에 사용됨)
        onThresholdChange?.call(currentlyAboveThreshold);
        
        // 디버그 모드에서만 상세 로그 출력
        if (kDebugMode) {
          print('🎚️ 임계값 ${currentlyAboveThreshold ? "초과" : "미달"}: '
              '${_currentDecibel.toStringAsFixed(1)}dB (임계값: ${thresholdDecibel.toStringAsFixed(1)}dB)');
        }
      }
      
    } catch (e) {
      print('❌ Amplitude 처리 오류: $e');
    }
  }

  /// Amplitude 값을 실제 환경 데시벨로 변환하는 핵심 메서드
  /// 
  /// 이 메서드는 record 패키지에서 제공하는 0.0~1.0 범위의 amplitude 값을
  /// 실제 환경에서 측정되는 데시벨(dB) 값으로 변환합니다.
  /// 
  /// **변환 공식**:
  /// - 선형 매핑 방식 사용 (단순하지만 효과적)
  /// - 0.0 (무음) → 20dB (매우 조용한 환경)
  /// - 1.0 (최대) → 90dB (매우 큰 소리)
  /// 
  /// **주의사항**:
  /// - 이는 근사치이며, 실제 물리적 데시벨과는 차이가 있을 수 있습니다
  /// - 하지만 상대적 비교와 임계값 판단에는 충분히 유용합니다
  /// 
  /// [amplitude]: 0.0 ~ 1.0 범위의 amplitude 값
  /// 반환값: 실제 환경 데시벨 값 (20dB ~ 90dB)
  double _amplitudeToDecibel(double amplitude) {
    // 완전한 무음 상태 처리
    if (amplitude <= 0.0) {
      return _minDecibel; // 20dB (매우 조용한 상태)
    }
    
    // 선형 매핑을 통한 데시벨 변환
    // 공식: 최소값 + (입력비율 × 범위)
    // 예: amplitude = 0.5라면
    //     20 + (0.5 × (90-20)) = 20 + 35 = 55dB
    double decibel = _minDecibel + (amplitude * (_maxDecibel - _minDecibel));
    
    // 안전을 위해 유효한 범위로 제한
    return decibel.clamp(_minDecibel, _maxDecibel);
  }

  /// 현재 오디오 레벨이 지정된 임계값을 넘는지 즉시 확인
  /// 
  /// 이 메서드는 콜백을 기다리지 않고 현재 상태를 즉시 확인할 때 사용됩니다.
  /// 
  /// [thresholdDecibel]: 확인할 임계값 (데시벨 단위)
  /// 반환값: true(임계값 초과), false(임계값 미달)
  /// 
  /// 사용 예시:
  /// ```dart
  /// if (monitor.isAboveThreshold(60.0)) {
  ///   print("현재 음성이 감지됨");
  /// }
  /// ```
  bool isAboveThreshold(double thresholdDecibel) {
    return _currentDecibel > thresholdDecibel;
  }

  /// 현재 레벨과 임계값의 차이를 수치로 반환
  /// 
  /// 현재 소리가 임계값보다 얼마나 크거나 작은지 정확한 수치로 확인할 수 있습니다.
  /// UI에서 "임계값까지 5dB 부족" 같은 정보를 표시할 때 유용합니다.
  /// 
  /// [thresholdDecibel]: 기준이 될 임계값
  /// 반환값: 차이 값 (양수: 초과, 음수: 미달, 0: 동일)
  /// 
  /// 사용 예시:
  /// ```dart
  /// double diff = monitor.getDifferenceFromThreshold(60.0);
  /// if (diff > 0) {
  ///   print("임계값보다 ${diff.toStringAsFixed(1)}dB 큼");
  /// } else {
  ///   print("임계값보다 ${(-diff).toStringAsFixed(1)}dB 작음");
  /// }
  /// ```
  double getDifferenceFromThreshold(double thresholdDecibel) {
    return _currentDecibel - thresholdDecibel;
  }

  /// 모든 리소스를 정리하는 메서드
  /// 
  /// 이 메서드는 AudioLevelMonitor 객체가 더 이상 필요하지 않을 때 호출되어
  /// 모든 리소스를 안전하게 해제합니다. 메모리 누수 방지를 위해 중요합니다.
  /// 
  /// **정리 작업**:
  /// 1. 모니터링 중지 (스트림 구독 해제)
  /// 2. AudioRecorder 객체 해제
  /// 3. 모든 콜백 및 상태 초기화
  /// 
  /// 주로 RecordingProvider의 dispose() 메서드에서 호출됩니다.
  void dispose() {
    stopMonitoring();    // 모니터링 중지 및 스트림 정리
    _recorder.dispose(); // AudioRecorder 객체 리소스 해제
  }
}

