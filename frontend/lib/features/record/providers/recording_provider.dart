// 🎤 음성 녹음 앱을 위한 상태 관리 프로바이더
// 이 파일은 음성 녹음, 재생, 파일 관리 등의 핵심 기능을 담당합니다.

// Flutter 기본 라이브러리들
import 'package:flutter/foundation.dart'; // kIsWeb 등 플랫폼 구분을 위한 상수들
import 'package:flutter/material.dart';    // ChangeNotifier 등 Flutter 위젯 관련 클래스들

// 음성 녹음 및 재생을 위한 외부 패키지들
import 'package:record/record.dart';                    // 음성 녹음을 위한 패키지
import 'package:audioplayers/audioplayers.dart';       // 음성 파일 재생을 위한 패키지
import 'package:permission_handler/permission_handler.dart'; // 마이크 권한 관리를 위한 패키지
import 'package:path_provider/path_provider.dart';     // 파일 저장 경로 관리를 위한 패키지

// Dart 기본 라이브러리들
import 'dart:async';  // Timer, Future 등 비동기 처리를 위한 클래스들
import 'dart:io';     // File, Directory 등 파일 시스템 접근을 위한 클래스들

// 웹 환경에서 파일 다운로드를 위한 조건부 import
// 웹 환경일 때만 web_download_web.dart를 import하고, 
// 다른 환경에서는 web_download_stub.dart를 import
import '../../../core/utils/web_download_stub.dart'
    if (dart.library.html) '../../../core/utils/web_download_web.dart';

// 데시벨 임계값 관련 모델들
import '../models/audio_threshold_settings.dart';
import '../models/audio_level_monitor.dart';

// 📱 녹음된 음성 파일의 정보를 담는 데이터 모델 클래스
// 각 녹음 파일의 메타데이터를 구조화하여 관리합니다.
class RecordingItem {
  final String path;          // 파일이 저장된 전체 경로 (예: /path/to/recording.wav)
  final String name;          // 사용자가 보게 될 파일명 (예: recording_123456.wav)
  final DateTime timestamp;   // 녹음이 생성된 날짜와 시간
  final int size;            // 파일 크기 (바이트 단위)
  final Duration? duration;   // 녹음 길이 (옵션, 현재는 사용하지 않음)

  // 생성자: 필수 매개변수들을 받아 RecordingItem 객체를 생성
  RecordingItem({
    required this.path,      // 파일 경로는 필수
    required this.name,      // 파일명은 필수
    required this.timestamp, // 생성 시간은 필수
    required this.size,      // 파일 크기는 필수
    this.duration,          // 녹음 길이는 선택사항
  });
}

// 🎤 음성 녹음 기능의 모든 상태와 동작을 관리하는 메인 프로바이더 클래스
// ChangeNotifier를 상속받아 상태 변경 시 UI에 자동으로 알림을 보냅니다.
class RecordingProvider with ChangeNotifier {
  // === 핵심 녹음/재생 객체들 ===
  final AudioRecorder _recorder = AudioRecorder(); // 음성 녹음을 담당하는 객체
  final AudioPlayer _player = AudioPlayer();       // 음성 재생을 담당하는 객체
  
  // === 데시벨 임계값 관련 객체들 ===
  final AudioThresholdSettings _thresholdSettings = AudioThresholdSettings(); // 임계값 설정 관리
  final AudioLevelMonitor _levelMonitor = AudioLevelMonitor();                // 오디오 레벨 모니터링
  
  // === 녹음 상태 관리 변수들 ===
  bool _isRecording = false;              // 현재 녹음 중인지 여부
  bool _isPlaying = false;                // 현재 재생 중인지 여부
  Duration _recordingDuration = Duration.zero; // 현재 녹음 시간 (실시간 업데이트)
  Timer? _timer;                          // 녹음 시간을 1초마다 업데이트하는 타이머
  String? _recordingPath;                 // 현재 녹음 중인 파일의 저장 경로
  
  // === 임계값 관련 상태 변수들 ===
  bool _isBelowThreshold = false;         // 현재 임계값 미달 상태인지 여부
  Duration _belowThresholdDuration = Duration.zero; // 임계값 미달 지속 시간
  int _belowThresholdSeconds = 0;         // 임계값 미달 상태의 총 초 수
  bool _isActuallyRecording = false;      // 실제로 음성이 녹음되고 있는지 여부 (임계값 기반)
  bool _waitingForVoice = false;          // 음성 입력을 대기 중인지 여부
  
  // === 녹음 파일 목록 관리 ===
  final List<RecordingItem> _recordings = []; // 녹음된 파일들의 목록 (최신순)
  
