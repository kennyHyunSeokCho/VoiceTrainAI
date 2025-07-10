import 'package:flutter/material.dart';
import '../widgets/song_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // 환영 메시지
          Text(
            '안녕하세요!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            '오늘도 멋진 목소리로 노래해보세요',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 24),

          // 메인 배너
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.purple[400]!, Colors.pink[400]!],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(60),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'AI 보컬 합성',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '당신만의 특별한 목소리로',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 보컬 트레이너 레벨
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '보컬 트레이너',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                '더보기',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                LevelCard(
                  title: 'Beginner',
                  subtitle: '기본 보컬 기술',
                  duration: '1개월',
                  lessons: '150강',
                  color: Colors.blue[50]!,
                  iconColor: Colors.blue[600]!,
                ),
                SizedBox(width: 12),
                LevelCard(
                  title: 'Intermediate',
                  subtitle: '다양한 장르 연습',
                  duration: '2개월',
                  lessons: '200강',
                  color: Colors.purple[50]!,
                  iconColor: Colors.purple[600]!,
                ),
                SizedBox(width: 12),
                LevelCard(
                  title: 'Advanced',
                  subtitle: '고급 테크닉',
                  duration: '3개월',
                  lessons: '250강',
                  color: Colors.pink[50]!,
                  iconColor: Colors.pink[600]!,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 오늘의 추천곡
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '오늘의 추천곡',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                '더보기',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220, // 넉넉하게! (새로운 곡과 동일)
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                SongCard(
                  imagePath: 'assets/images/iu.webp',
                  title: 'Never Ending Story',
                  artist: 'IU',
                ),
                SizedBox(width: 12),
                SongCard(
                  imagePath: 'assets/images/no_pain.webp',
                  title: 'Drowning',
                  artist: 'WOODZ',
                ),
                SizedBox(width: 12),
                SongCard(
                  imagePath: 'assets/images/famous.webp',
                  title: 'FAMOUS',
                  artist: 'Allday Project',
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 보컬 트래킹 진행률
          Text(
            '보컬 트래킹 진행률',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.purple[100],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        color: Colors.purple[600],
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '이번 주 진행률',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '5일 연속 연습 중!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '85%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple[600],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                LinearProgressIndicator(
                  value: 0.85,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.purple[600]!,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 새로운 곡 업데이트
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '새로운 곡',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                '더보기',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220, // 넉넉하게!
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                SongCard(
                  imagePath: 'assets/images/no_pain.webp',
                  title: 'NO PAIN',
                  artist: '실리카겔',
                ),
                SizedBox(width: 12),
                SongCard(
                  imagePath: 'assets/images/famous.webp',
                  title: 'FAMOUS',
                  artist: 'Allday Project',
                ),
                SizedBox(width: 12),
                SongCard(
                  imagePath: 'assets/images/iu.webp',
                  title: 'Celebrity',
                  artist: 'IU',
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class LevelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String duration;
  final String lessons;
  final Color color;
  final Color iconColor;

  const LevelCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.lessons,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.music_note, color: iconColor, size: 20),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Spacer(),
            Row(
              children: [
                Text(
                  duration,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                Text(
                  lessons,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
