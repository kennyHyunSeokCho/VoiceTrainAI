import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/song.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../services/s3_service.dart';
import '../services/api_config_service.dart'; // ApiConfigService 추가
import 'package:audioplayers/audioplayers.dart';

class AiVocalPlayPage extends StatefulWidget {
  @override
  _AiVocalPlayPageState createState() => _AiVocalPlayPageState();
}

class _AiVocalPlayPageState extends State<AiVocalPlayPage> {
  String? _albumCoverUrl;
  bool _isLoadingCover = true;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  String? _aiVocalUrl;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadAlbumCover();
    _loadAiVocalAudio();
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
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

  Future<void> _loadAiVocalAudio() async {
    try {
      final song = ModalRoute.of(context)!.settings.arguments as Song;

      setState(() {
        _isLoadingAudio = true;
      });

      print('🎵 AI 보컬 오디오 로드 시작: ${song.artist} - ${song.title}');

      // vocal_compare_page.dart와 동일한 방식으로 AI 보컬 presigned URL 가져오기
      // 사용자 ID는 "테스트사용자"로 고정 (실제로는 동적 사용자 ID를 사용해야 함)
      final aiVocalUrl = await S3Service.getAiVocalPresignedUrl(
        "테스트사용자", // 사용자 ID
        song.title, // 노래 제목
      );

      if (aiVocalUrl != null) {
        setState(() {
          _aiVocalUrl = aiVocalUrl;
          _isLoadingAudio = false;
        });

        // 오디오 플레이어 이벤트 리스너 설정
        _audioPlayer!.onPositionChanged.listen((position) {
          if (mounted) {
            setState(() {
              _position = position;
            });
          }
        });

        _audioPlayer!.onDurationChanged.listen((duration) {
          if (mounted) {
            setState(() {
              _duration = duration;
            });
          }
        });

        _audioPlayer!.onPlayerStateChanged.listen((state) {
          if (mounted) {
            setState(() {
              _isPlaying = state == PlayerState.playing;
            });
          }
        });

        print('✅ AI 보컬 오디오 로드 성공: $aiVocalUrl');
      } else {
        setState(() {
          _isLoadingAudio = false;
        });
        print('❌ AI 보컬 오디오 로드 실패');
      }
    } catch (e) {
      setState(() {
        _isLoadingAudio = false;
      });
      print('❌ AI 보컬 오디오 로드 오류: $e');
    }
  }

