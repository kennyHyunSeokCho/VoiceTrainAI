import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/song.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../services/s3_service.dart';

class AiVocalReadyPage extends StatefulWidget {
  @override
  _AiVocalReadyPageState createState() => _AiVocalReadyPageState();
}

class _AiVocalReadyPageState extends State<AiVocalReadyPage> {
  String? _albumCoverUrl;
  bool _isLoadingCover = true;

  @override
  void initState() {
    super.initState();
    _loadAlbumCover();
  }

  Future<void> _loadAlbumCover() async {
    try {
      final song = ModalRoute.of(context)!.settings.arguments as Song;
      
      // Song 객체의 albumCover 필드가 이미 S3 URL인지 확인
      if (song.albumCover.isNotEmpty && song.albumCover.startsWith('http')) {
        print('Song 객체에서 앨범커버 URL 사용: ${song.albumCover}');
        if (mounted) {
          setState(() {
            _albumCoverUrl = song.albumCover;
            _isLoadingCover = false;
          });
        }
      } else {
        // 기존 방식으로 URL 생성
        final coverUrl = await _fetchAlbumCoverUrl(song.artist, song.title);
        
        if (mounted) {
          setState(() {
            _albumCoverUrl = coverUrl;
            _isLoadingCover = false;
          });
        }
      }
    } catch (e) {
      print('앨범 커버 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoadingCover = false;
        });
      }
    }
  }

  Future<String> _fetchAlbumCoverUrl(String artist, String title) async {
    try {
      // S3Service를 사용하여 앨범 커버 URL 생성
      String albumCoverUrl = S3Service.getAlbumCoverUrl(artist, title);
      print('앨범커버 S3 URL 생성: $albumCoverUrl');
      
      // URL 유효성 검사
      try {
        final response = await http.head(Uri.parse(albumCoverUrl));
        print('앨범커버 S3 응답 코드: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          print('앨범커버 S3 성공: $albumCoverUrl');
          return albumCoverUrl;
        }
      } catch (e) {
        print('앨범커버 S3 요청 실패: $e');
      }
      
      print('앨범커버 로드 실패, 기본 이미지 사용');
      return 'https://via.placeholder.com/150x150?text=앨범커버';
    } catch (e) {
      print('앨범커버 URL 생성 실패: $e');
      return 'https://via.placeholder.com/150x150?text=앨범커버';
    }
  }

  Widget _buildAlbumCoverWidget() {
    final song = ModalRoute.of(context)!.settings.arguments as Song;
    
    print('=== _buildAlbumCoverWidget 디버깅 (Ready) ===');
    print('Song 객체 정보:');
    print('  - title: ${song.title}');
    print('  - artist: ${song.artist}');
    print('  - albumCover: "${song.albumCover}"');
    print('  - albumCover.isEmpty: ${song.albumCover.isEmpty}');
    print('  - albumCover.startsWith("http"): ${song.albumCover.startsWith('http')}');
    
    // Song 객체의 albumCover가 있으면 사용
    if (song.albumCover.isNotEmpty && song.albumCover.startsWith('http')) {
      print('✅ Song 객체에서 앨범커버 URL 사용: ${song.albumCover}');
      return CachedNetworkImage(
        imageUrl: song.albumCover,
        width: 160,
        height: 160,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 160,
          height: 160,
          color: Colors.grey[200],
          child: Center(
            child: CircularProgressIndicator(
              color: Colors.green,
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          print('❌ 앨범커버 로드 실패: $error');
          return Container(
            width: 160,
            height: 160,
            color: Colors.grey[200],
            child: Icon(
              Icons.music_note,
              size: 60,
              color: Colors.grey[400],
            ),
          );
        },
      );
    }
    
    print('❌ Song 객체에 URL이 없음');
    
    // Song 객체에 URL이 없으면 로딩 상태 표시
    if (_isLoadingCover) {
      return Container(
        width: 160,
        height: 160,
        color: Colors.grey[200],
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.green,
          ),
        ),
      );
    }
    
    // 생성된 URL이 있으면 사용
    if (_albumCoverUrl != null) {
      return CachedNetworkImage(
        imageUrl: _albumCoverUrl!,
        width: 160,
        height: 160,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 160,
          height: 160,
          color: Colors.grey[200],
          child: Center(
            child: CircularProgressIndicator(
              color: Colors.green,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 160,
          height: 160,
          color: Colors.grey[200],
          child: Icon(
            Icons.music_note,
            size: 60,
            color: Colors.grey[400],
          ),
        ),
      );
    }
    
    // 기본 아이콘 표시
    return Container(
      width: 160,
      height: 160,
      color: Colors.grey[200],
      child: Icon(
        Icons.music_note,
        size: 60,
        color: Colors.grey[400],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Song song = ModalRoute.of(context)!.settings.arguments as Song;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 배경 SVG 요소들
          Positioned(
            top: 80,
            left: -30,
            child: SvgPicture.asset(
              'assets/images/path4.svg',
              width: 100,
              height: 100,
              color: Colors.green.withOpacity(0.1),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -20,
            child: SvgPicture.asset(
              'assets/images/path5copy.svg',
              width: 80,
              height: 80,
              color: Colors.green.withOpacity(0.08),
            ),
          ),
          // 메인 콘텐츠
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 앨범커버 + 완료 효과
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 배경 원형 효과
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      // 앨범커버 이미지
                      ClipRRect(
                        borderRadius: BorderRadius.circular(80),
                        child: _buildAlbumCoverWidget(),
                      ),
                      // 완료 체크마크
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                // 제목과 부제목
                Text(
                  'AI Vocal 합성 완료!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '${song.title} - ${song.artist}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 32),
                // 완료된 진행바
                Container(
                  width: 280,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green, Colors.greenAccent],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '100% 완료',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 40),
                // 하단 장식 요소
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/images/path2copy2.svg',
                      width: 20,
                      height: 20,
                      color: Colors.green.withOpacity(0.6),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AI 보컬이 성공적으로 생성되었습니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    SizedBox(width: 8),
                    SvgPicture.asset(
                      'assets/images/path2.svg',
                      width: 20,
                      height: 20,
                      color: Colors.green.withOpacity(0.6),
                    ),
                  ],
                ),
                SizedBox(height: 40),
                // "들어보기" 버튼
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/ai-vocal-play', arguments: song);
                  },
                  icon: Icon(Icons.play_arrow, size: 24),
                  label: Text('들어보기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