  // === 외부에서 상태를 읽기 위한 Getter들 ===
  // private 변수들을 외부에서 안전하게 읽을 수 있도록 제공
  bool get isRecording => _isRecording;           // 녹음 중 여부 확인
  bool get isPlaying => _isPlaying;               // 재생 중 여부 확인
  Duration get recordingDuration => _recordingDuration; // 현재 녹음 시간 확인
  List<RecordingItem> get recordings => List.unmodifiable(_recordings); // 녹음 목록 (수정 불가능한 복사본)
  
  // === 데시벨 임계값 관련 Getter들 ===
  AudioThresholdSettings get thresholdSettings => _thresholdSettings; // 임계값 설정 객체
  bool get isBelowThreshold => _isBelowThreshold;           // 현재 임계값 미달 상태 여부
  Duration get belowThresholdDuration => _belowThresholdDuration; // 임계값 미달 지속 시간
  double get currentAudioLevel => _levelMonitor.currentDecibel;   // 현재 오디오 레벨 (dB)
  bool get isLevelMonitoring => _levelMonitor.isMonitoring;       // 레벨 모니터링 중 여부
  bool get isActuallyRecording => _isActuallyRecording;     // 실제로 음성이 녹음되고 있는지 여부
  bool get waitingForVoice => _waitingForVoice;             // 음성 입력을 대기 중인지 여부

  // === 생성자 ===
  RecordingProvider() {
    // 임계값 설정 변경 시 UI 업데이트를 위한 리스너 등록
    _thresholdSettings.addListener(() {
      notifyListeners(); // 임계값 설정이 변경되면 UI 업데이트
    });
  }

  // === 마이크 권한 확인 및 요청 메서드 ===
  // 플랫폼별로 다른 권한 처리 방식을 적용합니다.
  Future<bool> _checkPermissions() async {
    try {
      print('🔍 권한 확인 시작...');
      
      if (kIsWeb) {
        // 웹 환경: 브라우저가 자동으로 권한 요청 다이얼로그를 표시
        // getUserMedia API 호출 시 자동으로 권한이 요청됨
        print('🌐 웹 환경에서 마이크 권한 확인');
        return true; 
      }

      // 모바일/데스크톱 환경: permission_handler 패키지를 사용한 권한 관리
      PermissionStatus status = await Permission.microphone.status;
      print('📱 네이티브 권한 상태: $status');
      
      // 권한이 거부된 상태라면 사용자에게 권한 요청
      if (status.isDenied) {
        print('🔒 권한 요청 중...');
        status = await Permission.microphone.request();
        print('✅ 권한 요청 결과: $status');
      }
      
      return status.isGranted; // 권한이 허용되었는지 여부 반환
    } catch (e) {
      print('❌ 권한 확인 오류: $e');
      return false; // 오류 발생 시 권한 없음으로 처리
    }
  }

