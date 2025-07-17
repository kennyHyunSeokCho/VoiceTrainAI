import 'package:flutter/material.dart';

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
    return Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 앨범커버 - 정사각형으로 고정
          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.4,
              maxHeight: MediaQuery.of(context).size.width * 0.4,
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
<<<<<<< HEAD
                width: double.infinity,
=======
>>>>>>> 82cc4505750af6e4ee2d4559341fcc9ab375dd61
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
                  child: _buildImage(imagePath),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
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

          const SizedBox(height: 2),
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
    );
  }

  Widget _buildImage(String path) {
    // S3 URL이 기본 경로만 있는 경우 기본 이미지 표시
    if (path.contains(
          'ai-vocal-test-chaemin.s3.ap-northeast-2.amazonaws.com/album_covers/optimize',
        ) &&
        !path.contains('.jpg') &&
        !path.contains('.png') &&
        !path.contains('.jpeg') &&
        !path.contains('.webp')) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, color: Colors.grey[400], size: 40),
            const SizedBox(height: 8),
            Text(
              '앨범 커버',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stack) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.music_note, color: Colors.grey[400], size: 40),
          );
        },
      );
    } else {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stack) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.music_note, color: Colors.grey[400], size: 40),
          );
        },
      );
    }
  }
}
