import 'package:flutter/material.dart';

import '../pages/song_detail_page.dart';
<<<<<<< HEAD
import '../models/song.dart';

class SongCard extends StatelessWidget {
  final Song song;

  const SongCard({
    super.key,
    required this.song,
=======

class SongCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String artist;

  const SongCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.artist,
>>>>>>> origin/Feature_CM
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
<<<<<<< HEAD
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongDetailPage(song: song),
          ),
        );
      },
      child: SizedBox(
        width: 140, // 카드 가로 크기
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1) 앨범 아트/커버 이미지
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                song.albumCover,
                width: 140,
                height: 140,
                fit: BoxFit.contain,
                // 에러 시 로딩 이미지 아이콘
                errorBuilder: (context, error, stack) {
                  return Container(
                    width: 140,
                    height: 140,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // 2) 제목
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            // 3) 아티스트
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
=======
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SongDetailPage()),
        );
      },
      child: Container(
        width: 160,
        child: Column(
          mainAxisSize: MainAxisSize.min, // 추가!
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 앨범커버
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.music_note,
                          color: Colors.grey[400],
                          size: 40,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8), // 12 → 8로 줄여도 충분
            // 곡 제목
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 2), // 4 → 2로 줄임
            // 아티스트
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w400,
              ),
>>>>>>> origin/Feature_CM
            ),
          ],
        ),
      ),
    );
  }
}
