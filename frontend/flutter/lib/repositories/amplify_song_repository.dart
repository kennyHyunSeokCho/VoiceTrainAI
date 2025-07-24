
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import '../models/song.dart';
import 'song_repository.dart';

// SongRepository 계약을 "Amplify S3" 방식으로 이행하는 구현체
class AmplifySongRepository implements SongRepository {
  @override
  Future<List<Song>> getSongs() async {
    try {
      final result = await Amplify.Storage.list();
      final songFutures = result.items.map((file) async {
        final urlResult = await Amplify.Storage.getUrl(key: file.key);
        final filename = file.key.split('/').last.replaceAll('.jpg', '');
        final parts = filename.split(')-');
        final artist = parts.length > 1 ? parts[0].substring(1) : 'Unknown Artist';
        final title = parts.length > 1 ? parts[1].split('_(')[0].replaceAll('_', ' ') : 'Unknown Title';

        return Song(
          title: title,
          artist: artist,
          albumCover: urlResult.url,
          difficulty: '중급', 
          range: 'N/A', 
          lyrics: '...', 
          duration: '0:00',
        );
      }).toList();

      return await Future.wait(songFutures);
    } on StorageException catch (e) {
      safePrint('AmplifySongRepository Error: ${e.message}');
      return [];
    }
  }
}
