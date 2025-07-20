// lib/models/song.dart
class Song {
  final String title;
  final String artist;
  final String albumCover; // 이미지 경로, 없으면 ''로
  final String difficulty;
  final String range;
  final String lyrics;
  final String duration;
  final String? comfortableRange; // 편안한 음역대
  final String? coreRange; // 핵심 음역대
  final String? analysisStatus; // 분석 상태

  Song({
    required this.title,
    required this.artist,
    required this.albumCover,
    required this.difficulty,
    required this.range,
    required this.lyrics,
    required this.duration,
    this.comfortableRange,
    this.coreRange,
    this.analysisStatus,
  });

  // 음역대 분석 정보로 Song 객체를 업데이트하는 메서드
  Song copyWithVocalRange({
    String? comfortableRange,
    String? coreRange,
    String? analysisStatus,
  }) {
    return Song(
      title: this.title,
      artist: this.artist,
      albumCover: this.albumCover,
      difficulty: this.difficulty,
      range: this.range,
      lyrics: this.lyrics,
      duration: this.duration,
      comfortableRange: comfortableRange ?? this.comfortableRange,
      coreRange: coreRange ?? this.coreRange,
      analysisStatus: analysisStatus ?? this.analysisStatus,
    );
  }
}