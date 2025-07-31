import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config_service.dart';

class ScoreService {
  /// 점수를 서버에 저장합니다.
  static Future<Map<String, dynamic>> saveScore({
    required int songId,
    required double pitchScore,
    required double rhythmScore,
    required int totalScore,
    String? recordingPath,
  }) async {
    try {
      final baseUrl = await ApiConfigService.baseUrl;
      final url = Uri.parse('$baseUrl/api/feedback/save-score');
      
      print('📊 점수 저장 API 호출: $url');
      print('📊 데이터: 곡ID=$songId, 피치=$pitchScore, 리듬=$rhythmScore, 총점=$totalScore');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'song_id': songId,
          'pitch_score': pitchScore,
          'rhythm_score': rhythmScore,
          'total_score': totalScore,
          'recording_path': recordingPath,
        }),
      ).timeout(Duration(seconds: 10));

      print('📊 점수 저장 응답 상태: ${response.statusCode}');
      print('📊 점수 저장 응답 바디: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        print('❌ 점수 저장 실패: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': '점수 저장에 실패했습니다 (${response.statusCode})',
        };
      }
    } catch (e) {
      print('❌ 점수 저장 중 오류: $e');
      return {
        'success': false,
        'error': '점수 저장 중 오류가 발생했습니다: $e',
      };
    }
  }

  /// 사용자의 점수 그래프 데이터를 가져옵니다.
  static Future<Map<String, dynamic>> getScoreGraphData({
    int days = 30,
    int limit = 50,
  }) async {
    try {
      final baseUrl = await ApiConfigService.baseUrl;
      final url = Uri.parse('$baseUrl/api/feedback/score-graph?days=$days&limit=$limit');
      
      print('📈 점수 그래프 API 호출: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('📈 점수 그래프 응답 상태: ${response.statusCode}');
      print('📈 점수 그래프 응답 바디: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        print('❌ 점수 그래프 조회 실패: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': '점수 그래프 조회에 실패했습니다 (${response.statusCode})',
        };
      }
    } catch (e) {
      print('❌ 점수 그래프 조회 중 오류: $e');
      return {
        'success': false,
        'error': '점수 그래프 조회 중 오류가 발생했습니다: $e',
      };
    }
  }

  /// 테스트용 점수 그래프 데이터를 가져옵니다.
  static Future<Map<String, dynamic>> getTestScoreGraphData({
    required String userId,
    int days = 30,
    int limit = 50,
  }) async {
    try {
      final baseUrl = await ApiConfigService.baseUrl;
      final url = Uri.parse('$baseUrl/api/feedback/test/score-graph?user_id=$userId&days=$days&limit=$limit');
      
      print('📈 테스트 점수 그래프 API 호출: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('📈 테스트 점수 그래프 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        print('❌ 테스트 점수 그래프 조회 실패: ${response.statusCode}');
        return {
          'success': false,
          'error': '테스트 점수 그래프 조회에 실패했습니다',
        };
      }
    } catch (e) {
      print('❌ 테스트 점수 그래프 조회 중 오류: $e');
      return {
        'success': false,
        'error': '테스트 점수 그래프 조회 중 오류가 발생했습니다: $e',
      };
    }
  }

  /// 테스트용 점수 저장 (인증 불필요)
  static Future<Map<String, dynamic>> saveScoreTest({
    required String userId,
    required int songId,
    required double pitchScore,
    required double rhythmScore,
    required int totalScore,
    String? recordingPath,
  }) async {
    try {
      final baseUrl = await ApiConfigService.baseUrl;
      final url = Uri.parse('$baseUrl/api/feedback/test/save-score?user_id=$userId');
      
      print('📊 테스트 점수 저장 API 호출: $url');
      print('📊 데이터: 사용자=$userId, 곡ID=$songId, 피치=$pitchScore, 리듬=$rhythmScore, 총점=$totalScore');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'song_id': songId,
          'pitch_score': pitchScore,
          'rhythm_score': rhythmScore,
          'total_score': totalScore,
          'recording_path': recordingPath,
        }),
      ).timeout(Duration(seconds: 10));

      print('📊 테스트 점수 저장 응답 상태: ${response.statusCode}');
      print('📊 테스트 점수 저장 응답 바디: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        print('❌ 테스트 점수 저장 실패: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': '테스트 점수 저장에 실패했습니다 (${response.statusCode})',
        };
      }
    } catch (e) {
      print('❌ 테스트 점수 저장 중 오류: $e');
      return {
        'success': false,
        'error': '테스트 점수 저장 중 오류가 발생했습니다: $e',
      };
    }
  }
}