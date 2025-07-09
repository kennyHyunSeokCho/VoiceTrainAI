import 'package:flutter/material.dart';
import '../models/song.dart';

class SongDetailPage extends StatelessWidget {
  final String title;
  final String artist;
  final String imagePath;

  const SongDetailPage({
    super.key,
    required this.title,
    required this.artist,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1) Large Banner
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/iu.webp',
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),

            // 2) Song Info: Singer, Title, Tags
            Text('IU', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              'Never Ending Story',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: const [
                Chip(label: Text('F3 - D5', style: TextStyle(fontSize: 12))),
                Chip(label: Text('미리듣기', style: TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 24),

            // 3) Quick Actions: 연습현황, 피드백 히스토리, 녹음파일
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _iconLabel(Icons.schedule, '연습현황'),
                _iconLabel(Icons.history, '피드백 히스토리'),
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
                  child: _iconLabel(Icons.graphic_eq, 'AI 보컬 합성'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 4) Action Buttons: Play & Share
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('전체 듣기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9A82DB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('즐겨찾기'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(100, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 5) Cover Song Section
            const Text(
              'Cover Song',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // 6) Lyrics Section (텍스트만)
            const Text(
              '가사',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('''
손 닿을 수 없는 저기 어딘가
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
아름다운 시절 속에 머문 그대이기에
              ''', style: TextStyle(height: 1.4)),
          ],
        ),
      ),

      // 7) Bottom Record Button
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF9A82DB),
            onPressed: () {
              // Song 객체 생성 (실제 데이터 연동 시 수정)
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
            label: const Text('녹음하기', style: TextStyle(color: Colors.black54)),
            icon: const Icon(Icons.mic, color: Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _iconLabel(IconData icon, String label) => Column(
    children: [
      Icon(icon, size: 28, color: Colors.grey.shade700),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
