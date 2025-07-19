
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import '../models/song.dart';

class S3Service {
  // 기존 getSongsFromS3 메서드는 일시적으로 주석 처리
  // Amplify Storage API 호환성 문제로 인해 나중에 수정 예정
  /*
  Future<List<Song>> getSongsFromS3() async {
    // 기존 코드는 나중에 수정
    return [];
  }
  */

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

  /// 파일명에서 사용할 수 없는 특수문자를 제거하고 공백을 언더스코어로 변경합니다.
  static String _cleanFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[^\w\s가-힣]'), '') // 특수문자 제거 (한글, 영문, 숫자, 공백만 허용)
        .replaceAll(RegExp(r'\s+'), '_') // 공백을 언더스코어로 변경
        .trim();
  }
}
