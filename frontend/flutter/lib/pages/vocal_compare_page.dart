import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_config_service.dart';

class VocalComparePage extends StatefulWidget {
  final String userId;
  final String songTitle;
  final String artist;
  final String? recordingPath; // 녹음 파일 경로 추가

  const VocalComparePage({
    required this.userId,
    required this.songTitle,
    required this.artist,
    this.recordingPath, // 선택적 매개변수로 추가
    Key? key,
  }) : super(key: key);

  @override
  State<VocalComparePage> createState() => _VocalComparePageState();
}

class _VocalComparePageState extends State<VocalComparePage> {
  String? userVocalUrl;
  String? singerVocalUrl;
  String? aiVocalUrl;
  bool loading = true;

  late AudioPlayer _userPlayer;
  late AudioPlayer _singerPlayer;
  late AudioPlayer _aiPlayer;

  Duration _userDuration = Duration.zero;
  Duration _userPosition = Duration.zero;
  bool _userPlaying = false;

  Duration _singerDuration = Duration.zero;
  Duration _singerPosition = Duration.zero;
  bool _singerPlaying = false;

  Duration _aiDuration = Duration.zero;
  Duration _aiPosition = Duration.zero;
  bool _aiPlaying = false;

  @override
  void initState() {
    super.initState();
    _userPlayer = AudioPlayer();
    _singerPlayer = AudioPlayer();
    _aiPlayer = AudioPlayer();

    // 비동기 초기화 시작
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    print('🔄 보컬 비교 페이지 초기화 시작...');
    
    try {
      // 1. 사용자 보컬 설정
      if (widget.recordingPath != null) {
        print('📁 녹음 파일 경로 확인: ${widget.recordingPath}');
        if (widget.recordingPath!.startsWith('http')) {
          // S3 URL인 경우 presigned URL 생성
          userVocalUrl = await _getPresignedUrlForUserVocal(widget.recordingPath!);
          print('☁️ S3 녹음 파일 URL: $userVocalUrl');
        } else {
          // 로컬 파일인 경우
          userVocalUrl = 'file://${widget.recordingPath}';
          print('📁 로컬 녹음 파일 경로: ${widget.recordingPath}');
        }
      } else {
        userVocalUrl = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
        print('⚠️ 녹음 파일이 없어서 더미 파일을 사용합니다.');
      }

      // 2. 원곡 설정
      singerVocalUrl = await _getOriginalSongUrl();
      print('🎵 원곡 URL: $singerVocalUrl');

      // 3. AI 보컬은 더미 URL 사용 (나중에 실제 구현)
      aiVocalUrl = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3';
      print('🤖 AI 보컬 URL: $aiVocalUrl');

      if (mounted) {
        setState(() {
          loading = false;
        });
      }
      print('✅ 보컬 비교 페이지 초기화 완료');
    } catch (e) {
      print('❌ 보컬 비교 페이지 초기화 실패: $e');
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  /// 사용자 보컬 파일의 presigned URL을 생성합니다.
  Future<String?> _getPresignedUrlForUserVocal(String recordingPath) async {
    try {
      if (recordingPath.contains('ai-vocal-training-user.s3.ap-northeast-2.amazonaws.com/')) {
        final uri = Uri.parse(recordingPath);
        final pathSegments = uri.pathSegments;
        if (pathSegments.length >= 3) {
          final userId = pathSegments[0];
          final fileName = pathSegments[2];
          final s3Key = '$userId/vocal/$fileName';
          print('🔍 사용자 녹음 파일 S3 키: $s3Key');
          
          return await _getPresignedUrlForRead(
            bucket: 'ai-vocal-training-user',
            s3Key: s3Key,
          );
        }
      }
      return recordingPath;
    } catch (e) {
      print('❌ 사용자 녹음 파일 URL 생성 실패: $e');
      return recordingPath;
    }
  }

  /// 원곡 파일의 presigned URL을 생성합니다.
  Future<String?> _getOriginalSongUrl() async {
    try {
      // 파일명에서 특수문자 제거 및 공백을 언더스코어로 변경
      String safeArtist = widget.artist
          .replaceAll(RegExp(r'[^\w\s가-힣]'), '')
          .replaceAll(' ', '_');
      String safeTitle = widget.songTitle
          .replaceAll(RegExp(r'[^\w\s가-힣]'), '')
          .replaceAll(' ', '_');

      // S3 키 생성: MusicFile/가수명/original/가수명_노래제목.wav
      final s3Key = 'MusicFile/$safeArtist/original/${safeArtist}_$safeTitle.wav';
      print('🎵 원곡 S3 키: $s3Key');

      final presignedUrl = await _getPresignedUrlForRead(
        bucket: 'ai-vocal-training',
        s3Key: s3Key,
      );

      if (presignedUrl != null) {
        print('✅ 원곡 Presigned URL 생성 성공: $presignedUrl');
        return presignedUrl;
      } else {
        print('⚠️ 원곡 Presigned URL 생성 실패, 직접 S3 접근 시도');
        return 'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/$s3Key';
      }
    } catch (e) {
      print('❌ 원곡 URL 생성 실패: $e');
      return 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3';
    }
  }

  /// S3 읽기를 위한 presigned URL을 생성합니다.
  Future<String?> _getPresignedUrlForRead({
    required String bucket,
    required String s3Key,
  }) async {
    try {
      final String backendUrl = ApiConfigService.baseUrl;
      print('🌐 Presigned URL 요청: $backendUrl/s3/presigned-url');
      print('📦 버킷: $bucket, S3 키: $s3Key');

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
        print('❌ Presigned URL 생성 실패: ${response.statusCode}');
        print('응답: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Presigned URL 생성 중 오류: $e');
      return null;
    }
  }

  Future<void> _fetchVocalUrls() async {
    setState(() => loading = true);
    try {
      // 실제 API 엔드포인트에 맞게 URL을 수정하세요!
      final userRes = await http.get(
        Uri.parse(
          '${ApiConfigService.baseUrl}/api/s3/user_vocal?user_id=${Uri.encodeComponent(widget.userId)}&song=${Uri.encodeComponent(widget.songTitle)}',
        ),
      );
      final singerRes = await http.get(
        Uri.parse(
          '${ApiConfigService.baseUrl}/api/s3/singer_vocal?artist=${Uri.encodeComponent(widget.artist)}&title=${Uri.encodeComponent(widget.songTitle)}',
        ),
      );
      final aiRes = await http.get(
        Uri.parse(
          '${ApiConfigService.baseUrl}/api/s3/ai_vocal?user_id=${Uri.encodeComponent(widget.userId)}&song=${Uri.encodeComponent(widget.songTitle)}',
        ),
      );

      setState(() {
        userVocalUrl = json.decode(userRes.body)['url'];
        singerVocalUrl = json.decode(singerRes.body)['url'];
        aiVocalUrl = json.decode(aiRes.body)['url'];
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      // 에러 처리
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('보컬 파일을 불러오지 못했습니다: $e')));
    }
  }

  void _initPlayer(
    AudioPlayer player,
    Function(Duration) onDuration,
    Function(Duration) onPosition,
    Function(bool) onPlaying,
  ) {
    player.onDurationChanged.listen(onDuration);
    player.onPositionChanged.listen(onPosition);
    player.onPlayerStateChanged.listen(
      (state) => onPlaying(state == PlayerState.playing),
    );
  }

  @override
  void dispose() {
    _userPlayer.dispose();
    _singerPlayer.dispose();
    _aiPlayer.dispose();
    super.dispose();
  }

  Widget _buildAudioPlayer({
    required String label,
    required AudioPlayer player,
    required String url,
    required Duration duration,
    required Duration position,
    required bool isPlaying,
  }) {
    // 녹음 파일 여부 확인
    final bool isUserRecording =
        label == "사용자 보컬" && widget.recordingPath != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (isUserRecording) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '실제 녹음',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Slider(
              value: position.inSeconds.toDouble(),
              min: 0,
              max: duration.inSeconds.toDouble() > 0
                  ? duration.inSeconds.toDouble()
                  : 1,
              onChanged: (v) {
                player.seek(Duration(seconds: v.toInt()));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatTime(position)),
                Text(_formatTime(duration)),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: () async {
                    if (isPlaying) {
                      await player.pause();
                    } else {
                      await player.setSourceUrl(url);
                      await player.resume();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: () async {
                    await player.stop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds % 60)}";
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (userVocalUrl == null || singerVocalUrl == null || aiVocalUrl == null) {
      return Scaffold(body: Center(child: Text('보컬 파일을 불러올 수 없습니다.')));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.songTitle} - ${widget.artist} 보컬 비교'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          const SizedBox(height: 16),
          _buildAudioPlayer(
            label: "사용자 보컬",
            player: _userPlayer,
            url: userVocalUrl!,
            duration: _userDuration,
            position: _userPosition,
            isPlaying: _userPlaying,
          ),
          _buildAudioPlayer(
            label: "가수 원본 보컬",
            player: _singerPlayer,
            url: singerVocalUrl!,
            duration: _singerDuration,
            position: _singerPosition,
            isPlaying: _singerPlaying,
          ),
          _buildAudioPlayer(
            label: "AI 변환 보컬",
            player: _aiPlayer,
            url: aiVocalUrl!,
            duration: _aiDuration,
            position: _aiPosition,
            isPlaying: _aiPlaying,
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/main', (route) => false);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8B5CF6),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              '홈으로 돌아가기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