  Future<void> _togglePlayPause() async {
    if (_aiVocalUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI 보컬 파일을 찾을 수 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      if (_isPlaying) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.play(UrlSource(_aiVocalUrl!));
      }
    } catch (e) {
      print('재생 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('재생 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
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

    print('=== _buildAlbumCoverWidget 디버깅 (Play) ===');
    print('Song 객체 정보:');
    print('  - title: ${song.title}');
    print('  - artist: ${song.artist}');
    print('  - albumCover: "${song.albumCover}"');
    print('  - albumCover.isEmpty: ${song.albumCover.isEmpty}');
    print(
      '  - albumCover.startsWith("http"): ${song.albumCover.startsWith('http')}',
    );

    // Song 객체의 albumCover가 있으면 사용
    if (song.albumCover.isNotEmpty && song.albumCover.startsWith('http')) {
      print('✅ Song 객체에서 앨범커버 URL 사용: ${song.albumCover}');
      return CachedNetworkImage(
        imageUrl: song.albumCover,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 200,
          height: 200,
          color: Colors.grey[200],
          child: Center(
            child: CircularProgressIndicator(color: Colors.deepPurple),
          ),
        ),
        errorWidget: (context, url, error) {
          print('❌ 앨범커버 로드 실패: $error');
          return Container(
            width: 200,
            height: 200,
            color: Colors.grey[200],
            child: Icon(Icons.music_note, size: 80, color: Colors.grey[400]),
          );
        },
      );
    }

    print('❌ Song 객체에 URL이 없음');

    // Song 객체에 URL이 없으면 로딩 상태 표시
    if (_isLoadingCover) {
      return Container(
        width: 200,
        height: 200,
        color: Colors.grey[200],
        child: Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
      );
    }

    // 생성된 URL이 있으면 사용
    if (_albumCoverUrl != null) {
      return CachedNetworkImage(
        imageUrl: _albumCoverUrl!,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 200,
          height: 200,
          color: Colors.grey[200],
          child: Center(
            child: CircularProgressIndicator(color: Colors.deepPurple),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 200,
          height: 200,
          color: Colors.grey[200],
          child: Icon(Icons.music_note, size: 80, color: Colors.grey[400]),
        ),
      );
    }

    // 기본 아이콘 표시
    return Container(
      width: 200,
      height: 200,
      color: Colors.grey[200],
      child: Icon(Icons.music_note, size: 80, color: Colors.grey[400]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Song song = ModalRoute.of(context)!.settings.arguments as Song;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'AI Vocal 합성',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 배경 SVG 요소들
          Positioned(
            top: 100,
            right: -40,
            child: SvgPicture.asset(
              'assets/images/rectangle4.svg',
              width: 150,
              height: 150,
              color: Colors.deepPurple.withOpacity(0.05),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -30,
            child: SvgPicture.asset(
              'assets/images/rectangle7.svg',
              width: 100,
              height: 100,
              color: Colors.purple.withOpacity(0.03),
            ),
          ),
          // 메인 콘텐츠
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // 앨범커버 섹션
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 배경 원형 효과
                      Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(120),
                        ),
                      ),
                      // 앨범커버 이미지
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: _buildAlbumCoverWidget(),
                      ),
                      // 재생 중 표시
                      if (_isPlaying)
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.deepPurple.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.pause,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                // 곡 정보
                Text(
                  song.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${song.artist} - AI 보컬 Ver.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                // 난이도와 음역대
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        song.difficulty,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        song.range,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // AI 보컬 로딩 상태
                if (_isLoadingAudio)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.orange[700]!,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'AI 보컬 로딩 중...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_aiVocalUrl == null && !_isLoadingAudio)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: Colors.red[700],
                        ),
                        SizedBox(width: 8),
                        Text(
                          'AI 보컬 파일을 찾을 수 없습니다',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 32),
                // 재생바
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _duration.inMilliseconds > 0
                                  ? _position.inMilliseconds.toDouble()
                                  : 0.0,
                              min: 0.0,
                              max: _duration.inMilliseconds > 0
                                  ? _duration.inMilliseconds.toDouble()
                                  : 1.0,
                              onChanged: (value) {
                                final newPosition = Duration(
                                  milliseconds: value.toInt(),
                                );
                                _audioPlayer?.seek(newPosition);
                              },
                              activeColor: Colors.deepPurple,
                              inactiveColor: Colors.grey[300],
                              thumbColor: Colors.deepPurple,
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                // 플레이어 컨트롤
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(Icons.skip_previous, size: 32),
                      onPressed: () {},
                      color: Colors.grey[600],
                    ),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            blurRadius: 15,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 36,
                        ),
                        onPressed: _isLoadingAudio ? null : _togglePlayPause,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.skip_next, size: 32),
                      onPressed: () {},
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                SizedBox(height: 24),
                // 추가 액션 버튼들
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(Icons.favorite_border, size: 28),
                      onPressed: () {},
                      color: Colors.grey[600],
                    ),
                    IconButton(
                      icon: Icon(Icons.share, size: 28),
                      onPressed: () {},
                      color: Colors.grey[600],
                    ),
                    IconButton(
                      icon: Icon(Icons.download, size: 28),
                      onPressed: () {},
                      color: Colors.grey[600],
                    ),
                    IconButton(
                      icon: Icon(Icons.more_vert, size: 28),
                      onPressed: () {},
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                Spacer(),
                // 하단 장식
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/images/icon.svg',
                      width: 16,
                      height: 16,
                      color: Colors.deepPurple.withOpacity(0.6),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AI 보컬 합성 완료',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
