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
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 앨범커버 (정사각형 비율 유지)
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  // Image.network를 다시 Image.asset으로 되돌립니다.
                  child: Image.asset(
                    song.albumCover.isNotEmpty
                        ? song.albumCover
                        : 'assets/images/default_album_cover.webp',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) {
                      return Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.music_note, color: Colors.grey[400], size: 40),
                      );
                    },
                  ),
                ),
              ),
            ),

            // 2. 텍스트 부분 (Expanded로 남은 공간을 채움)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, left: 4, right: 4), // 상단 패딩을 8에서 6으로 줄임
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15, // 폰트 크기를 16에서 15로 줄임
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13, // 폰트 크기를 14에서 13으로 줄임
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
