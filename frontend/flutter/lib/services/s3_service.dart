import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../main.dart'; // CurrentUser 사용을 위해

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
  /// 업로드 위치: {사용자ID}/vocal/{파일명}
  static Future<String?> uploadUserVocalFile({
    required File file,
    required String fileName,
  }) async {
    try {
      // 현재 로그인된 사용자 ID 가져오기
      String? userId = CurrentUser.getUserNickname();
      if (userId == null) {
        print('❌ 로그인된 사용자 정보가 없습니다.');
        return null;
      }

      // 사용자 ID 정리 (특수문자 제거)
      String cleanUserId = _cleanFileName(userId);

      // S3 키 생성: {사용자ID}/vocal/{파일명}
      String s3Key = '$cleanUserId/vocal/$fileName';
      String bucket = 'ai-vocal-training-user';
      String contentType = 'audio/wav';

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

  /// 백엔드에서 presigned URL 요청
  static Future<String?> _getPresignedUrl(
    String bucket,
    String s3Key,
    String contentType,
  ) async {
    try {
      const String backendUrl = 'http://10.0.2.2:8000';

      final response = await http.post(
        Uri.parse('$backendUrl/upload/presigned-url'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bucket': bucket,
          's3_key': s3Key,
          'content_type': contentType,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['presigned_url'];
      } else {
        print('❌ Presigned URL 요청 실패: ${response.statusCode}');
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
      final fileBytes = await file.readAsBytes();

      final response = await http.put(
        Uri.parse(presignedUrl),
        headers: {'Content-Type': contentType},
        body: fileBytes,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Presigned URL 업로드 중 오류: $e');
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
  /// 경로: https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/MusicFile/가수명/original/가수명_노래제목.wav
  static String getOriginalSongUrl(String artist, String title) {
    // 파일명에서 특수문자 제거 및 공백 처리
    String cleanArtist = _cleanFileName(artist);
    String cleanTitle = _cleanFileName(title);

    return 'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/MusicFile/$cleanArtist/original/${cleanArtist}_$cleanTitle.wav';
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

  /// 파일명에서 사용할 수 없는 특수문자를 제거하고 공백을 언더스코어로 변경합니다.
  static String _cleanFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[^\w\s가-힣]'), '') // 특수문자 제거 (한글, 영문, 숫자, 공백만 허용)
        .replaceAll(RegExp(r'\s+'), '_') // 공백을 언더스코어로 변경
        .trim();
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
