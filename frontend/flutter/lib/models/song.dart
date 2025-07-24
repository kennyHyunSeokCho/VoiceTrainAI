// lib/models/song.dart
class Song {
  final String title;
  final String artist;
  final String albumCover; // 이미지 경로, 없으면 ''로
  final String difficulty;
  final String range;
  final String lyrics;
  final String duration;

  Song({
    required this.title,
    required this.artist,
    required this.albumCover,
    required this.difficulty,
    required this.range,
    required this.lyrics,
    required this.duration,
  });
}