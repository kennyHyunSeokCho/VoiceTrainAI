import 'package:flutter/material.dart';
<<<<<<< HEAD
=======
import '../pages/song_detail_page.dart';
import '../models/song.dart';
>>>>>>> origin/Feature_DU

class SongCard extends StatelessWidget {
  final Song song;

  const SongCard({
    super.key,
    required this.song,
  });

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
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
=======
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
>>>>>>> origin/Feature_DU
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
<<<<<<< HEAD
                  child: _buildImage(imagePath),
=======
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
>>>>>>> origin/Feature_DU
                ),
              ),
            ),
          ),

<<<<<<< HEAD
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
=======
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
>>>>>>> origin/Feature_DU
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
