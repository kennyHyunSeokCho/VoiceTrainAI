import 'package:flutter/material.dart';
import '../models/song.dart';

class SongDetailPage extends StatelessWidget {
  final Song song;

  const SongDetailPage({super.key, required this.song});

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
                song.albumCover,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.music_note, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 2) Song Info: Singer, Title, Tags
            Text(song.artist, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              song.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(song.range, style: TextStyle(fontSize: 12))),
                Chip(label: Text(song.difficulty, style: TextStyle(fontSize: 12))),
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
            Text(
              song.lyrics,
              style: TextStyle(height: 1.4),
            ),
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
