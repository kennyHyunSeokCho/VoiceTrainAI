import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/song.dart';

class AiVocalReadyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Song song = ModalRoute.of(context)!.settings.arguments as Song;

    return Scaffold(
      body: Stack(
        children: [
          // 배경 SVG 요소들
          Positioned(
            top: 80,
            left: -30,
            child: SvgPicture.asset(
              'assets/images/path4.svg',
              width: 100,
              height: 100,
              color: Colors.green.withOpacity(0.1),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -20,
            child: SvgPicture.asset(
              'assets/images/path5copy.svg',
              width: 80,
              height: 80,
              color: Colors.green.withOpacity(0.08),
            ),
          ),
          // 메인 콘텐츠
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 앨범커버 + 완료 효과
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 배경 원형 효과
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
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
                      // 완료 체크마크
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                // 제목과 부제목
                Text(
                  'AI Vocal 합성 완료!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
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
                // 완료된 진행바
                Container(
                  width: 280,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green, Colors.greenAccent],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '100% 완료',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 40),
                // 하단 장식 요소
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/images/path2copy2.svg',
                      width: 20,
                      height: 20,
                      color: Colors.green.withOpacity(0.6),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AI 보컬이 성공적으로 생성되었습니다',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    SizedBox(width: 8),
                    SvgPicture.asset(
                      'assets/images/path2.svg',
                      width: 20,
                      height: 20,
                      color: Colors.green.withOpacity(0.6),
                    ),
                  ],
                ),
                SizedBox(height: 40),
                // "들어보기" 버튼
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/ai-vocal-play',
                      arguments: song,
                    );
                  },
                  icon: Icon(Icons.play_arrow, size: 24),
                  label: Text(
                    '들어보기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
