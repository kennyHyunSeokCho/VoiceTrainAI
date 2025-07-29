import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config_service.dart'; // ApiConfigService 추가
import '../services/s3_service.dart'; // S3Service 추가

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

    // 오디오 플레이어 이벤트 리스너 설정
    _initPlayer(
      _userPlayer,
      (duration) {
        if (mounted) setState(() => _userDuration = duration);
      },
      (position) {
        if (mounted) setState(() => _userPosition = position);
      },
      (playing) {
        if (mounted) setState(() => _userPlaying = playing);
      },
    );

    _initPlayer(
      _singerPlayer,
      (duration) {
        if (mounted) setState(() => _singerDuration = duration);
      },
      (position) {
        if (mounted) setState(() => _singerPosition = position);
      },
      (playing) {
        if (mounted) setState(() => _singerPlaying = playing);
      },
    );

    _initPlayer(
      _aiPlayer,
      (duration) {
        if (mounted) setState(() => _aiDuration = duration);
      },
      (position) {
        if (mounted) setState(() => _aiPosition = position);
      },
      (playing) {
        if (mounted) setState(() => _aiPlaying = playing);
      },
    );

    // 녹음 파일이 있으면 S3 URL 또는 로컬 파일 사용, 없으면 더미 URL 사용
    if (widget.recordingPath != null) {
      if (widget.recordingPath!.startsWith('http')) {
        // S3 URL인 경우
        userVocalUrl = widget.recordingPath!;
        print('☁️ S3 녹음 파일 URL: ${widget.recordingPath}');
      } else {
        // 로컬 파일인 경우
        userVocalUrl = 'file://${widget.recordingPath}';
        print('📁 로컬 녹음 파일 경로: ${widget.recordingPath}');
      }
    } else {
      userVocalUrl =
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
      print('⚠️ 녹음 파일이 없어서 더미 파일을 사용합니다.');
    }

    // 원곡과 AI 보컬 URL 설정
    _loadVocalUrls();
  }

  Future<void> _loadVocalUrls() async {
    setState(() => loading = true);
    try {
      // 원곡 URL 설정 (노래 상세 페이지와 동일한 방식)
      singerVocalUrl = S3Service.getOriginalSongUrl(
        widget.artist,
        widget.songTitle,
      );
      print('🎵 원곡 URL 설정: $singerVocalUrl');

      // AI 합성 파일 presigned URL 가져오기
      print('🔍 AI 합성 파일 presigned URL 요청 중...');
      print('   - 사용자 ID: ${widget.userId}');
      print('   - 노래 제목: ${widget.songTitle}');

      final presignedUrl = await S3Service.getAiVocalPresignedUrl(
        widget.userId,
        widget.songTitle,
      );

      if (presignedUrl != null) {
        aiVocalUrl = presignedUrl;
        print('✅ AI 합성 파일 presigned URL 성공: $aiVocalUrl');
      } else {
        print('⚠️ AI 합성 파일 presigned URL 실패. 더미 파일을 사용합니다.');
        aiVocalUrl =
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3';
      }

      setState(() {
        loading = false;
      });
    } catch (e) {
      print('❌ 보컬 URL 로드 중 오류: $e');
      // 오류 시 더미 URL 사용
      singerVocalUrl =
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3';
      aiVocalUrl =
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3';
      setState(() => loading = false);
    }
  }

  /// 파일명에서 특수문자를 제거하고 안전한 파일명으로 변환합니다.
  String _cleanFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[^\w\s-]'), '') // 특수문자 제거
        .replaceAll(RegExp(r'\s+'), '_') // 공백을 언더스코어로 변경
        .toLowerCase(); // 소문자로 변환
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
                try {
                  player.seek(Duration(seconds: v.toInt()));
                } catch (e) {
                  print('❌ 오디오 시크 오류: $e');
                }
              },
              onChangeEnd: (v) {
                // 시크 완료 후 상태 업데이트
                setState(() {});
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
                    try {
                      if (isPlaying) {
                        await player.pause();
                      } else {
                        // 다른 플레이어들 중지
                        if (player != _userPlayer) await _userPlayer.stop();
                        if (player != _singerPlayer) await _singerPlayer.stop();
                        if (player != _aiPlayer) await _aiPlayer.stop();

                        // 현재 플레이어에 소스 설정 및 재생
                        await player.setSourceUrl(url);
                        await player.resume();
                      }
                    } catch (e) {
                      print('❌ 오디오 재생 오류: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('오디오 재생 중 오류가 발생했습니다: $e')),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: () async {
                    try {
                      await player.stop();
                    } catch (e) {
                      print('❌ 오디오 정지 오류: $e');
                    }
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
