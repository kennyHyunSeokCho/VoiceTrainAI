import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/song.dart';

class SongDetailPage extends StatelessWidget {
  const SongDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 배경 그라데이션
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.purple[50]!, Colors.white, Colors.pink[50]!],
              ),
            ),
          ),

          // 메인 콘텐츠
          CustomScrollView(
            slivers: [
              // 커스텀 앱바
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                pinned: true,
                backgroundColor: Colors.white.withOpacity(0.8),
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      size: 20,
                      color: Colors.black87,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),

              // 메인 콘텐츠
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // 앨범 아트 (더 큰 크기, 부드러운 그림자)
                      Center(
                        child: Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/iu.webp',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 곡 정보 (더 세련된 타이포그래피)
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'IU',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Never Ending Story',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 태그 (더 세련된 디자인)
                      Center(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildTag('F3 - D5', Colors.purple[100]!),
                            _buildDifficultyTag('중급'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 퀵 액션 버튼들 (더 세련된 디자인)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildQuickAction(Icons.schedule, '연습현황'),
                            _buildQuickAction(Icons.history, '피드백 히스토리'),
                            GestureDetector(
                              onTap: () {
                                final song = Song(
                                  title: 'Never Ending Story',
                                  artist: 'IU',
                                  albumCover: 'assets/images/iu.webp',
                                  difficulty: '중급',
                                  range: 'F3 ~ D5',
                                  lyrics:
                                      '''손 닿을 수 없는 저기 어딘가\n오늘도 난 숨 쉬고 있지만\n너와 머물던 작은 의자 위에\n같은 모습의 바람이 지나네\n\n너는 떠나며 마치 날 떠나가듯이\n멀리 손을 흔들며\n언젠가 추억에 남겨져 갈 거라고\n\n그리워하면 언젠가 만나게 되는\n어느 영화와 같은 일들이 이뤄져 가기를\n힘겨워 한 날에 너를 지킬 수 없었던\n아름다운 시절 속에 머문 그대이기에\n\n너는 떠나며 마치 날 떠나가듯이\n멀리 손을 흔들며\n언젠가 추억에 남겨져 갈 거라고\n\n그리워하면 언젠가 만나게 되는\n어느 영화와 같은 일들이 이뤄져 가기를\n힘겨워 한 날에 너를 지킬 수 없었던\n아름다운 시절 속에 머문 그대여\n\n그리워하면 언젠가 만나게 되는\n어느 영화와 같은 일들이 이뤄져 가기를\n힘겨워 한 날에 너를 지킬 수 없었던\n아름다운 시절 속에 머문 그대이기에''',
                                  duration: '3:40',
                                );
                                Navigator.pushNamed(
                                  context,
                                  '/ai-vocal-loading',
                                  arguments: song,
                                );
                              },
                              child: _buildQuickAction(
                                Icons.graphic_eq,
                                'AI 보컬 합성',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 메인 액션 버튼들 (더 세련된 디자인)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple[400]!,
                                    Colors.pink[400]!,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple[300]!.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.play_arrow, size: 24),
                                label: const Text(
                                  '전체 듣기',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[300]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: Icon(
                                Icons.favorite_border,
                                color: Colors.grey[600],
                              ),
                              label: Text(
                                '즐겨찾기',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(120, 56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Cover Song 섹션
                      _buildSectionTitle('Cover Song'),
                      const SizedBox(height: 20),

                      // Cover Song 카드 (새로운 디자인)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: const DecorationImage(
                                  image: AssetImage('assets/images/iu.webp'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Never Ending Story',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'IU • Cover Version',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.play_circle_outline,
                              color: Colors.grey[600],
                              size: 32,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 가사 섹션
                      _buildSectionTitle('가사'),
                      const SizedBox(height: 20),

                      // 가사 컨테이너 (더 세련된 디자인)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          '''손 닿을 수 없는 저기 어딘가
오늘도 난 숨 쉬고 있지만
너와 머물던 작은 의자 위에
같은 모습의 바람이 지나네

너는 떠나며 마치 날 떠나가듯이
멀리 손을 흔들며
언젠가 추억에 남겨져 갈 거라고

그리워하면 언젠가 만나게 되는
어느 영화와 같은 일들이 이뤄져 가기를
힘겨워 한 날에 너를 지킬 수 없었던
아름다운 시절 속에 머문 그대이기에

너는 떠나며 마치 날 떠나가듯이
멀리 손을 흔들며
언젠가 추억에 남겨져 갈 거라고

그리워하면 언젠가 만나게 되는
어느 영화와 같은 일들이 이뤄져 가기를
힘겨워 한 날에 너를 지킬 수 없었던
아름다운 시절 속에 머문 그대여

그리워하면 언젠가 만나게 되는
어느 영화와 같은 일들이 이뤄져 가기를
힘겨워 한 날에 너를 지킬 수 없었던
아름다운 시절 속에 머문 그대이기에''',
                          style: TextStyle(
                            height: 1.6,
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 하단 녹음 버튼 (더 세련된 디자인)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[400]!, Colors.pink[400]!],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple[300]!.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    final song = Song(
                      title: 'Never Ending Story',
                      artist: 'IU',
                      albumCover: 'assets/images/iu.webp',
                      difficulty: '중급',
                      range: 'F3 ~ D5',
                      lyrics:
                          '''손 닿을 수 없는 저기 어딘가\n오늘도 난 숨 쉬고 있지만\n너와 머물던 작은 의자 위에\n같은 모습의 바람이 지나네\n\n너는 떠나며 마치 날 떠나가듯이\n멀리 손을 흔들며\n언젠가 추억에 남겨져 갈 거라고\n\n그리워하면 언젠가 만나게 되는\n어느 영화와 같은 일들이 이뤄져 가기를\n힘겨워 한 날에 너를 지킬 수 없었던\n아름다운 시절 속에 머문 그대이기에\n\n너는 떠나며 마치 날 떠나가듯이\n멀리 손을 흔들며\n언젠가 추억에 남겨져 갈 거라고\n\n그리워하면 언젠가 만나게 되는\n어느 영화와 같은 일들이 이뤄져 가기를\n힘겨워 한 날에 너를 지킬 수 없었던\n아름다운 시절 속에 머문 그대여\n\n그리워하면 언젠가 만나게 되는\n어느 영화와 같은 일들이 이뤄져 가기를\n힘겨워 한 날에 너를 지킬 수 없었던\n아름다운 시절 속에 머문 그대이기에''',
                      duration: '3:40',
                    );
                    Navigator.pushNamed(context, '/record', arguments: song);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mic, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        '녹음하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, size: 24, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildDifficultyTag(String difficulty) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (difficulty.toLowerCase()) {
      case '초급':
      case 'beginner':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[700]!;
        icon = Icons.star;
        break;
      case '중급':
      case 'intermediate':
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[700]!;
        icon = Icons.star;
        break;
      case '고급':
      case 'advanced':
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[700]!;
        icon = Icons.star;
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        icon = Icons.star;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            difficulty,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
