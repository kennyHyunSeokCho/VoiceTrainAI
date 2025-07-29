import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config_service.dart';

class VocalRangeAnalysis {
  final String? lowestNote;
  final String? highestNote;
  final String? rangeSpan;
  final List<String>? topNotes;
  final Map<String, int>? noteFrequencies;

  VocalRangeAnalysis({
    this.lowestNote,
    this.highestNote,
    this.rangeSpan,
    this.topNotes,
    this.noteFrequencies,
  });

  factory VocalRangeAnalysis.fromJson(Map<String, dynamic> json) {
    final vocalRange = json['vocal_range'] as Map<String, dynamic>?;
    if (vocalRange == null) return VocalRangeAnalysis();

    return VocalRangeAnalysis(
      lowestNote: vocalRange['lowest_note'] as String?,
      highestNote: vocalRange['highest_note'] as String?,
      rangeSpan: vocalRange['range_span'] as String?,
      topNotes: (vocalRange['top_notes'] as List<dynamic>?)?.cast<String>(),
      noteFrequencies: vocalRange['note_frequencies'] != null
          ? Map<String, int>.from(vocalRange['note_frequencies'])
          : null,
    );
  }
}

class VocalRangeService {
  /// 안전한 음역대 분석 (기존 메서드)
  static Future<VocalRangeAnalysis?> analyzeVocalRangeSafe(
    String title,
    String artist,
  ) async {
    try {
      final String backendUrl = await ApiConfigService.baseUrl;

      final response = await http
          .get(Uri.parse('$backendUrl/api/vocal-range/$artist/$title'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return VocalRangeAnalysis.fromJson(data);
        }
      }
    } catch (e) {
      print('음역대 분석 오류: $e');
    }
    return null;
  }

  /// 원곡 기반 음역대 분석 (새로운 메서드)
  static Future<VocalRangeAnalysis?> analyzeOriginalSongVocalRange(
    String title,
    String artist,
  ) async {
    try {
      print('🎵 원곡 음역대 분석 시작: $artist - $title');

      final String backendUrl = await ApiConfigService.baseUrl;

      final response = await http
          .get(
            Uri.parse(
              '$backendUrl/api/vocal-range/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(title)}',
            ),
          )
          .timeout(const Duration(seconds: 60)); // 분석 시간이 오래 걸릴 수 있으므로 60초로 설정

      print('📊 응답 상태 코드: ${response.statusCode}');
      print('📊 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final analysis = VocalRangeAnalysis.fromJson(data);
          print('✅ 음역대 분석 성공:');
          print('  - 최저음: ${analysis.lowestNote}');
          print('  - 최고음: ${analysis.highestNote}');
          print('  - 음역대: ${analysis.rangeSpan}');
          print('  - 주요 음들: ${analysis.topNotes}');
          return analysis;
        }
      } else if (response.statusCode == 404) {
        print('❌ 원곡 파일을 찾을 수 없습니다: $artist - $title');
      } else {
        print('❌ 음역대 분석 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ 음역대 분석 오류: $e');
    }
    return null;
  }
}
