import 'package:flutter/material.dart';
import '/main_layout.dart';
import 'register.dart';
import '../services/google_auth_service.dart';
import '../services/kakao_auth_service.dart';
import '../main.dart'; // CurrentUser 클래스 사용을 위해
// import 'dart:html' as html; // 웹 전용 라이브러리이므로 모바일에서는 주석 처리

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isGoogleLoading = false;
  bool _isKakaoLoading = false;

  @override
  void initState() {
    super.initState();
    // 카카오 SDK 초기화
    KakaoAuthService.initialize();
  }

  void _login(BuildContext context) {
    // 로그인 검증 생략
    // 임시 테스트용 사용자 정보 설정
    CurrentUser.setUser('test_user_123', '테스트사용자', 'test@example.com', 'email');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainLayout()),
    );
  }

  /// Google 로그인 처리
  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      // 직접 Google 로그인 시도 (웹에서도 시도)
      final directUserInfo = await GoogleAuthService.signInWithGoogleDirect();

      if (directUserInfo != null) {
        // Access Token으로 백엔드 API 호출
        final accessToken = directUserInfo['access_token'];
        final backendResponse = await GoogleAuthService.callBackendAuthAPI(
          accessToken,
        );

        if (backendResponse != null && backendResponse['success'] == true) {
          // 백엔드에서 받은 사용자 정보로 CurrentUser 설정
          final userData = backendResponse['user'];
          CurrentUser.setUser(
            userData['id'].toString(),
            userData['name'] ?? userData['email'],
            userData['email'] ?? '',
            userData['provider'] ?? 'google',
          );

          // 로그인 성공 - 메인 화면으로 이동
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Google 로그인 성공: ${userData['email']}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );

            // 잠시 후 메인 화면으로 이동
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MainLayout()),
                );
              }
            });
          }
        } else {
          // 백엔드 API 호출 실패
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('서버 인증에 실패했습니다. 다시 시도해주세요.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
      // directUserInfo가 null인 경우는 사용자가 취소한 것이므로 오류 메시지 표시하지 않음
    } catch (e) {
      print('Google 로그인 실패: $e');
      // 사용자가 취소한 경우가 아닌 실제 오류인 경우에만 메시지 표시
      if (mounted && e.toString().contains('cancelled') == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google 로그인에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  /// Kakao 로그인 처리
  Future<void> _handleKakaoLogin() async {
    setState(() {
      _isKakaoLoading = true;
    });

    try {
      final tokenInfo = await KakaoAuthService.signInWithKakao();
      if (tokenInfo != null) {
        // 카카오 사용자 정보 가져오기
        final user = await KakaoAuthService.getCurrentUser();
        if (user != null) {
          // 로그인 성공 처리
          CurrentUser.setUser(
            user.id.toString(),
            user.kakaoAccount?.profile?.nickname ?? 'Kakao User',
            user.kakaoAccount?.email ?? '',
            'kakao',
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '카카오 로그인 성공: ${user.kakaoAccount?.email ?? 'Kakao User'}',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );

            // 잠시 후 메인 화면으로 이동
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MainLayout()),
                );
              }
            });
          }
        }
      }
      // tokenInfo가 null인 경우는 사용자가 취소한 것이므로 오류 메시지 표시하지 않음
    } catch (e) {
      print('Kakao 로그인 실패: $e');
      // 사용자가 취소한 경우가 아닌 실제 오류인 경우에만 메시지 표시
      if (mounted && e.toString().contains('cancelled') == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('카카오 로그인에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isKakaoLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  16,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // AVTS 로고
                Center(
                  child: Text(
                    'AVTS',
                    style: TextStyle(
                      fontSize: 45,
                      fontWeight: FontWeight.w300,
                      color: Color(0xff8917E3),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // 소셜 로그인 버튼들
                Column(
                  children: [
                    // 카카오 로그인 버튼
                    Container(
                      width: double.infinity,
                      height: 44,
                      margin: EdgeInsets.only(bottom: 10),
                      child: ElevatedButton.icon(
                        onPressed: _isKakaoLoading ? null : _handleKakaoLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFFEE500),
                          foregroundColor: Colors.black87,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isKakaoLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black87,
                                  ),
                                ),
                              )
                            : Icon(Icons.chat_bubble_outline, size: 18),
                        label: _isKakaoLoading
                            ? Text('처리 중...')
                            : Text(
                                '카카오로 로그인',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    // Google 로그인 버튼
                    Container(
                      width: double.infinity,
                      height: 44,
                      margin: EdgeInsets.only(bottom: 20),
                      child: ElevatedButton.icon(
                        onPressed: _isGoogleLoading ? null : _handleGoogleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 2,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isGoogleLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black87,
                                  ),
                                ),
                              )
                            : Icon(Icons.mail_outline, size: 18),
                        label: _isGoogleLoading
                            ? Text('처리 중...')
                            : Text(
                                'Google로 로그인',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),

                // 구분선
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '또는',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),

                const SizedBox(height: 20),

                // 이메일 로그인 폼
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이메일 입력
                    Text(
                      '이메일 주소',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      decoration: InputDecoration(
                        hintText: '이메일을 입력하세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Color(0xff8917E3),
                            width: 2,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 비밀번호 입력
                    Text(
                      '비밀번호',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: '비밀번호를 입력하세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Color(0xff8917E3),
                            width: 2,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 로그인 버튼
                    Container(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          _login(context);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MainLayout(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xff8917E3),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 회원가입 페이지로 이동 링크
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '계정이 없으신가요?',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterPage(),
                                ),
                              );
                            },
                            child: Text(
                              '회원가입',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff8917E3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
