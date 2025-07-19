import 'package:flutter/material.dart';
import '/main_layout.dart';
import 'register.dart';
import '../services/google_auth_service.dart';
import '../services/kakao_auth_service.dart';
import 'dart:html' as html;

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
        // Access Token으로 사용자 정보 가져오기
        final accessToken = directUserInfo['access_token'];
        final userInfo = await GoogleAuthService.getUserInfoWithAccessToken(
          accessToken,
        );

        if (userInfo != null) {
          // Clerk JWT 토큰 요청 (Access Token 사용)
          final jwtToken = await GoogleAuthService.getClerkJWTWithAccessToken(
            accessToken,
          );

          if (jwtToken != null) {
            // 로그인 성공 - 메인 화면으로 이동
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Google 로그인 성공: ${userInfo['email']}'),
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
            // JWT 토큰 요청 실패
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('서버 인증에 실패했습니다. 다시 시도해주세요.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          // 사용자 정보 가져오기 실패
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('사용자 정보를 가져올 수 없습니다.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Google 로그인 실패
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google 로그인에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (error) {
      print('Google 로그인 오류: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 중 오류가 발생했습니다: $error'),
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

  /// 카카오 로그인 처리
  Future<void> _handleKakaoLogin() async {
    setState(() {
      _isKakaoLoading = true;
    });

    try {
      print('카카오 로그인 시작...');

      // 카카오 로그인 시도
      final userInfo = await KakaoAuthService.signInWithKakao();

      if (userInfo != null) {
        // 로그인 성공 - 메인 화면으로 이동
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('카카오 로그인 성공: ${userInfo['user']['name']}'),
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
        // 카카오 로그인 실패
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('카카오 로그인에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (error) {
      print('카카오 로그인 오류: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('카카오 로그인 중 오류가 발생했습니다: $error'),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'AVTS',
                        style: TextStyle(
                          fontSize: 55, // 텍스트 크기 조정
                          fontWeight: FontWeight.w300, // 굵기
                          color: Color(0xff8917E3), // 색상
                        ),
                        textAlign: TextAlign.center, // 여러 줄일 경우도 가운데 정렬
                      ),
                    ),

                    const SizedBox(height: 30),
                    const Text(
                      'Email Address',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Enter your email',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    const SizedBox(height: 20),
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        _login(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MainLayout(),
                          ),
                        ); // Login 시 메인으로 이동
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 5,
                        backgroundColor: const Color.fromARGB(
                          255,
                          146,
                          119,
                          223,
                        ),
                        foregroundColor: Colors.white,
                        minimumSize: Size(
                          double.infinity,
                          48,
                        ), // width는 무시되고 height만 유지됨
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('Login'),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isKakaoLoading ? null : _handleKakaoLogin,
                      style: ElevatedButton.styleFrom(
                        elevation: 5,
                        minimumSize: Size(double.infinity, 48),
                        backgroundColor: const Color(0xFFFEE500), // 카카오 브랜드 색상
                        foregroundColor: const Color(0xFF191919), // 카카오 텍스트 색상
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        side: BorderSide.none,
                      ),
                      child: _isKakaoLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF191919),
                                ),
                              ),
                            )
                          : const Text(
                              '카카오로 로그인',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 13),
                    ElevatedButton(
                      onPressed: _isGoogleLoading ? null : _handleGoogleLogin,
                      style: ElevatedButton.styleFrom(
                        elevation: 5,
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _isGoogleLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login with Google'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('계정이 없으신가요?', style: TextStyle(fontSize: 10)),

                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterPage(),
                            ),
                          ); // Register시 페이지 이동
                        },
                        child: const Text('회원가입'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
