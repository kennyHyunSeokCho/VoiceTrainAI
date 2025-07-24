import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import '../models/song.dart';

class AiVocalLoadingPage extends StatefulWidget {
  @override
  _AiVocalLoadingPageState createState() => _AiVocalLoadingPageState();
}

class _AiVocalLoadingPageState extends State<AiVocalLoadingPage>
    with TickerProviderStateMixin {
  double _progress = 0.0;
  Timer? _timer;
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    // 로딩 진행률 시뮬레이션
    _startLoading();
  }

  void _startLoading() {
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (_progress < 1.0) {
        setState(() {
          // 진행률을 단계별로 증가 (실제 AI 처리 시간을 시뮬레이션)
          if (_progress < 0.3) {
            _progress += 0.01; // 초기 단계: 빠르게
          } else if (_progress < 0.7) {
            _progress += 0.005; // 중간 단계: 중간 속도
          } else if (_progress < 0.95) {
            _progress += 0.002; // 후반 단계: 느리게
          } else {
            _progress += 0.001; // 마무리 단계: 매우 느리게
          }
          
          if (_progress > 1.0) _progress = 1.0;
        });
        
        // 애니메이션 업데이트
        _progressAnimation = Tween<double>(
          begin: _progressAnimation.value,
          end: _progress,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ));
        _animationController.forward(from: 0.0);
      } else {
        timer.cancel();
        // 로딩 완료 시 자동으로 다음 페이지로 이동
        Future.delayed(Duration(seconds: 1), () {
          if (mounted) {
            final song = ModalRoute.of(context)!.settings.arguments as Song;
            Navigator.pushReplacementNamed(context, '/ai-vocal-ready', arguments: song);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  String _getLoadingText() {
    if (_progress < 0.2) {
      return 'AI 모델 초기화 중...';
    } else if (_progress < 0.4) {
      return '음성 데이터 분석 중...';
    } else if (_progress < 0.6) {
      return '보컬 특성 추출 중...';
    } else if (_progress < 0.8) {
      return 'AI 보컬 생성 중...';
    } else if (_progress < 0.95) {
      return '음질 최적화 중...';
    } else {
      return '완료!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Song song = ModalRoute.of(context)!.settings.arguments as Song;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 배경 SVG 요소들
          Positioned(
            top: 50,
            right: -20,
            child: SvgPicture.asset(
              'assets/images/vector.svg',
              width: 120,
              height: 120,
              color: Colors.deepPurple.withOpacity(0.1),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -30,
            child: SvgPicture.asset(
              'assets/images/path.svg',
              width: 100,
              height: 100,
              color: Colors.purple.withOpacity(0.08),
            ),
          ),
          // 메인 콘텐츠
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 앨범커버 + 배경 효과
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 배경 원형 효과
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      // 앨범커버 이미지
                      ClipRRect(
                        borderRadius: BorderRadius.circular(80),
                        child: Image.asset(
                          song.albumCover.isNotEmpty
                              ? song.albumCover
                              : 'assets/images/iu.webp',
                          width: 160,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // 로딩 애니메이션 효과
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(90),
                          border: Border.all(
                            color: Colors.deepPurple.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                // 제목과 부제목
                Text(
                  'AI Vocal 합성 중',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple[800],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '${song.title} - ${song.artist}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 32),
                // 동적 로딩 텍스트
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: Text(
                    _getLoadingText(),
                    key: ValueKey(_getLoadingText()),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.deepPurple[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: 24),
                // 진행바
                Container(
                  width: 280,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    children: [
                      // 진행률 표시
                      AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 280 * _progressAnimation.value,
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.deepPurple, Colors.purple],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // 진행률 퍼센트
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return Text(
                      '${(_progressAnimation.value * 100).toInt()}% 완료',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.deepPurple[600],
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
                SizedBox(height: 40),
                // 하단 장식 요소
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/images/path2.svg',
                      width: 20,
                      height: 20,
                      color: Colors.deepPurple.withOpacity(0.6),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AI가 당신의 목소리를 분석하고 있습니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    SizedBox(width: 8),
                    SvgPicture.asset(
                      'assets/images/path2copy.svg',
                      width: 20,
                      height: 20,
                      color: Colors.deepPurple.withOpacity(0.6),
                    ),
                  ],
                ),
                SizedBox(height: 40),
                // 테스트용: 합성 완료 페이지로 이동 버튼 (개발 중에만 사용)
                if (_progress < 1.0)
                  ElevatedButton(
                    onPressed: () {
                      _timer?.cancel();
                      final song = ModalRoute.of(context)!.settings.arguments as Song;
                      Navigator.pushReplacementNamed(context, '/ai-vocal-ready', arguments: song);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      minimumSize: Size(200, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 4,
                    ),
                    child: Text('테스트: 바로 완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
