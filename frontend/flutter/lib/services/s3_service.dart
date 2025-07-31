import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../main.dart'; // CurrentUser 사용을 위해
import '../services/api_config_service.dart'; // ApiConfigService 추가

class S3Service {
  // 기존 getSongsFromS3 메서드는 일시적으로 주석 처리
  // Amplify Storage API 호환성 문제로 인해 나중에 수정 예정
  /*
  Future<List<Song>> getSongsFromS3() async {
    // 기존 코드는 나중에 수정
    return [];
  }
  */

  /// 사용자 보컬 파일을 ai-vocal-training-user 버킷에 업로드합니다.
  /// 업로드 위치: {사용자ID}/vocal/{사용자ID}_{노래제목}_record.wav
  static Future<String?> uploadUserVocalFile({
    required File file,
    required String songTitle,
    required String songArtist,
  }) async {
    try {
      // 현재 로그인된 사용자 ID 가져오기
      String? userId = CurrentUser.getUserNickname();
      if (userId == null) {
        print('❌ 로그인된 사용자 정보가 없습니다.');
        return null;
      }

      // 사용자 ID와 노래 정보 정리 (특수문자 제거)
      String cleanUserId = _cleanFileName(userId);
      String cleanSongTitle = _cleanFileName(songTitle);
      String cleanSongArtist = _cleanFileName(songArtist);

      // 파일 확장자 가져오기
      String extension = file.path.split('.').last.toLowerCase();
      if (extension.isEmpty) extension = 'wav'; // 기본값

      // S3 키 생성: {사용자ID}/vocal/{사용자ID}_{노래제목}_record.{확장자}
      String fileName = '${cleanUserId}_${cleanSongTitle}_record.$extension';
      String s3Key = '$cleanUserId/vocal/$fileName';
      String bucket = 'ai-vocal-training-user';
      String contentType = 'audio/$extension';

      print('🎵 사용자 보컬 파일 업로드 시작: $s3Key');

      // 백엔드에서 presigned URL 요청
      String? presignedUrl = await _getPresignedUrl(bucket, s3Key, contentType);
      if (presignedUrl == null) {
        print('❌ Presigned URL 생성 실패');
        return null;
      }

      // Presigned URL로 파일 업로드
      bool uploadSuccess = await _uploadToPresignedUrl(
        presignedUrl,
        file,
        contentType,
      );
      if (!uploadSuccess) {
        print('❌ 파일 업로드 실패');
        return null;
      }

      // 업로드 성공 시 S3 URL 반환
      String uploadedUrl =
          'https://$bucket.s3.ap-northeast-2.amazonaws.com/$s3Key';
      print('✅ 사용자 보컬 파일 업로드 성공: $uploadedUrl');
      return uploadedUrl;
    } catch (e) {
      print('❌ 사용자 보컬 파일 업로드 실패: $e');
      return null;
    }
  }

