import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/song.dart';

class AiVocalPlayPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Song song = ModalRoute.of(context)!.settings.arguments as Song;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('AI Vocal 합성', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 배경 SVG 요소들
          Positioned(
            top: 100,
            right: -40,
            child: SvgPicture.asset(
              'assets/images/rectangle4.svg',
              width: 150,
              height: 150,
              color: Colors.deepPurple.withOpacity(0.05),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -30,
            child: SvgPicture.asset(
              'assets/images/rectangle7.svg',
              width: 100,
              height: 100,
              color: Colors.purple.withOpacity(0.03),
            ),
          ),
          // 메인 콘텐츠
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // 앨범커버 섹션
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 배경 원형 효과
                      Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(120),
                        ),
                      ),
                      // 앨범커버 이미지
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: Image.asset(
                          song.albumCover.isNotEmpty
                              ? song.albumCover
                              : 'assets/images/iu.webp',
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // 재생 중 표시
                      Positioned(
                        bottom: 20,
                        right: 20,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.3),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                // 곡 정보
                Text(
                  song.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${song.artist} - AI 보컬 Ver.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                // 난이도와 음역대
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        song.difficulty,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        song.range,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32),
                // 재생바
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '1:46',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: 106,
                              min: 0,
                              max: 220,
                              onChanged: (v) {},
                              activeColor: Colors.deepPurple,
                              inactiveColor: Colors.grey[300],
                              thumbColor: Colors.deepPurple,
                            ),
                          ),
                          Text(
                            song.duration,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                // 플레이어 컨트롤
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(Icons.skip_previous, size: 32),
                      onPressed: () {},
                      color: Colors.grey[600],
                    ),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            blurRadius: 15,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.pause, size: 36),
                        onPressed: () {},
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.skip_next, size: 32),
                      onPressed: () {},
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                SizedBox(height: 24),
                // 추가 액션 버튼들
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(Icons.favorite_border, size: 28),
                      onPressed: () {},
                      color: Colors.grey[600],
                    ),
                    IconButton(
                      icon: Icon(Icons.share, size: 28),
                      onPressed: () {},
                      color: Colors.grey[600],
                    ),
                    IconButton(
                      icon: Icon(Icons.download, size: 28),
                      onPressed: () {},
                      color: Colors.grey[600],
                    ),
                    IconButton(
                      icon: Icon(Icons.more_vert, size: 28),
                      onPressed: () {},
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                Spacer(),
                // 하단 장식
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/images/icon.svg',
                      width: 16,
                      height: 16,
                      color: Colors.deepPurple.withOpacity(0.6),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AI 보컬 합성 완료',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
