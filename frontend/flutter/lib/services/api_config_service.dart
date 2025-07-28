import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfigService {
  static const String _emulatorUrl = 'http://10.0.2.2:8000';
  static const String _deviceUrl =
      'http://192.168.0.36:8000'; // 실제 서버 IP (Wi-Fi IP)
  static const String _productionUrl = 'https://your-production-server.com';

  /// 현재 환경에 맞는 API 기본 URL을 반환합니다.
  static String get baseUrl {
    if (kDebugMode) {
      // 디버그 모드에서는 에뮬레이터인지 실제 기기인지 확인
      if (Platform.isAndroid || Platform.isIOS) {
        // 실제 기기에서 실행 중
        print('📱 실제 기기에서 실행 중 - $deviceUrl 사용');
        return _deviceUrl;
      } else {
        // 에뮬레이터에서 실행 중
        print('🖥️ 에뮬레이터에서 실행 중 - $emulatorUrl 사용');
        return _emulatorUrl;
      }
    } else {
      // 릴리즈 모드에서는 프로덕션 URL 사용
      print('🚀 릴리즈 모드 - $productionUrl 사용');
      return _productionUrl;
    }
  }

  /// 에뮬레이터용 URL을 반환합니다.
  static String get emulatorUrl => _emulatorUrl;

  /// 실제 기기용 URL을 반환합니다.
  static String get deviceUrl => _deviceUrl;

  /// 프로덕션용 URL을 반환합니다.
  static String get productionUrl => _productionUrl;

  /// 현재 환경 정보를 로그로 출력합니다.
  static void logCurrentEnvironment() {
    print('🌐 API 환경 설정:');
    print('   - 현재 URL: $baseUrl');
    print('   - 플랫폼: ${Platform.operatingSystem}');
    print('   - 디버그 모드: $kDebugMode');
  }
}
