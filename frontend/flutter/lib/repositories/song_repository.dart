
import '../models/song.dart';

// 데이터 통신에 대한 "계약서"
abstract class SongRepository {
  // 노래 목록을 가져오는 기능이 반드시 있어야 한다.
  Future<List<Song>> getSongs();

  // (선택) 특정 노래의 상세 정보를 가져오는 기능
  // Future<Song> getSongDetails(String songId);

  // (선택) 녹음 파일을 업로드하는 기능
  // Future<String> uploadRecording(File audioFile);
}