  /// 실시간 녹음 파일을 ai-vocal-training-user 버킷에 업로드합니다.
  /// 업로드 위치: {사용자ID}/vocal/{가수명}_{노래제목}_record.wav
  static Future<String?> uploadRealtimeRecordingFile({
    required File file,
    required String songTitle,
    required String songArtist,
  }) async {
    try {
      // 현재 로그인된 사용자 ID 가져오기
      String? userId = CurrentUser.getUserNickname();
      if (userId == null) {
        print('❌ 로그인된 사용자 정보가 없습니다.');
        return null;
      }

      // 노래 정보 정리 (특수문자 제거)
      String cleanSongTitle = _cleanFileName(songTitle);
      String cleanSongArtist = _cleanFileName(songArtist);

      // 파일 확장자 가져오기
      String extension = file.path.split('.').last.toLowerCase();
      if (extension.isEmpty) extension = 'wav'; // 기본값

      // S3 키 생성: {사용자ID}/vocal/{가수명}_{노래제목}_record.{확장자}
      String fileName =
          '${cleanSongArtist}_${cleanSongTitle}_record.$extension';
      String s3Key = '$userId/vocal/$fileName';
      String bucket = 'ai-vocal-training-user';
      String contentType = 'audio/$extension';

      print('🎵 실시간 녹음 파일 업로드 시작: $s3Key');

      // 백엔드에서 presigned URL 요청
      String? presignedUrl = await _getPresignedUrl(bucket, s3Key, contentType);
      if (presignedUrl == null) {
        print('❌ Presigned URL 생성 실패');
        return null;
      }

      // Presigned URL로 파일 업로드
      bool uploadSuccess = await _uploadToPresignedUrl(
        presignedUrl,
        file,
        contentType,
      );
      if (!uploadSuccess) {
        print('❌ 파일 업로드 실패');
        return null;
      }

      // 업로드 성공 시 S3 URL 반환
      String uploadedUrl =
          'https://$bucket.s3.ap-northeast-2.amazonaws.com/$s3Key';
      print('✅ 실시간 녹음 파일 업로드 성공: $uploadedUrl');
      return uploadedUrl;
    } catch (e) {
      print('❌ 실시간 녹음 파일 업로드 실패: $e');
      return null;
    }
  }

  /// 백엔드에서 presigned URL 요청
  static Future<String?> _getPresignedUrl(
    String bucket,
    String s3Key,
    String contentType,
  ) async {
    try {
      final backendUrl = await ApiConfigService.baseUrl;

      print('🔗 백엔드 요청 시작: $backendUrl/upload/presigned-url');
      print(
        '📦 요청 데이터: bucket=$bucket, s3_key=$s3Key, content_type=$contentType',
      );

      final response = await http
          .post(
            Uri.parse('$backendUrl/upload/presigned-url'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'bucket': bucket,
              's3_key': s3Key,
              'content_type': contentType,
            }),
          )
          .timeout(const Duration(seconds: 30)); // 30초 타임아웃

      print('📡 백엔드 응답 상태: ${response.statusCode}');
      print('📄 백엔드 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final presignedUrl = data['presigned_url'];
        print('✅ Presigned URL 생성 성공: ${presignedUrl?.substring(0, 50)}...');
        return presignedUrl;
      } else {
        print('❌ Presigned URL 요청 실패: ${response.statusCode}');
        print('❌ 응답 내용: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Presigned URL 요청 중 오류: $e');
      return null;
    }
  }

  /// Presigned URL로 파일 업로드
  static Future<bool> _uploadToPresignedUrl(
    String presignedUrl,
    File file,
    String contentType,
  ) async {
    try {
      print('📁 파일 업로드 시작...');
      print('📏 파일 크기: ${await file.length()} bytes');

      final fileBytes = await file.readAsBytes();
      print('📦 파일 바이트 읽기 완료: ${fileBytes.length} bytes');

      print('🚀 S3 업로드 요청 시작...');
      final response = await http
          .put(
            Uri.parse(presignedUrl),
            headers: {'Content-Type': contentType},
            body: fileBytes,
          )
          .timeout(const Duration(minutes: 5)); // 5분 타임아웃

      print('📡 S3 응답 상태: ${response.statusCode}');
      print('📄 S3 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ S3 업로드 성공!');
        return true;
      } else {
        print('❌ S3 업로드 실패: ${response.statusCode}');
        print('❌ S3 응답 내용: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ S3 업로드 중 오류: $e');
      return false;
    }
  }

