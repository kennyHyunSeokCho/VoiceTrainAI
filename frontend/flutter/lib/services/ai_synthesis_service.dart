import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class AISynthesisService {
  // 백엔드 API 기본 URL (환경에 따라 변경 필요)
  static const String baseUrl = 'http://localhost:8000'; // 개발 환경
  // static const String baseUrl = 'https://your-production-api.com'; // 프로덕션 환경

  /// AI 음성 합성 시작
  static Future<Map<String, dynamic>> startAISynthesis({
    required String userId,
    required String singerName,
    required String songName,
    String? userVocalS3,
    String? vocalS3,
    String? instS3,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai-synthesis/synthesis/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'singer_name': singerName,
          'song_name': songName,
          'user_vocal_s3': userVocalS3,
          'vocal_s3': vocalS3,
          'inst_s3': instS3,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'AI 합성 시작 실패: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('AI 합성 시작 중 오류 발생: $e');
    }
  }

  /// AI 합성 상태 확인
  static Future<Map<String, dynamic>> getSynthesisStatus({
    required String jobId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ai-synthesis/synthesis/status/$jobId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('상태 확인 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('상태 확인 중 오류 발생: $e');
    }
  }

  /// AI 합성 작업 취소
  static Future<Map<String, dynamic>> cancelSynthesis({
    required String jobId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai-synthesis/synthesis/cancel/$jobId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('합성 취소 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('합성 취소 중 오류 발생: $e');
    }
  }

  /// Pod 연결 상태 확인
  static Future<Map<String, dynamic>> checkPodHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ai-synthesis/synthesis/pod-health'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Pod 상태 확인 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Pod 상태 확인 중 오류 발생: $e');
    }
  }

  /// Song 객체에서 AI 합성 요청 데이터 생성
  static Map<String, dynamic> createSynthesisRequest({
    required Song song,
    required String userId,
    String? userVocalS3,
    String? vocalS3,
    String? instS3,
  }) {
    return {
      'user_id': userId,
      'singer_name': song.artist,  // 백엔드에서 artist로 받음
      'song_name': song.title,     // 백엔드에서 title로 받음
      'user_vocal_s3': userVocalS3,
      'vocal_s3': vocalS3,
      'inst_s3': instS3,
    };
  }
}
