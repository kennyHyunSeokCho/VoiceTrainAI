import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../services/s3_service.dart';

class UserRecordingPlayPage extends StatefulWidget {
  final String songTitle;
  final String artist;
  final String audioUrl;
  final String albumCoverUrl;

  const UserRecordingPlayPage({
    super.key,
    required this.songTitle,
    required this.artist,
    required this.audioUrl,
    required this.albumCoverUrl,
  });

  @override
  State<UserRecordingPlayPage> createState() => _UserRecordingPlayPageState();
}

class _UserRecordingPlayPageState extends State<UserRecordingPlayPage>
    with TickerProviderStateMixin {
  AudioPlayer? _audioPlayer;
  StreamSubscription<PlayerState>? _audioPlayerSubscription;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _albumCoverUrl;
  String? _presignedAudioUrl;

  // 애니메이션 컨트롤러
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 초기화
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _audioPlayer = AudioPlayer();
    _audioPlayerSubscription = _audioPlayer!.onPlayerStateChanged.listen((
      state,
    ) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });

        // 재생 상태에 따라 애니메이션 제어
        if (state == PlayerState.playing) {
          _rotationController.repeat();
          _pulseController.repeat(reverse: true);
        } else {
          _rotationController.stop();
          _pulseController.stop();
        }
      }
    });

    _audioPlayer!.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer!.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _loadPresignedUrl();
    _loadAlbumCover();
  }

  @override
  void dispose() {
    _audioPlayerSubscription?.cancel();
    _audioPlayer?.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadPresignedUrl() async {
    try {
      // S3 URL에서 파일명 추출
      // 예: https://ai-vocal-training-user.s3.ap-northeast-2.amazonaws.com/테스트사용자/vocal/테스트사용자_오늘만_I_LOVE_YOU_record.wav
      final uri = Uri.parse(widget.audioUrl);
      final pathParts = uri.path.split('/');
      final filename = pathParts.last;
      final userId = pathParts[pathParts.length - 3]; // vocal 폴더의 상위 폴더가 사용자 ID

      print('🎵 파일 정보 추출:');
      print('  - 사용자 ID: $userId');
      print('  - 파일명: $filename');

      // Presigned URL 가져오기
      final presignedUrl = await S3Service.getAudioPresignedUrl(
        userId,
        filename,
      );
      if (presignedUrl != null) {
        setState(() {
          _presignedAudioUrl = presignedUrl;
        });
        _loadAudio();
      } else {
        throw Exception('Presigned URL을 가져올 수 없습니다');
      }
    } catch (e) {
      print('❌ Presigned URL 로드 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오디오 파일을 로드할 수 없습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAudio() async {
    if (_presignedAudioUrl == null) {
      print('❌ Presigned URL이 없습니다');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🎵 오디오 로드 시작: $_presignedAudioUrl');

      // 오디오 플레이어 설정
      await _audioPlayer!.setSourceUrl(_presignedAudioUrl!);

      // 오디오 로드 완료 대기
      await Future.delayed(Duration(milliseconds: 500));

      print('✅ 오디오 로드 성공');
    } catch (e) {
      print('❌ 오디오 로드 실패: $e');

      // 오류 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '오디오 파일을 로드할 수 없습니다.\n파일이 손상되었거나 지원되지 않는 형식일 수 있습니다.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: '다시 시도',
              textColor: Colors.white,
              onPressed: () => _loadPresignedUrl(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAlbumCover() async {
    try {
      final albumCoverUrl = await S3Service.getAlbumCoverUrlByTitle(
        widget.songTitle,
      );
      if (mounted && albumCoverUrl != null) {
        setState(() {
          _albumCoverUrl = albumCoverUrl;
        });
      }
    } catch (e) {
      print('❌ 앨범 커버 로드 실패: $e');
    }
  }

  Future<void> _playPause() async {
    if (_isPlaying) {
      await _audioPlayer!.pause();
    } else {
      await _audioPlayer!.resume();
    }
  }

  Future<void> _stop() async {
    await _audioPlayer!.stop();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade50,
              Colors.white,
              Colors.purple.shade50,
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 상단 앱바
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.purple,
                        size: 24,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '내 녹음',
                            style: TextStyle(
                              color: Colors.purple.shade800,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Cover Song',
                            style: TextStyle(
                              color: Colors.purple.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.purple,
                        size: 24,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              // 메인 콘텐츠
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),

                      // 앨범 커버 섹션
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        height: MediaQuery.of(context).size.width * 0.6,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.2),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                                spreadRadius: 5,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: _albumCoverUrl != null
                                ? Image.network(
                                    _albumCoverUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildDefaultAlbumCover();
                                    },
                                  )
                                : _buildDefaultAlbumCover(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 35),

                      // 노래 정보 섹션
                      Column(
                        children: [
                          Text(
                            widget.songTitle,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade800,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '내 녹음',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.purple.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 35),

                      // 재생 시간 표시
                      if (_duration > Duration.zero)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_position),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatDuration(_duration),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),

                      // 진행 바
                      if (_duration > Duration.zero)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.purple.shade400,
                              inactiveTrackColor: Colors.purple.shade100,
                              thumbColor: Colors.purple.shade600,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 10,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 20,
                              ),
                              trackHeight: 6,
                            ),
                            child: Slider(
                              value: _position.inMilliseconds.toDouble(),
                              min: 0,
                              max: _duration.inMilliseconds.toDouble(),
                              onChanged: (value) {
                                _audioPlayer!.seek(
                                  Duration(milliseconds: value.toInt()),
                                );
                              },
                            ),
                          ),
                        ),

                      const SizedBox(height: 40),

                      // 재생 컨트롤
                      Center(
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors:
                                        _isLoading || _duration == Duration.zero
                                        ? [
                                            Colors.grey.shade300,
                                            Colors.grey.shade400,
                                          ]
                                        : [
                                            Colors.purple.shade400,
                                            Colors.purple.shade600,
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(40),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (_isLoading ||
                                                      _duration == Duration.zero
                                                  ? Colors.grey
                                                  : Colors.purple.shade600)
                                              .withOpacity(0.4),
                                      blurRadius: 25,
                                      offset: const Offset(0, 10),
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed:
                                      (_isLoading || _duration == Duration.zero)
                                      ? null
                                      : _playPause,
                                  icon: Icon(
                                    _isLoading
                                        ? Icons.hourglass_empty
                                        : _duration == Duration.zero
                                        ? Icons.error
                                        : _isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    size: 50,
                                    color:
                                        _isLoading || _duration == Duration.zero
                                        ? Colors.grey.shade500
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 30),

                      // 추가 정보 카드 (컴팩트 버전)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.1),
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple.shade400,
                                    Colors.purple.shade600,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.mic,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '내 녹음 파일',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade800,
                                    ),
                                  ),
                                  Text(
                                    '녹음 날짜: ${DateTime.now().toString().split(' ')[0]}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.purple.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAlbumCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade100, Colors.purple.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.music_note, size: 100, color: Colors.purple.shade400),
    );
  }
}
