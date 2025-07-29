import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiConfigService {
  static const String _emulatorUrl = 'http://10.0.2.2:8000';
  static const String _fallbackDeviceUrl =
      'http://192.168.0.31:8000'; // fallback IP
  static const String _productionUrl = 'https://your-production-server.com';

  static String? _cachedDeviceUrl;
  static DateTime? _lastIpCheck;
  static const Duration _ipCacheDuration = Duration(minutes: 5); // 5분간 캐시

  /// 현재 환경에 맞는 API 기본 URL을 반환합니다.
  static Future<String> get baseUrl async {
    if (kDebugMode) {
      if (Platform.isAndroid || Platform.isIOS) {
        // 실제 기기에서 실행 중 - 자동 IP 감지
        return await _getDeviceUrl();
      } else {
        // 에뮬레이터에서 실행 중
        print('🖥️ 에뮬레이터에서 실행 중 - $_emulatorUrl 사용');
        return _emulatorUrl;
      }
    } else {
      // 릴리즈 모드에서는 프로덕션 URL 사용
      print('🚀 릴리즈 모드 - $_productionUrl 사용');
      return _productionUrl;
    }
  }

  /// 실제 기기용 URL을 자동으로 감지하여 반환합니다.
  static Future<String> _getDeviceUrl() async {
    // 캐시된 URL이 있고 유효한 경우 사용
    if (_cachedDeviceUrl != null && _lastIpCheck != null) {
      if (DateTime.now().difference(_lastIpCheck!) < _ipCacheDuration) {
        print('📱 캐시된 IP 사용: $_cachedDeviceUrl');
        return _cachedDeviceUrl!;
      }
    }

    try {
      // 백엔드에서 IP 정보 가져오기 시도
      final ipInfo = await _fetchIpInfo();
      if (ipInfo != null) {
        final deviceUrl = 'http://${ipInfo['local_ip']}:8000';
        _cachedDeviceUrl = deviceUrl;
        _lastIpCheck = DateTime.now();
        print('📱 자동 감지된 IP 사용: $deviceUrl');
        return deviceUrl;
      }
    } catch (e) {
      print('⚠️ IP 자동 감지 실패: $e');
    }

    // 자동 감지 실패 시 fallback IP 사용
    print('📱 Fallback IP 사용: $_fallbackDeviceUrl');
    return _fallbackDeviceUrl;
  }

  /// 백엔드에서 IP 정보를 가져옵니다.
  static Future<Map<String, dynamic>?> _fetchIpInfo() async {
    try {
      // 먼저 fallback IP로 IP 정보 요청
      final response = await http
          .get(
            Uri.parse('$_fallbackDeviceUrl/api/ip-info'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🌐 IP 정보 가져오기 성공: ${data['local_ip']}');
        return data;
      }
    } catch (e) {
      print('❌ IP 정보 가져오기 실패: $e');
    }
    return null;
  }

  /// 에뮬레이터용 URL을 반환합니다.
  static String get emulatorUrl => _emulatorUrl;

  /// 실제 기기용 URL을 반환합니다 (동기 버전).
  static String get deviceUrl => _cachedDeviceUrl ?? _fallbackDeviceUrl;

  /// 프로덕션용 URL을 반환합니다.
  static String get productionUrl => _productionUrl;

  /// 캐시된 IP를 초기화합니다.
  static void clearIpCache() {
    _cachedDeviceUrl = null;
    _lastIpCheck = null;
    print('🔄 IP 캐시 초기화됨');
  }

  /// 현재 환경 정보를 로그로 출력합니다.
  static Future<void> logCurrentEnvironment() async {
    final currentUrl = await baseUrl;
    print('🌐 API 환경 설정:');
    print('   - 현재 URL: $currentUrl');
    print('   - 플랫폼: ${Platform.operatingSystem}');
    print('   - 디버그 모드: $kDebugMode');
    print('   - 캐시된 IP: $_cachedDeviceUrl');
  }
}