  // === 음성 녹음 시작 메서드 ===
  // 사용자가 녹음 버튼을 눌렀을 때 호출되는 핵심 메서드
  Future<void> startRecording() async {
    try {
      print('🚀 녹음 시작 프로세스 시작...');
      
      // 1단계: 마이크 권한 확인 및 요청
      bool hasPermission = await _checkPermissions();
      if (!hasPermission) {
        print('❌ 마이크 권한이 거부되었습니다');
        throw Exception('마이크 권한이 필요합니다');
      }
      print('✅ 마이크 권한 확인 완료');

      // 2단계: 중복 녹음 방지 - 이미 녹음 중이라면 함수 종료
      print('🎤 현재 녹음 상태: $_isRecording');
      if (_isRecording) {
        print('⚠️ 이미 녹음 중입니다');
        return;
      }

      // 3단계: 플랫폼별 파일 저장 경로 설정
      // 현재 시간을 이용해 고유한 파일명 생성
      String fileName = 'voice_recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      if (kIsWeb) {
        // 웹 환경: 단순한 파일명만 설정 (브라우저가 다운로드 폴더에 저장)
        _recordingPath = fileName;
        print('🌐 웹 녹음 파일: $fileName');
      } else {
        // 모바일/데스크톱 환경: 앱 전용 폴더에 파일 저장
        Directory documentsDir = await getApplicationDocumentsDirectory(); // 앱 문서 폴더 경로 가져오기
        Directory recordingDir = Directory('${documentsDir.path}/VoiceTraining_Recordings'); // 전용 녹음 폴더 생성
        
        // 폴더가 없다면 생성
        if (!await recordingDir.exists()) {
          await recordingDir.create(recursive: true);
        }
        
        _recordingPath = '${recordingDir.path}/$fileName';
        print('📱 모바일 녹음 파일: $_recordingPath');
      }

      // 4단계: 플랫폼별 녹음 설정 및 실제 녹음 시작
      print('⏺️ AudioRecorder.start() 호출...');
      
      // 모든 플랫폼에서 WAV 형식 사용 (무손실, 호환성 우수)
      print('🎵 WAV 형식으로 녹음 시작 (무손실 품질)');
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,   // WAV 형식 (무손실, 호환성 좋음)
          bitRate: 128000,            // 128kbps 품질 (음성 녹음에 적합)
          sampleRate: 44100,          // 44.1kHz 샘플링 (CD 품질)
        ),
        path: _recordingPath!,
      );

      // 5단계: 녹음 시작 확인
      bool recordingStarted = await _recorder.isRecording();
      print('🔴 녹음 시작 확인: $recordingStarted');
      
      if (!recordingStarted) {
        throw Exception('녹음을 시작할 수 없습니다');
      }

      // 6단계: 상태 업데이트 및 타이머 시작
      _isRecording = true;
      _recordingDuration = Duration.zero;
      _isBelowThreshold = false;
      _belowThresholdDuration = Duration.zero;
      _belowThresholdSeconds = 0;
      _isActuallyRecording = !_thresholdSettings.isEnabled; // 임계값 비활성화시 즉시 녹음
      _waitingForVoice = _thresholdSettings.isEnabled;      // 임계값 활성화시 음성 대기
      
      // 1초마다 녹음 시간을 업데이트하는 타이머 시작
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordingDuration = Duration(seconds: timer.tick);
        
        // 임계값 미달 시간도 업데이트
        if (_isBelowThreshold) {
          _belowThresholdSeconds += 1;
          _belowThresholdDuration = Duration(seconds: _belowThresholdSeconds);
        }
        
        notifyListeners(); // UI에 시간 업데이트 알림
      });

      // 7단계: 오디오 레벨 모니터링 시작 (항상 실행하여 실시간 레벨 표시)
      try {
        await _startLevelMonitoring();
        print('🎵 오디오 레벨 모니터링 시작됨');
      } catch (e) {
        print('⚠️ 오디오 레벨 모니터링 시작 실패: $e');
        // 모니터링 실패해도 녹음은 계속 진행
      }
      
      notifyListeners(); // UI에 녹음 시작 상태 알림
      print('✅ 녹음 시작 완료!');
      
    } catch (e) {
      // 오류 발생 시 정리 작업 및 상태 초기화
      print('❌❌❌ 녹음 시작 오류: $e');
      print('❌❌❌ 오류 타입: ${e.runtimeType}');
      
      _isRecording = false;
      _timer?.cancel();
      notifyListeners();
      throw e; // 오류를 다시 던져서 UI에서 처리할 수 있도록 함
    }
  }

  // === 음성 녹음 중지 및 파일 저장 메서드 ===
  // 사용자가 녹음 중지 버튼을 눌렀을 때 호출되는 메서드
  Future<void> stopRecording() async {
    try {
      print('🛑 녹음 중지 시작...');
      
      // 1단계: 녹음 중지 및 파일 경로 받기
      final recordedPath = await _recorder.stop();
      print('📁 녹음된 파일 경로: $recordedPath');
      
      // 2단계: 오디오 레벨 모니터링 중지
      if (_levelMonitor.isMonitoring) {
        try {
          await _levelMonitor.stopMonitoring();
          print('🎵 오디오 레벨 모니터링 중지됨');
        } catch (e) {
          print('⚠️ 오디오 레벨 모니터링 중지 실패: $e');
        }
      }

      // 3단계: 타이머 정리 및 상태 초기화
      _timer?.cancel();
      _timer = null;
      _isRecording = false;
      _isBelowThreshold = false;
      
      // 3단계: 녹음된 파일 처리 (플랫폼별 다른 처리)
      if (recordedPath != null && _recordingPath != null) {
        if (kIsWeb) {
          // 웹 환경: 자동으로 브라우저 다운로드 폴더에 파일 다운로드
          print('💾 웹 환경: 파일 다운로드 시작');
          await downloadFile(recordedPath, _recordingPath!);
          print('✅ 웹 파일 다운로드 완료');
        } else {
          // 모바일/데스크톱 환경: 앱 내부 파일 목록에 추가
          print('📱 모바일 환경: 파일 목록에 추가');
          
          // 새로운 녹음 아이템 생성
          final newRecording = RecordingItem(
            path: recordedPath,                           // 실제 저장된 파일 경로
            name: _recordingPath!.split('/').last,        // 파일명만 추출
            timestamp: DateTime.now(),                    // 현재 시간을 생성 시간으로 설정
            size: await File(recordedPath).length(),      // 파일 크기 계산
          );
          
          // 목록의 맨 앞에 추가 (최신 파일이 위에 오도록)
          _recordings.insert(0, newRecording);
          print('✅ 파일 목록 추가 완료: ${newRecording.name}');
        }
        
        print('✅ 녹음 완료: $recordedPath');
      }
      
      notifyListeners(); // UI에 녹음 완료 상태 알림
    } catch (e) {
      // 오류 발생 시 안전한 상태로 복구
      print('❌❌❌ 녹음 중지 오류: $e');
      _isRecording = false;
      _timer?.cancel();
      notifyListeners();
      throw e;
    }
  }

  // === 녹음된 파일 재생/중지 토글 메서드 ===
  // 파일 목록에서 특정 파일을 재생하거나 중지할 때 사용
  Future<void> togglePlayback(String filePath) async {
    try {
      if (_isPlaying) {
        // 현재 재생 중이라면 중지
        await _player.stop();
        _isPlaying = false;
      } else {
        // 재생 중이 아니라면 파일 재생 시작
        await _player.play(DeviceFileSource(filePath)); // 로컬 파일 재생
        _isPlaying = true;
        
        // 재생 완료 이벤트 리스너 등록
        // 파일 재생이 끝나면 자동으로 재생 상태를 false로 변경
        _player.onPlayerComplete.listen((_) {
          _isPlaying = false;
          notifyListeners(); // UI 업데이트
        });
      }
      notifyListeners(); // 재생 상태 변경을 UI에 알림
    } catch (e) {
      print('재생 오류: $e');
    }
  }

  // === 녹음 파일 삭제 메서드 ===
  // 사용자가 파일 목록에서 특정 파일을 삭제할 때 호출
  Future<void> deleteRecording(RecordingItem item) async {
    try {
      if (!kIsWeb) {
        // 모바일/데스크톱 환경에서만 실제 파일 삭제 수행
        // (웹에서는 이미 다운로드된 파일이므로 삭제할 수 없음)
        final file = File(item.path);
        if (await file.exists()) {
          await file.delete(); // 물리적 파일 삭제
        }
      }
      
      // 앱 내부 목록에서 제거
      _recordings.remove(item);
      notifyListeners(); // UI 업데이트
      print('🗑️ 파일 삭제: ${item.name}');
    } catch (e) {
      print('파일 삭제 오류: $e');
    }
  }

  // === 데시벨 임계값 관련 정보 메서드들 ===
  // 하드코딩된 임계값을 사용하므로 설정 변경 메서드들은 제거됨
  
  /// 임계값 미달 비율을 계산합니다 (0.0 ~ 1.0)
  /// 녹음 시간 대비 임계값 미달 시간의 비율
  double get belowThresholdRatio {
    if (_recordingDuration.inSeconds == 0) return 0.0;
    return _belowThresholdSeconds / _recordingDuration.inSeconds;
  }
  
  /// 임계값 미달 비율을 퍼센트로 반환합니다 (0 ~ 100)
  int get belowThresholdPercentage {
    return (belowThresholdRatio * 100).round();
  }



  /// 레벨 모니터링을 시작하는 내부 메서드
  Future<void> _startLevelMonitoring() async {
    try {
      await _levelMonitor.startMonitoring(
        thresholdDecibel: _thresholdSettings.threshold,
        onLevelUpdate: (double level) {
          _thresholdSettings.updateCurrentLevel(level);
        },
        onThresholdChange: (bool isAboveThreshold) {
          // 하드코딩된 임계값은 항상 활성화되어 있음
          _isBelowThreshold = !isAboveThreshold;
          
          if (isAboveThreshold && !_isActuallyRecording) {
            // 임계값 초과 && 현재 실제 녹음 중이 아님 -> 실제 녹음 시작!
            _isActuallyRecording = true;
            _waitingForVoice = false;
            print('🎤✅ 음성 감지! 실제 녹음 시작 (${_thresholdSettings.threshold.toStringAsFixed(1)}dB 초과)');
          } else if (!isAboveThreshold && _isActuallyRecording) {
            // 임계값 미달 && 현재 실제 녹음 중 -> 실제 녹음 일시정지
            _isActuallyRecording = false;
            _waitingForVoice = true;
            print('🔇⏸️ 음성 없음! 실제 녹음 일시정지 (${_thresholdSettings.threshold.toStringAsFixed(1)}dB 미달)');
          }
          
          notifyListeners();
        },
      );
    } catch (e) {
      print('⚠️ 레벨 모니터링 시작 실패: $e');
      throw e;
    }
  }

  // === 리소스 정리 메서드 ===
  // Provider가 메모리에서 해제될 때 자동으로 호출되어 리소스를 정리
  @override
  void dispose() {
    _timer?.cancel();                 // 실행 중인 타이머 정리
    _levelMonitor.dispose();          // 오디오 레벨 모니터 리소스 해제
    _thresholdSettings.dispose();     // 임계값 설정 객체 리소스 해제
    _recorder.dispose();              // 녹음 객체 리소스 해제
    _player.dispose();                // 재생 객체 리소스 해제
    super.dispose();                  // 부모 클래스의 dispose 호출
  }
} 