import 'package:flutter/material.dart';
import '../pages/song_detail_page.dart';
import '../models/song.dart';

class SongCard extends StatelessWidget {
  final Song song;

  const SongCard({
    super.key,
    required this.song,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongDetailPage(song: song),
          ),
        );
      },
      child: Container(
        width: 160,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                    song.albumCover.isNotEmpty
                        ? song.albumCover
                        : 'assets/images/default_album_cover.webp', // 기본 이미지 경로
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
            const SizedBox(height: 8),
            // 곡 제목
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // 아티스트
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
