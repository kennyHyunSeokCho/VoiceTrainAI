
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import '../models/song.dart';

class S3Service {
  Future<List<Song>> getSongsFromS3() async {
    try {
      // 1. S3 버킷의 파일 목록을 가져옵니다.
      final result = await Amplify.Storage.list();

      // 2. 각 파일의 공개 URL을 가져오고, 파일 이름에서 메타데이터를 파싱합니다.
      final songFutures = result.items.map((file) async {
        // 파일의 공개 URL 가져오기
        final urlResult = await Amplify.Storage.getUrl(key: file.key);

        // 파일 이름 파싱: '(아티스트)-제목.jpg' 형식 기준
        String artist = 'Unknown Artist';
        String title = 'Unknown Title';

        // .jpg 확장자 제거
        final filename = file.key.split('/').last.replaceAll('.jpg', '').replaceAll('.png', ''); // 다른 확장자도 고려

        final parts = filename.split(')-');
        if (parts.length >= 2) {
          // 아티스트: 첫 부분의 '(' 제거
          artist = parts[0].substring(1);
          // 제목: 두 번째 부분의 '_'를 공백으로 변경
          title = parts[1].split('_(')[0].replaceAll('_', ' ');
        }

        return Song(
          title: title,
          artist: artist,
          albumCover: urlResult.url, // S3의 공개 URL
          difficulty: '중급', // 기본값
          range: 'N/A', // 기본값
          lyrics: '가사를 불러오는 중...', // 기본값
          duration: '0:00', // 기본값
        );
      }).toList();

      // 3. 모든 비동기 작업이 완료될 때까지 기다린 후 리스트를 반환합니다.
      return await Future.wait(songFutures);

    } on StorageException catch (e) {
      safePrint('S3에서 노래 목록을 가져오는 중 오류 발생: ${e.message}');
      return []; // 오류 발생 시 빈 리스트 반환
    } catch (e) {
      safePrint('알 수 없는 오류: $e');
      return [];
    }
  }
}