  /// 파일을 S3 버킷에 업로드합니다.
  static Future<String?> uploadFile({
    required File file,
    required String artist,
    required String title,
    required FileType fileType,
  }) async {
    try {
      String cleanArtist = _cleanFileName(artist);
      String cleanTitle = _cleanFileName(title);

      // 파일 타입에 따른 경로 및 파일명 생성
      String s3Key = _generateS3Key(cleanArtist, cleanTitle, fileType);

      // Amplify Storage를 사용한 파일 업로드
      final result = await Amplify.Storage.uploadFile(
        path: StoragePath.fromString(s3Key),
        localFile: AWSFile.fromPath(file.path),
      ).result;

      // 업로드 성공 시 완전한 URL 반환
      String uploadedUrl = _generatePublicUrl(s3Key);
      print('✅ 파일 업로드 성공: $uploadedUrl');
      return uploadedUrl;
    } catch (e) {
      print('❌ 파일 업로드 실패: $e');
      return null;
    }
  }

  /// 파일 타입에 따른 S3 키(경로) 생성
  static String _generateS3Key(String artist, String title, FileType fileType) {
    switch (fileType) {
      case FileType.original:
        return 'MusicFile/$artist/original/${artist}_$title.wav';
      case FileType.inst:
        return 'MusicFile/$artist/inst/${artist}_${title}_inst.wav';
      case FileType.albumCover:
        return 'album_cover/${artist}_$title.jpg';
      case FileType.midi:
        return 'MusicFile/$artist/midi/${artist}_${title}_midi.mid';
      case FileType.userRecording:
        return 'recordings/${artist}_${title}_${DateTime.now().millisecondsSinceEpoch}.wav';
    }
  }

  /// S3 키로부터 공개 URL 생성
  static String _generatePublicUrl(String s3Key) {
    return 'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/$s3Key';
  }

