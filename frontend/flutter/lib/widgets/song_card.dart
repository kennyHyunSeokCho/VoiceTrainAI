import 'package:flutter/material.dart';

import '../pages/song_detail_page.dart';

class SongCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String artist;

  const SongCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.artist,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
            ),
          ],
        ),
      ),
    );
  }
}
