import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/s3_service.dart';
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

    // 각 플레이어 초기화
    _initPlayer(
      _userPlayer,
      (duration) {
        setState(() => _userDuration = duration);
      },
      (position) {
        setState(() => _userPosition = position);
      },
      (playing) {
        setState(() => _userPlaying = playing);
      },
    );

    _initPlayer(
      _singerPlayer,
      (duration) {
        setState(() => _singerDuration = duration);
      },
      (position) {
        setState(() => _singerPosition = position);
      },
      (playing) {
        setState(() => _singerPlaying = playing);
      },
    );

    _initPlayer(
      _aiPlayer,
      (duration) {
        setState(() => _aiDuration = duration);
      },
      (position) {
        setState(() => _aiPosition = position);
      },
      (playing) {
        setState(() => _aiPlaying = playing);
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

    // 원곡 파일 URL 설정 (S3에서 가져오기)
    singerVocalUrl = S3Service.getOriginalSongUrl(
      widget.artist,
      widget.songTitle,
    );
    print('🎵 원곡 파일 URL: $singerVocalUrl');

    // URL 인코딩 확인
    if (singerVocalUrl != null) {
      try {
        Uri.parse(singerVocalUrl!);
        print('✅ 원곡 URL 인코딩 확인 완료');
      } catch (e) {
        print('❌ 원곡 URL 인코딩 오류: $e');
        singerVocalUrl = Uri.encodeFull(singerVocalUrl!);
        print('🔧 인코딩된 원곡 URL: $singerVocalUrl');
      }
    }

    // AI 변환 보컬은 더미 URL로 설정 (나중에 실제 AI 보컬로 교체)
    aiVocalUrl =
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3';

    // 로딩 상태 업데이트
    if (mounted) {
      setState(() {
        loading = false;
      });
    }
    print('✅ 보컬 비교 페이지 초기화 완료');
    // _fetchVocalUrls(); // 주석 처리
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
            const SizedBox(height: 12),
            // 진행 바
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF8B5CF6),
                inactiveTrackColor: Colors.grey[300],
                thumbColor: const Color(0xFF8B5CF6),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: position.inSeconds.toDouble(),
                min: 0,
                max: duration.inSeconds.toDouble() > 0
                    ? duration.inSeconds.toDouble()
                    : 1,
                onChanged: (v) {
                  player.seek(Duration(seconds: v.toInt()));
                },
              ),
            ),
            // 시간 표시
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(position),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatTime(duration),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 컨트롤 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 재생/일시정지 버튼
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () async {
                      if (isPlaying) {
                        await player.pause();
                      } else {
                        try {
                          // 다른 플레이어들 중지
                          await _userPlayer.pause();
                          await _singerPlayer.pause();
                          await _aiPlayer.pause();

                          // 현재 플레이어 재생
                          await player.setSourceUrl(url);
                          await player.resume();
                        } catch (e) {
                          print('❌ 오디오 재생 실패: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('오디오 파일을 재생할 수 없습니다: $e'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // 정지 버튼
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.stop, color: Colors.grey, size: 24),
                    onPressed: () async {
                      await player.stop();
                    },
                  ),
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