  /// 파일 존재 여부 확인
  static Future<bool> checkFileExists(String s3Key) async {
    try {
      await Amplify.Storage.getProperties(
        path: StoragePath.fromString(s3Key),
      ).result;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 원곡 파일의 S3 URL을 생성합니다.
  static String getOriginalSongUrl(String artist, String title) {
    // 파일명에서 특수문자 제거 및 공백 처리
    String cleanArtist = _cleanFileName(artist);
    String cleanTitle = _cleanFileName(title);

    return 'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/MusicFile/$cleanArtist/original/${cleanArtist}_$cleanTitle.wav';
  }

  /// AI 합성 파일의 presigned URL을 백엔드에서 가져옵니다.
  static Future<String?> getAiVocalPresignedUrl(
    String userId,
    String songTitle,
  ) async {
    try {
      print('🔍 AI 보컬 presigned URL 요청 시작');
      print('   - 사용자 ID: $userId');
      print('   - 노래 제목: $songTitle');

      final backendUrl = await ApiConfigService.baseUrl;
      final requestUrl =
          '$backendUrl/api/ai-vocal-presigned-url/$userId/$songTitle';
      print('   - 요청 URL: $requestUrl');

      final response = await http
          .get(Uri.parse(requestUrl))
          .timeout(const Duration(seconds: 10));

      print('   - 응답 상태 코드: ${response.statusCode}');
      print('   - 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final presignedUrl = data['presigned_url'];
        print('✅ AI 보컬 presigned URL 성공: $presignedUrl');
        return presignedUrl;
      } else {
        print('❌ AI 합성 파일 presigned URL 요청 실패: ${response.statusCode}');
        print('   - 응답 본문: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ AI 합성 파일 presigned URL 요청 오류: $e');
      return null;
    }
  }

  /// Inst 파일의 S3 URL을 생성합니다.
  /// 경로: https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/MusicFile/가수명/inst/가수명_노래제목_inst.wav
  static String getInstSongUrl(String artist, String title) {
    // 파일명에서 특수문자 제거 및 공백 처리
    String cleanArtist = _cleanFileName(artist);
    String cleanTitle = _cleanFileName(title);

    return 'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/MusicFile/$cleanArtist/inst/${cleanArtist}_$cleanTitle\_inst.wav';
  }

  /// 앨범 커버 이미지의 S3 URL을 생성합니다.
  /// 경로: https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/album_cover/가수명_노래제목.jpg
  static String getAlbumCoverUrl(String artist, String title) {
    // 파일명에서 특수문자 제거 및 공백 처리
    String cleanArtist = _cleanFileName(artist);
    String cleanTitle = _cleanFileName(title);

    return 'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/album_cover/${cleanArtist}_$cleanTitle.jpg';
  }

  /// 백엔드에서 앨범 커버 URL을 가져옵니다.
  static Future<String?> getAlbumCoverUrlFromBackend(
    String artist,
    String title,
  ) async {
    try {
      print('🎵 앨범 커버 URL 조회 시작: $artist - $title');

      final backendUrl = await ApiConfigService.baseUrl;
      final response = await http
          .get(
            Uri.parse(
              '$backendUrl/api/album-cover/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(title)}',
            ),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final albumCoverUrl = data['album_cover_url'];
          print('✅ 앨범 커버 URL 조회 성공: $albumCoverUrl');
          return albumCoverUrl;
        } else {
          print('❌ 앨범 커버 URL 조회 실패: ${data['detail']}');
          return null;
        }
      } else {
        print('❌ 앨범 커버 URL 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ 앨범 커버 URL 조회 오류: $e');
      return null;
    }
  }

  /// 노래 제목만으로 앨범 커버 URL을 가져옵니다.
  static Future<String?> getAlbumCoverUrlByTitle(String title) async {
    try {
      print('🎵 앨범 커버 URL 조회 (제목만): $title');

      final backendUrl = await ApiConfigService.baseUrl;
      final response = await http
          .get(
            Uri.parse(
              '$backendUrl/api/album-cover-by-title/${Uri.encodeComponent(title)}',
            ),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final albumCoverUrl = data['album_cover_url'];
          print('✅ 앨범 커버 URL 조회 성공: $albumCoverUrl');
          return albumCoverUrl;
        } else {
          print('❌ 앨범 커버 URL 조회 실패: ${data['detail']}');
          return null;
        }
      } else {
        print('❌ 앨범 커버 URL 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ 앨범 커버 URL 조회 오류: $e');
      return null;
    }
  }

  /// 노래 제목만으로 앨범 커버 URL을 생성합니다.
  static String getAlbumCoverUrlByTitleOnly(String title) {
    String cleanTitle = _cleanFileName(title);
    return 'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/album_cover/$cleanTitle.jpg';
  }

  /// MIDI 파일의 S3 URL을 생성합니다.
  /// 경로: https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/MusicFile/가수명/midi/가수명_노래제목_midi.mid
  static String getMidiFileUrl(String artist, String title) {
    // 파일명에서 특수문자 제거 및 공백 처리
    String cleanArtist = _cleanFileName(artist);
    String cleanTitle = _cleanFileName(title);

    return 'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/MusicFile/$cleanArtist/midi/${cleanArtist}_$cleanTitle\_midi.mid';
  }

  /// 사용자 보컬 파일의 S3 URL을 생성합니다.
  /// 경로: https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/recordings/가수명_노래제목_업로드파일명
  static String getVocalSongUrl(String artist, String title, String fileName) {
    // 파일명에서 특수문자 제거 및 공백 처리
    String cleanArtist = _cleanFileName(artist);
    String cleanTitle = _cleanFileName(title);
    String cleanFileName = _cleanFileName(fileName);

    return 'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/recordings/${cleanArtist}_${cleanTitle}_$cleanFileName';
  }

  /// 오디오 파일 재생을 위한 presigned URL을 가져옵니다.
  static Future<String?> getAudioPresignedUrl(
    String userId,
    String filename,
  ) async {
    try {
      print('🎵 오디오 presigned URL 요청: $userId/$filename');
      final backendUrl = await ApiConfigService.baseUrl;

      final response = await http
          .get(
            Uri.parse(
              '$backendUrl/api/audio-presigned-url/${Uri.encodeComponent(userId)}/${Uri.encodeComponent(filename)}',
            ),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final presignedUrl = data['presigned_url'];
          print('✅ 오디오 presigned URL 생성 성공: $presignedUrl');
          return presignedUrl;
        }
      }

      print('❌ 오디오 presigned URL 생성 실패: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ 오디오 presigned URL 요청 실패: $e');
      return null;
    }
  }

  /// 파일명에서 사용할 수 없는 특수문자를 제거하고 공백을 언더스코어로 변경합니다.
  static String _cleanFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[^\w\s가-힣]'), '') // 특수문자 제거 (한글, 영문, 숫자, 공백만 허용)
        .replaceAll(RegExp(r'\s+'), '_') // 공백을 언더스코어로 변경
        .trim();
  }

  /// 사용자가 업로드한 파일 목록을 가져옵니다.
  static Future<List<Map<String, dynamic>>> getUserUploads(
    String userId,
  ) async {
    try {
      print('🎵 사용자 업로드 파일 목록 조회 시작: $userId');

      final backendUrl = await ApiConfigService.baseUrl;
      final apiUrl = '$backendUrl/api/user-uploads/$userId';
      
      print('🔗 API 호출 URL: $apiUrl');

      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 30));

      print('📡 API 응답 상태 코드: ${response.statusCode}');
      print('📡 API 응답 헤더: ${response.headers}');
      print('📡 API 응답 바디: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final uploads = List<Map<String, dynamic>>.from(data['uploads']);
          print('✅ 사용자 업로드 파일 목록 조회 성공: ${uploads.length}개 파일');
          
          // 각 파일 정보 로그
          for (var upload in uploads) {
            print('  📁 파일: ${upload['filename']}');
            print('     - 아티스트: ${upload['artist']}');
            print('     - 제목: ${upload['song_title']}');
            print('     - 타입: ${upload['type']}');
            print('     - 크기: ${upload['size']} bytes');
            print('     - S3 키: ${upload['key']}');
          }
          
          return uploads;
        } else {
          print('❌ 사용자 업로드 파일 목록 조회 실패: ${data['detail']}');
          print('❌ 응답 데이터: $data');
          return [];
        }
      } else {
        print('❌ 사용자 업로드 파일 목록 조회 실패: ${response.statusCode}');
        print('❌ 응답 바디: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ 사용자 업로드 파일 목록 조회 오류: $e');
      print('❌ 오류 타입: ${e.runtimeType}');
      return [];
    }
  }

  /// 사용자가 업로드한 파일을 삭제합니다.
  static Future<bool> deleteUserUpload(String userId, String filename) async {
    try {
      print('🗑️ 사용자 업로드 파일 삭제 시작: $userId/$filename');

      final backendUrl = await ApiConfigService.baseUrl;
      final response = await http
          .delete(Uri.parse('$backendUrl/api/user-uploads/$userId/$filename'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ 사용자 업로드 파일 삭제 성공: ${data['message']}');
        return true;
      } else {
        print('❌ 사용자 업로드 파일 삭제 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ 사용자 업로드 파일 삭제 오류: $e');
      return false;
    }
  }

  static Future<String?> getPresignedUrlForRead({
    required String bucket,
    required String s3Key,
  }) async {
    final String backendUrl = await ApiConfigService.baseUrl;
    final response = await http.post(
      Uri.parse('$backendUrl/s3/presigned-url'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'bucket': bucket,
        's3_key': s3Key,
        'operation': 'get_object',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['presigned_url'];
    } else {
      print('❌ Presigned URL 요청 실패: ${response.statusCode}');
      return null;
    }
  }
}

/// 업로드할 파일 타입 열거형
enum FileType {
  original, // 원곡 파일
  inst, // 인스트 파일
  albumCover, // 앨범 커버
  midi, // MIDI 파일
  userRecording, // 사용자 녹음 파일
}
