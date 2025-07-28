import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
<<<<<<< HEAD
import 'api_config_service.dart';
=======
>>>>>>> origin/Feature_CM2

class GoogleAuthService {
  // Clerk를 통한 OAuth 처리 - 다른 URL 패턴 시도
  static const String clerkOAuthUrl =
      'https://probable-lion-70.clerk.accounts.dev/oauth/google';

  /// Clerk를 통한 Google 로그인 (웹용)
  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // Clerk OAuth URL로 직접 이동
      print('Clerk OAuth 페이지로 이동: $clerkOAuthUrl');

      // 웹에서는 새 창으로 열거나 리다이렉트
      return {
        'provider': 'google',
        'method': 'clerk_oauth',
        'url': clerkOAuthUrl,
      };
    } catch (error) {
      print('Clerk OAuth 오류: $error');
      return null;
    }
  }

  /// 직접 Google Sign-In (모바일용)
  static Future<Map<String, dynamic>?> signInWithGoogleDirect() async {
    try {
      // 웹에서는 Google Identity Services 사용
      if (kIsWeb) {
        print('웹에서는 Google Identity Services를 사용합니다.');
        return await _signInWithGoogleWeb();
      }

      // 모바일에서는 기존 Google Sign-In 사용
      final GoogleSignIn _googleSignIn = GoogleSignIn(
        clientId: dotenv.env['GOOGLE_CLIENT_ID'] ?? 'default_google_client_id',
        scopes: ['email', 'profile'],
      );

      // Google Sign-In 실행
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('Google 로그인이 취소되었습니다.');
        return null;
      }

      // Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // ID 토큰 확인
      if (googleAuth.idToken == null) {
        print('ID 토큰을 가져올 수 없습니다.');
        return null;
      }

      // 사용자 정보 구성
      final userInfo = {
        'id': googleUser.id,
        'email': googleUser.email,
        'name': googleUser.displayName,
        'picture': googleUser.photoUrl,
        'provider': 'google',
        'access_token': googleAuth.accessToken,
        'id_token': googleAuth.idToken,
      };

      print('Google 로그인 성공: ${userInfo['email']}');
      return userInfo;
    } catch (error) {
      print('Google 로그인 오류: $error');
      return null;
    }
  }

  /// 웹용 Google Identity Services 로그인
  static Future<Map<String, dynamic>?> _signInWithGoogleWeb() async {
    try {
      // 웹에서는 직접 Google Sign-In 사용 (deprecated 경고 무시)
      final GoogleSignIn _googleSignIn = GoogleSignIn(
        clientId: dotenv.env['GOOGLE_CLIENT_ID'] ?? 'default_google_client_id',
        scopes: ['email', 'profile'],
      );

      // 웹에서도 signIn 사용 (deprecated지만 작동함)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('웹에서 Google 로그인이 취소되었습니다.');
        return null;
      }

      // Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // ID 토큰 확인 - 웹에서는 null일 수 있음
      if (googleAuth.idToken == null) {
        print('웹에서 ID 토큰을 가져올 수 없습니다. Access Token만 사용합니다.');

        // Access Token만으로 사용자 정보 구성
        final userInfo = {
          'id': googleUser.id,
          'email': googleUser.email,
          'name': googleUser.displayName,
          'picture': googleUser.photoUrl,
          'provider': 'google',
          'access_token': googleAuth.accessToken,
          'id_token': null, // 웹에서는 null일 수 있음
        };

        print('웹 Google 로그인 성공 (Access Token만): ${userInfo['email']}');
        return userInfo;
      }

      // ID 토큰이 있는 경우
      final userInfo = {
        'id': googleUser.id,
        'email': googleUser.email,
        'name': googleUser.displayName,
        'picture': googleUser.photoUrl,
        'provider': 'google',
        'access_token': googleAuth.accessToken,
        'id_token': googleAuth.idToken,
      };

      print('웹 Google 로그인 성공: ${userInfo['email']}');
      return userInfo;
    } catch (error) {
      print('웹 Google 로그인 오류: $error');
      return null;
    }
  }

  /// Google 로그아웃
  static Future<void> signOut() async {
    try {
      final GoogleSignIn _googleSignIn = GoogleSignIn(
        clientId: dotenv.env['GOOGLE_CLIENT_ID'] ?? 'default_google_client_id',
      );
      await _googleSignIn.signOut();
      print('Google 로그아웃 완료');
    } catch (error) {
      print('Google 로그아웃 오류: $error');
    }
  }

  /// 현재 로그인된 Google 사용자 확인
  static Future<GoogleSignInAccount?> getCurrentUser() async {
    final GoogleSignIn _googleSignIn = GoogleSignIn(
      clientId: dotenv.env['GOOGLE_CLIENT_ID'] ?? 'default_google_client_id',
    );
    return await _googleSignIn.signInSilently();
  }

  /// Access Token으로 Google 사용자 정보 가져오기 (People API 사용)
  static Future<Map<String, dynamic>?> getUserInfoWithAccessToken(
    String accessToken,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://people.googleapis.com/v1/people/me?sources=READ_SOURCE_TYPE_PROFILE&personFields=photos,names,emailAddresses',
        ),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final userInfo = jsonDecode(response.body);

        // People API 응답에서 사용자 정보 추출
        final names = userInfo['names'] as List?;
        final emailAddresses = userInfo['emailAddresses'] as List?;
        final photos = userInfo['photos'] as List?;

        final name = names?.isNotEmpty == true ? names![0]['displayName'] : '';
        final email = emailAddresses?.isNotEmpty == true
            ? emailAddresses![0]['value']
            : '';
        final photoUrl = photos?.isNotEmpty == true ? photos![0]['url'] : '';
        final resourceName = userInfo['resourceName'] ?? '';

        return {
          'id': resourceName.replaceAll('people/', ''),
          'email': email,
          'name': name,
          'picture': photoUrl,
          'provider': 'google',
          'access_token': accessToken,
        };
      } else {
        print('Google People API 요청 실패: ${response.statusCode}');
        print('응답: ${response.body}');
        return null;
      }
    } catch (error) {
      print('Google People API 요청 오류: $error');
      return null;
    }
  }

  /// Clerk JWT 토큰 요청 (Access Token 사용)
  static Future<String?> getClerkJWTWithAccessToken(String accessToken) async {
    try {
      final response = await http.post(
<<<<<<< HEAD
        Uri.parse('${ApiConfigService.baseUrl}/auth/google/callback'),
=======
        Uri.parse('http://10.0.2.2:8000/auth/google/callback'),
>>>>>>> origin/Feature_CM2
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': accessToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['jwt_token'];
      } else {
        print('Clerk JWT 토큰 요청 실패: ${response.statusCode}');
        print('응답: ${response.body}');
        return null;
      }
    } catch (error) {
      print('Clerk JWT 토큰 요청 오류: $error');
      return null;
    }
  }

  /// 백엔드 API에 Google Access Token을 전송하여 사용자 정보 및 JWT를 받아옵니다.
  static Future<Map<String, dynamic>?> callBackendAuthAPI(
    String accessToken,
  ) async {
    try {
<<<<<<< HEAD
      final String backendUrl = ApiConfigService.baseUrl; // 백엔드 URL
=======
      const String backendUrl = 'http://10.0.2.2:8000'; // 백엔드 URL
>>>>>>> origin/Feature_CM2

      final response = await http.post(
        Uri.parse('$backendUrl/auth/google/callback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': accessToken}),
      );

      print('백엔드 API 응답 상태: ${response.statusCode}');
      print('백엔드 API 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }

      print('백엔드 API 호출 실패');
      return null;
    } catch (e) {
      print('백엔드 API 호출 중 오류: $e');
      return null;
    }
  }
}
