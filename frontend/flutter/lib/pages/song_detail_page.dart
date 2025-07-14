import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/song.dart';

class SongDetailPage extends StatefulWidget {
  const SongDetailPage({super.key});

  @override
  State<SongDetailPage> createState() => _SongDetailPageState();
}

class _SongDetailPageState extends State<SongDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: Stack(
        children: [
          // 메인 콘텐츠
          CustomScrollView(
            slivers: [
              // 커스텀 앱바
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                pinned: true,
                backgroundColor: const Color(0xFFF8F7FF),
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      size: 20,
                      color: const Color(0xFF6B46C1),
                    ),
                    onPressed: () => Navigator.pop(context),
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
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF8B5CF6,
                                ).withOpacity(0.15),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
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
                                fontSize: 18,
                                color: const Color(0xFF8B5CF6),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Never Ending Story',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1F2937),
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 태그 (더 세련된 디자인)
                      Center(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildTag('F3 - D5', const Color(0xFFE0E7FF)),
                            _buildDifficultyTag('중급'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 퀵 액션 버튼들 (더 세련된 디자인)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildQuickAction(Icons.schedule_rounded, '연습현황'),
                            _buildQuickAction(
                              Icons.history_rounded,
                              '피드백 히스토리',
                            ),
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
                                Icons.graphic_eq_rounded,
                                'AI 보컬 합성',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 메인 액션 버튼들 (연보라색 테마)
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF8B5CF6,
                                    ).withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {},
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '전체 듣기',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFE0E7FF),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF8B5CF6,
                                    ).withOpacity(0.1),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {},
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.favorite_border_rounded,
                                        color: const Color(0xFF8B5CF6),
                                        size: 28,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '즐겨찾기',
                                        style: TextStyle(
                                          color: const Color(0xFF8B5CF6),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
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

                      const SizedBox(height: 40),

                      // Cover Song 섹션
                      _buildSectionTitle('Cover Song'),
                      const SizedBox(height: 20),

                      // Cover Song 카드 (연보라색 테마)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
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
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'IU • Cover Version',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: const Color(0xFF8B5CF6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.play_circle_outline_rounded,
                              color: const Color(0xFF8B5CF6),
                              size: 36,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 가사 섹션
                      _buildSectionTitle('가사'),
                      const SizedBox(height: 20),

                      // 가사 (완전한 중앙 정렬)
                      Center(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                              height: 2.0,
                              fontSize: 16,
                              color: const Color(0xFF374151),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
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

          // 하단 녹음 버튼 (연보라색 테마)
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
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
                      Icon(Icons.mic_rounded, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        '녹음하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B46C1),
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0E7FF)),
          ),
          child: Icon(icon, size: 28, color: const Color(0xFF8B5CF6)),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B46C1),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1F2937),
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
        backgroundColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF166534);
        icon = Icons.star_rounded;
        break;
      case '중급':
      case 'intermediate':
        backgroundColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        icon = Icons.star_rounded;
        break;
      case '고급':
      case 'advanced':
        backgroundColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        icon = Icons.star_rounded;
        break;
      default:
        backgroundColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF6B7280);
        icon = Icons.star_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 6),
          Text(
            difficulty,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
