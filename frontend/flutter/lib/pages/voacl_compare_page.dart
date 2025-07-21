import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VocalComparePage extends StatefulWidget {
  final String userId;
  final String songTitle;
  final String artist;

  const VocalComparePage({
    required this.userId,
    required this.songTitle,
    required this.artist,
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
    _fetchVocalUrls();
  }

  Future<void> _fetchVocalUrls() async {
    setState(() => loading = true);
    try {
      // 실제 API 엔드포인트에 맞게 URL을 수정하세요!
      final userRes = await http.get(
        Uri.parse(
          'http://localhost:8000/api/s3/user_vocal?user_id=${Uri.encodeComponent(widget.userId)}&song=${Uri.encodeComponent(widget.songTitle)}',
        ),
      );
      final singerRes = await http.get(
        Uri.parse(
          'http://localhost:8000/api/s3/singer_vocal?artist=${Uri.encodeComponent(widget.artist)}&title=${Uri.encodeComponent(widget.songTitle)}',
        ),
      );
      final aiRes = await http.get(
        Uri.parse(
          'http://localhost:8000/api/s3/ai_vocal?user_id=${Uri.encodeComponent(widget.userId)}&song=${Uri.encodeComponent(widget.songTitle)}',
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
    );
  }
}
