import 'package:flutter/material.dart';

import '../pages/song_detail_page.dart';

class SongCard extends StatelessWidget {
  final String title;
  final String artist;
  final String imagePath;

  const SongCard({
    super.key,
    required this.title,
    required this.artist,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongDetailPage(
              title: title,
              artist: artist,
              imagePath: imagePath,
            ),
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
                imagePath,
                width: 140,
                height: 140,
                fit: BoxFit.contain,
                // 에러 시 로딩 이미지 아이콘
                errorBuilder: (context, error, stack) {
                  return Container(
                    width: 140,
                    height: 90,
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
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            // 3) 아티스트
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
