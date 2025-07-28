import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config_service.dart';

class VocalRangeAnalysis {
  final String songTitle;
  final String artist;
  final String totalRange;
  final String comfortableRange;
  final String coreRange;
  final String difficulty;
  final String analysisStatus;

  VocalRangeAnalysis({
    required this.songTitle,
    required this.artist,
    required this.totalRange,
    required this.comfortableRange,
    required this.coreRange,
    required this.difficulty,
    required this.analysisStatus,
  });

  factory VocalRangeAnalysis.fromJson(Map<String, dynamic> json) {
    return VocalRangeAnalysis(
      songTitle: json['song_title'] ?? '',
      artist: json['artist'] ?? '',
      totalRange: json['total_range'] ?? '',
      comfortableRange: json['comfortable_range'] ?? '',
      coreRange: json['core_range'] ?? '',
      difficulty: json['difficulty'] ?? '',
      analysisStatus: json['analysis_status'] ?? '',
    );
  }
}

class VocalRangeService {
  // 백엔드 서버 URL 설정
  static String get baseUrl => ApiConfigService.baseUrl;

  /// 노래의 음역대를 분석합니다.
  static Future<VocalRangeAnalysis> analyzeVocalRange(
    String title,
    String artist,
  ) async {
    try {
      print('HTTP 요청 시작: $baseUrl/api/vocal-range/$title/$artist'); // 디버깅용

      final response = await http
          .get(
            Uri.parse('$baseUrl/api/vocal-range/$title/$artist'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 10), // 10초 타임아웃 설정
            onTimeout: () {
              print('HTTP 요청 타임아웃'); // 디버깅용
              throw Exception('Request timeout');
            },
          );

      print('HTTP 응답 상태 코드: ${response.statusCode}'); // 디버깅용
      print('HTTP 응답 본문: ${response.body}'); // 디버깅용

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return VocalRangeAnalysis.fromJson(data);
      } else {
        print('API 호출 실패: ${response.statusCode}'); // 디버깅용
        // API 호출 실패 시 기본값 반환
        return VocalRangeAnalysis(
          songTitle: title,
          artist: artist,
          totalRange: '분석 실패',
          comfortableRange: '분석 실패',
          coreRange: '분석 실패',
          difficulty: '분석 실패',
          analysisStatus: 'failed',
        );
      }
    } catch (e) {
      print('HTTP 요청 오류: $e'); // 디버깅용
      // 네트워크 오류 등 예외 발생 시 기본값 반환
      return VocalRangeAnalysis(
        songTitle: title,
        artist: artist,
        totalRange: '연결 오류',
        comfortableRange: '연결 오류',
        coreRange: '연결 오류',
        difficulty: '연결 오류',
        analysisStatus: 'error',
      );
    }
  }

  /// URL 인코딩을 처리하여 안전한 API 호출을 합니다.
  static Future<VocalRangeAnalysis> analyzeVocalRangeSafe(
    String title,
    String artist,
  ) async {
    try {
      // URL 인코딩 처리
      final encodedTitle = Uri.encodeComponent(title);
      final encodedArtist = Uri.encodeComponent(artist);

      print(
        'API 호출: $baseUrl/api/vocal-range/$encodedTitle/$encodedArtist',
      ); // 디버깅용

      return await analyzeVocalRange(encodedTitle, encodedArtist);
    } catch (e) {
      print('음역대 분석 오류: $e'); // 디버깅용
      return VocalRangeAnalysis(
        songTitle: title,
        artist: artist,
        totalRange: '인코딩 오류',
        comfortableRange: '인코딩 오류',
        coreRange: '인코딩 오류',
        difficulty: '인코딩 오류',
        analysisStatus: 'error',
      );
    }
  }
}
