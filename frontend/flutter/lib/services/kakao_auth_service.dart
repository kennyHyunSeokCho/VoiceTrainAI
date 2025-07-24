import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class KakaoAuthService {
  static const String _baseUrl = 'http://localhost:8000';

  // 환경변수에서 앱 키 가져오기
  static String get _nativeAppKey =>
      dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? 'default_kakao_native_key';
  static String get _javaScriptAppKey =>
      dotenv.env['KAKAO_JAVASCRIPT_APP_KEY'] ?? 'default_kakao_js_key';

  /// 카카오 로그인 초기화
  static Future<void> initialize() async {
    // 앱 키 디버그 출력
    print('카카오 앱 키 확인:');
    print('Native App Key: $_nativeAppKey');
    print('JavaScript App Key: $_javaScriptAppKey');

    if (kIsWeb) {
      // 웹에서는 JavaScript SDK 사용
      KakaoSdk.init(
        nativeAppKey: _nativeAppKey,
        javaScriptAppKey: _javaScriptAppKey,
      );
    } else {
      // 모바일에서는 네이티브 SDK 사용
      KakaoSdk.init(nativeAppKey: _nativeAppKey);
    }
  }

  /// 카카오 로그인 실행 (Access Token만 반환)
  static Future<Map<String, dynamic>?> signInWithKakao() async {
    try {
      print('카카오 로그인 시작...');

      // 카카오 로그인 시도
      OAuthToken token = await UserApi.instance.loginWithKakaoAccount();

      print(
        '카카오 로그인 성공! Access Token: ${token.accessToken?.substring(0, 20)}...',
      );

      // Access Token과 Refresh Token 반환
      return {
        'access_token': token.accessToken,
        'refresh_token': token.refreshToken,
      };
    } catch (error) {
      print('카카오 로그인 실패: $error');
      rethrow;
    }
  }

  /// 카카오 로그아웃
  static Future<void> signOut() async {
    try {
      await UserApi.instance.logout();
      print('카카오 로그아웃 완료');
    } catch (error) {
      print('카카오 로그아웃 실패: $error');
      rethrow;
    }
  }

  /// 현재 카카오 사용자 정보 가져오기
  static Future<User?> getCurrentUser() async {
    try {
      return await UserApi.instance.me();
    } catch (error) {
      print('카카오 사용자 정보 가져오기 실패: $error');
      return null;
    }
  }

  /// 백엔드로 카카오 토큰 전송
  static Future<Map<String, dynamic>?> _sendTokenToBackend(
    String accessToken,
  ) async {
    try {
      print('백엔드로 카카오 토큰 전송 중...');

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/kakao/callback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': accessToken}),
      );

      print('백엔드 응답 상태 코드: ${response.statusCode}');
      print('백엔드 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('카카오 로그인 성공: ${data['user']['name']}');
        return data;
      } else {
        print('백엔드 요청 실패: ${response.statusCode} - ${response.body}');
        throw Exception('백엔드 요청 실패: ${response.statusCode}');
      }
    } catch (error) {
      print('백엔드 토큰 전송 실패: $error');
      rethrow;
    }
  }

  /// 카카오 계정 연결 상태 확인
  static Future<bool> isKakaoTalkInstalled() async {
    try {
      // 웹에서는 카카오톡 앱 설치 여부를 확인할 수 없으므로 항상 false
      if (kIsWeb) {
        return false;
      }
      // 모바일에서는 카카오톡 설치 여부를 확인
      // 실제 구현에서는 카카오 SDK의 적절한 메서드를 사용해야 함
      return false; // 임시로 false 반환
    } catch (error) {
      print('카카오톡 설치 확인 실패: $error');
      return false;
    }
  }

  /// 카카오톡으로 로그인 (카카오톡 앱이 설치된 경우)
  static Future<Map<String, dynamic>?> signInWithKakaoTalk() async {
    try {
      print('카카오톡으로 로그인 시도...');

      OAuthToken token = await UserApi.instance.loginWithKakaoTalk();

      print('카카오톡 로그인 성공!');

      // 백엔드로 토큰 전송
      return await _sendTokenToBackend(token.accessToken!);
    } catch (error) {
      print('카카오톡 로그인 실패: $error');
      rethrow;
    }
  }

  /// 카카오 계정으로 로그인 (카카오톡 앱이 설치되지 않은 경우)
  static Future<Map<String, dynamic>?> signInWithKakaoAccount() async {
    try {
      print('카카오 계정으로 로그인 시도...');

      OAuthToken token = await UserApi.instance.loginWithKakaoAccount();

      print('카카오 계정 로그인 성공!');

      // 백엔드로 토큰 전송
      return await _sendTokenToBackend(token.accessToken!);
    } catch (error) {
      print('카카오 계정 로그인 실패: $error');
      rethrow;
    }
  }

  /// 백엔드 API에 카카오 Access Token을 전송하여 사용자 정보 및 JWT를 받아옵니다.
  static Future<Map<String, dynamic>?> callBackendAuthAPI(
    String accessToken,
  ) async {
    try {
      const String backendUrl = 'http://localhost:8000';

      final response = await http.post(
        Uri.parse('$backendUrl/auth/kakao/callback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': accessToken}),
      );

      print('카카오 백엔드 API 응답 상태: ${response.statusCode}');
      print('카카오 백엔드 API 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }

      print('카카오 백엔드 API 호출 실패');
      return null;
    } catch (e) {
      print('카카오 백엔드 API 호출 중 오류: $e');
      return null;
    }
  }
}
