import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import '../models/song.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

final List<_LyricLine> exampleLyrics = [
  _LyricLine(text: '손 닿을 수 없는 저기 어딘가', time: 0),
  _LyricLine(text: '오늘도 난 숨 쉬고 있지만', time: 3),
  _LyricLine(text: '너와 머물던 작은 의자 위에', time: 6),
  _LyricLine(text: '같은 모습의 바람이 지나네', time: 9),
  _LyricLine(text: '너는 떠나며 마치 날 떠나가듯이', time: 12),
  _LyricLine(text: '손 닿을 수 없는 저기 어딘가2', time: 15),
  _LyricLine(text: '오늘도 난 숨 쉬고 있지만2', time: 20),
  _LyricLine(text: '너와 머물던 작은 의자 위에2', time: 25),
  _LyricLine(text: '같은 모습의 바람이 지나네2', time: 28),
  _LyricLine(text: '너는 떠나며 마치 날 떠나가듯이2', time: 31),
  _LyricLine(text: '손 닿을 수 없는 저기 어딘가3', time: 33),
  _LyricLine(text: '오늘도 난 숨 쉬고 있지만3', time: 36),
  _LyricLine(text: '너와 머물던 작은 의자 위에3', time: 39),
  _LyricLine(text: '같은 모습의 바람이 지나네3', time: 42),
  _LyricLine(text: '너는 떠나며 마치 날 떠나가듯이3', time: 45),
];

class RecordPage extends StatefulWidget {
  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  bool isPlaying = false; // AudioPlayer 상태와 동기화
  int score = 0;
  int pointDelta = 0;
  int currentLyricIndex = 0;
  double progress = 0.0; // 0~1
  late List<_LyricLine> lyricLines;
  Timer? mainTimer;
  final Random _random = Random();
  bool isFavorite = false; // 즐겨찾기 상태
  String? albumCoverUrl;
  bool loading = true;

  // AudioPlayer 관련 변수들
  late AudioPlayer audioPlayer;
  Duration totalDuration = Duration.zero;
  Duration currentPosition = Duration.zero;
  bool isAudioLoaded = false;

  // 퍼펙트스코어 멜로디 바 데이터 (임시 하드코딩)
  final List<_MelodyBar> melodyBars = [
    _MelodyBar(start: 0, duration: 2, pitch: 2),
    _MelodyBar(start: 1.5, duration: 1.2, pitch: 3),
    _MelodyBar(start: 3, duration: 1.5, pitch: 1),
    _MelodyBar(start: 4.5, duration: 1, pitch: 4),
    _MelodyBar(start: 5.5, duration: 2, pitch: 0),
    _MelodyBar(start: 7.5, duration: 1.5, pitch: 2),
    _MelodyBar(start: 9, duration: 1.2, pitch: 3),
    _MelodyBar(start: 10.5, duration: 1.5, pitch: 1),
  ];
  double defaultDuration = 50.0; // 기본 전체 길이(초) - AudioPlayer 로드 전까지 사용

  // 예시: 가사-시간 매핑
  // final List<_LyricLine> exampleLyrics = [
  //   _LyricLine(text: '손 닿을 수 없는 저기 어딘가', time: 0),
  //   _LyricLine(text: '오늘도 난 숨 쉬고 있지만', time: 3),
  //   _LyricLine(text: '너와 머물던 작은 의자 위에', time: 6),
  //   _LyricLine(text: '같은 모습의 바람이 지나네', time: 9),
  //   _LyricLine(text: '너는 떠나며 마치 날 떠나가듯이', time: 12),
  //   _LyricLine(text: '손 닿을 수 없는 저기 어딘가2', time: 15),
  //   _LyricLine(text: '오늘도 난 숨 쉬고 있지만2', time: 20),
  //   _LyricLine(text: '너와 머물던 작은 의자 위에2', time: 25),
  //   _LyricLine(text: '같은 모습의 바람이 지나네2', time: 28),
  //   _LyricLine(text: '너는 떠나며 마치 날 떠나가듯이2', time: 31),
  //   _LyricLine(text: '손 닿을 수 없는 저기 어딘가3', time: 33),
  //   _LyricLine(text: '오늘도 난 숨 쉬고 있지만3', time: 36),
  //   _LyricLine(text: '너와 머물던 작은 의자 위에3', time: 39),
  //   _LyricLine(text: '같은 모습의 바람이 지나네3', time: 42),
  //   _LyricLine(text: '너는 떠나며 마치 날 떠나가듯이3', time: 45),
  // ];

  @override
  void initState() {
    super.initState();
    lyricLines = exampleLyrics;
    _initAudioPlayer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _initAudioPlayer() {
    audioPlayer = AudioPlayer();
    print('AudioPlayer 초기화 완료');

    // 볼륨 설정 (0.0 ~ 1.0)
    audioPlayer.setVolume(1.0);
    print('AudioPlayer 볼륨 설정: 1.0');

    // AudioPlayer 이벤트 리스너 설정
    audioPlayer.onPositionChanged.listen((Duration position) {
      if (mounted) {
        setState(() {
          currentPosition = position;
          if (totalDuration.inMilliseconds > 0) {
            progress = position.inMilliseconds / totalDuration.inMilliseconds;
          }
          // 가사 인덱스 갱신
          for (int i = 0; i < lyricLines.length; i++) {
            if (position.inSeconds >= lyricLines[i].time) {
              currentLyricIndex = i;
            }
          }
        });
      }
    });

    audioPlayer.onDurationChanged.listen((Duration duration) {
      if (mounted) {
        setState(() {
          totalDuration = duration;
          print('오디오 길이: ${duration.inSeconds}초');
        });
      }
    });

    audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          isPlaying = state == PlayerState.playing;
        });
        print('오디오 상태 변경: $state');

        // 상태별 상세 로그
        switch (state) {
          case PlayerState.playing:
            print('🎵 오디오 재생 중 - 소리가 들려야 함');
            break;
          case PlayerState.paused:
            print('⏸️ 오디오 일시정지됨');
            break;
          case PlayerState.stopped:
            print('⏹️ 오디오 정지됨');
            break;
          case PlayerState.completed:
            print('✅ 오디오 재생 완료');
            break;
          default:
            print('❓ 알 수 없는 오디오 상태: $state');
        }
      }
    });

    // 상태/오류 로그 추가
    audioPlayer.onPlayerComplete.listen((_) {
      print('오디오 재생 완료');
    });
  }

  Future<void> _loadData() async {
    try {
      // initState에서는 context를 직접 사용할 수 없으므로 WidgetsBinding 사용
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        final song = ModalRoute.of(context)!.settings.arguments as Song;

        // S3에서 실제 데이터 불러오기
        String coverUrl = await fetchAlbumCoverUrl(song.artist, song.title);
        List<_LyricLine> lyrics = await fetchLyrics(
          song.artist,
          songTitle: song.title,
        );

        // S3에서 inst 파일 로드
        await _loadInstFile(song.artist, song.title);

        print('S3에서 불러온 앨범커버: $coverUrl');
        print('S3에서 불러온 가사 개수: ${lyrics.length}');

        if (mounted) {
          setState(() {
            albumCoverUrl = coverUrl;
            lyricLines = lyrics;
            loading = false;
          });
        }
      });
    } catch (e) {
      print('데이터 로딩 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          albumCoverUrl = 'https://via.placeholder.com/150';
          lyricLines = exampleLyrics;
          loading = false;
        });
      }
    }
  }

  Future<void> _loadInstFile(String artist, String title) async {
    try {
      // 파일명에서 특수문자 제거 및 공백을 언더스코어로 변경
      String safeArtist = artist
          .replaceAll(RegExp(r'[^\w\s가-힣]'), '')
          .replaceAll(' ', '_');
      String safeTitle = title
          .replaceAll(RegExp(r'[^\w\s가-힣]'), '')
          .replaceAll(' ', '_');

      // 여러 가능한 파일명 패턴 시도
      List<String> possibleUrls = [
        'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/MusicFile/$safeArtist/inst/${safeArtist}_${safeTitle}_inst.wav',
        'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/MusicFile/$artist/inst/${artist}_${safeTitle}_inst.wav',
        'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/MusicFile/$safeArtist/inst/${safeTitle}_inst.wav',
        'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/MusicFile/$artist/inst/${safeTitle}_inst.wav',
      ];

      for (String instUrl in possibleUrls) {
        print('Inst 파일 요청 시도: $instUrl');
        try {
          final response = await http.head(Uri.parse(instUrl));
          print('Inst 파일 응답 코드: ${response.statusCode}');

          if (response.statusCode == 200) {
            print('Inst 파일 로딩 성공: $instUrl');
            try {
              await audioPlayer.setSourceUrl(instUrl);
              print('AudioPlayer에 소스 설정 완료');

              // 볼륨을 명시적으로 설정
              await audioPlayer.setVolume(1.0);
              print('AudioPlayer 볼륨 설정 완료: 1.0');

              setState(() {
                isAudioLoaded = true;
              });
              print('isAudioLoaded: true로 설정됨');

              // 자동 재생 시도
              try {
                await audioPlayer.resume();
                print('AudioPlayer resume() 호출 성공');
              } catch (e) {
                print('AudioPlayer resume() 호출 실패: $e');
              }
              return;
            } catch (e) {
              print('AudioPlayer 소스 설정 실패: $e');
            }
          }
        } catch (e) {
          print('Inst 파일 요청 실패: $e');
          continue;
        }
      }

      print('모든 inst 파일 URL 시도 실패');
    } catch (e) {
      print('Inst 파일 로딩 실패: $e');
    }
  }

  void _togglePlay() async {
    if (!mounted) {
      print('컴포넌트가 마운트되지 않음');
      return;
    }
    if (!isAudioLoaded) {
      print('오디오가 로드되지 않음');
      return;
    }

    print('재생/일시정지 토글: 현재 상태 = $isPlaying');

    if (isPlaying) {
      print('일시정지 시도');
      await audioPlayer.pause();
      print('일시정지 완료');
    } else {
      print('재생 시도');
      try {
        // 재생 전에 볼륨을 다시 설정
        await audioPlayer.setVolume(1.0);
        print('재생 전 볼륨 설정: 1.0');

        await audioPlayer.resume();
        print('재생 성공');
      } catch (e) {
        print('재생 실패: $e');
      }
    }
  }

  void _onSeek(double value) async {
    if (!mounted || !isAudioLoaded) return;

    final newPosition = Duration(
      milliseconds: (value * totalDuration.inMilliseconds).round(),
    );
    await audioPlayer.seek(newPosition);
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Center(child: CircularProgressIndicator());
    final Song song = ModalRoute.of(context)!.settings.arguments as Song;
    final double barAreaWidth = MediaQuery.of(context).size.width * 0.92;
    final double barAreaHeight = 54;
    final double leftPadding = 24;
    final double centerLineX = barAreaWidth * 0.35; // 기준선을 좀 더 오른쪽으로
    double currentTime = currentPosition.inSeconds.toDouble();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 점수/정보
            Padding(
              padding: const EdgeInsets.only(
                top: 16,
                left: 24,
                right: 24,
                bottom: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: const Color(0xFFF59E0B),
                        size: 24,
                      ),
                      SizedBox(width: 6),
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        child: Text(
                          '$score/100',
                          key: ValueKey(score),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        child: Text(
                          pointDelta > 0
                              ? '+$pointDelta points'
                              : pointDelta < 0
                              ? '$pointDelta points'
                              : '',
                          key: ValueKey(pointDelta),
                          style: TextStyle(
                            fontSize: 14,
                            color: pointDelta > 0
                                ? const Color(0xFF10B981)
                                : pointDelta < 0
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite
                            ? const Color(0xFFEC4899)
                            : const Color(0xFF8B5CF6),
                        size: 24,
                      ),
                      onPressed: () {
                        if (!mounted) return;
                        setState(() {
                          isFavorite = !isFavorite;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            // 노래 정보
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 0),
              child: Column(
                children: [
                  // 앨범 커버
                  CachedNetworkImage(
                    imageUrl: albumCoverUrl ?? '',
                    placeholder: (context, url) => CircularProgressIndicator(),
                    errorWidget: (context, url, error) =>
                        Icon(Icons.music_note),
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                  SizedBox(height: 6),
                  Text(
                    song.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    song.artist,
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF8B5CF6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTag(
                        song.difficulty,
                        const Color(0xFFFEF3C7),
                        const Color(0xFF92400E),
                      ),
                      SizedBox(width: 8),
                      _buildTag(
                        song.range,
                        const Color(0xFFE0E7FF),
                        const Color(0xFF6B46C1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 18),
            // 퍼펙트스코어 바 + 세로 기준선 (왼쪽→중앙)
            SizedBox(
              width: barAreaWidth,
              height: barAreaHeight + 16,
              child: Stack(
                children: [
                  // 세로 기준선 (중앙보다 왼쪽)
                  Positioned(
                    left: centerLineX - 2,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // 멜로디 막대(오른쪽→왼쪽 이동, 기준선 통과 시 색상 점진적 변화)
                  for (int i = 0; i < melodyBars.length; i++)
                    _MelodyBarWidget(
                      bar: melodyBars[i],
                      progress: progress,
                      totalDuration: totalDuration.inSeconds.toDouble(),
                      barAreaWidth: barAreaWidth,
                      barAreaHeight: barAreaHeight,
                      centerLineX: centerLineX,
                      onPassed: (accuracy) {
                        if (!mounted) return;
                        setState(() {
                          int delta = 0;
                          switch (accuracy) {
                            case _Accuracy.Perfect:
                              delta = 5;
                              break;
                            case _Accuracy.Great:
                              delta = 3;
                              break;
                            case _Accuracy.Good:
                              delta = 0;
                              break;
                            case _Accuracy.Normal:
                              delta = -3;
                              break;
                            case _Accuracy.Bad:
                              delta = -5;
                              break;
                          }
                          score = max(0, score + delta);
                          pointDelta = delta;
                        });
                      },
                      currentTime: currentTime,
                      enableGradient: false,
                    ),
                ],
              ),
            ),
            SizedBox(height: 18),
            // 중앙 가사(11줄) - 클릭 이동만 지원
            Expanded(
              child: Center(
                child: _LyricSliderN(
                  lyricLines: lyricLines,
                  currentIndex: currentLyricIndex,
                  visibleCount: 11, // 강조 가사 위/아래 5줄씩 보이게
                  onTap: (idx) async {
                    if (!mounted || !isAudioLoaded) return;
                    setState(() {
                      currentLyricIndex = idx;
                    });
                    // 가사 시간에 맞춰 오디오 시크
                    final seekTime = Duration(
                      seconds: lyricLines[idx].time.toInt(),
                    );
                    await audioPlayer.seek(seekTime);
                  },
                ),
              ),
            ),
            // Spacer() 제거 (가사 중앙 배치 위해)
            // 하단 재생 시간/재생바/컨트롤
            Padding(
              padding: const EdgeInsets.only(
                bottom: 16,
                left: 24,
                right: 24,
                top: 0,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        _formatDuration(currentPosition),
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: totalDuration.inMilliseconds > 0
                              ? currentPosition.inMilliseconds /
                                    totalDuration.inMilliseconds
                              : 0.0,
                          min: 0,
                          max: 1,
                          onChanged: (v) {
                            _onSeek(v);
                          },
                          activeColor: const Color(0xFF8B5CF6),
                          inactiveColor: const Color(0xFFE5E7EB),
                        ),
                      ),
                      Text(
                        _formatDuration(totalDuration),
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _togglePlay,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            SizedBox(width: 10),
                            Text(
                              isPlaying ? '일시정지' : '재생',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  String _formatTime(double seconds) {
    int min = seconds ~/ 60;
    int sec = seconds.toInt() % 60;
    return '${min}:${sec.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    int min = duration.inMinutes;
    int sec = duration.inSeconds % 60;
    return '${min}:${sec.toString().padLeft(2, '0')}';
  }

  // 오디오 재생 함수 예시
  Future<void> playInst() async {
    final player = AudioPlayer();
    await player.play(AssetSource('audio/song1_inst.wav'));
  }
}

// 퍼펙트스코어 멜로디 바 데이터
class _MelodyBar {
  final double start; // 시작 시간(초)
  final double duration; // 길이(초)
  final int pitch; // 음정(0~N)
  _MelodyBar({
    required this.start,
    required this.duration,
    required this.pitch,
  });
}

// 가사-시간 매핑 데이터
class _LyricLine {
  final String text;
  final double time;
  _LyricLine({required this.text, required this.time});
}

// 퍼펙트스코어 멜로디 바 위젯 (세로 기준선, 오른쪽→왼쪽 이동, 기준선 통과 시 색상 점진적 변화)
class _MelodyBarWidget extends StatefulWidget {
  final _MelodyBar bar;
  final double progress;
  final double totalDuration;
  final double barAreaWidth;
  final double barAreaHeight;
  final double centerLineX;
  final double barHeight;
  final double barThickness;
  final double barSpacing;
  final double barSpeed;
  final double barPitchStep;
  final double barMinY;
  final double barMaxY;
  final Function(_Accuracy) onPassed;
  final double currentTime;
  final bool enableGradient;

  _MelodyBarWidget({
    required this.bar,
    required this.progress,
    required this.totalDuration,
    required this.barAreaWidth,
    required this.barAreaHeight,
    required this.centerLineX,
    required this.onPassed,
    required this.currentTime,
    this.barHeight = 12,
    this.barThickness = 8,
    this.barSpacing = 12,
    this.barSpeed = 1.0,
    this.barPitchStep = 12,
    this.barMinY = 8,
    this.barMaxY = 40,
    this.enableGradient = false,
  });

  @override
  State<_MelodyBarWidget> createState() => _MelodyBarWidgetState();
}

class _MelodyBarWidgetState extends State<_MelodyBarWidget> {
  bool passed = false;
  _Accuracy? lastAccuracy;

  @override
  void didUpdateWidget(covariant _MelodyBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mounted) return;
    // 기준선 통과 시 콜백(한 번만)
    if (!passed && _isPassingCenter()) {
      final acc = _randomAccuracy();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onPassed(acc);
      });
      lastAccuracy = acc;
      passed = true;
    }
    // 재시작 시 초기화
    if (widget.progress == 0 && passed) {
      passed = false;
      lastAccuracy = null;
    }
  }

  bool _isPassingCenter() {
    double barLeft = _barLeft();
    double center = widget.centerLineX;
    return (barLeft <= center && barLeft + barWidth() > center);
  }

  double _barLeft() {
    // 전체 진행에 따라 막대의 왼쪽 위치 계산 (오른쪽→왼쪽)
    double barProgress =
        (widget.currentTime - widget.bar.start) / widget.bar.duration;
    double width = barWidth();
    double totalMove = widget.barAreaWidth - width - 24; // 24: left padding 보정
    return barProgress < 0
        ? widget.barAreaWidth - width
        : barProgress > 1
        ? -width
        : widget.barAreaWidth - barProgress * totalMove - width;
  }

  double _barTop() {
    // pitch에 따라 y위치 조정 (pitch 0~4 기준)
    double pitchRange = 4;
    double step = (widget.barAreaHeight - widget.barThickness) / pitchRange;
    return (widget.barAreaHeight - widget.barThickness) / 2 -
        (widget.bar.pitch - 2) * step;
  }

  double barWidth() {
    return widget.bar.duration /
        widget.totalDuration *
        widget.barAreaWidth *
        1.1; // 1.1: 시각적으로 더 잘 보이게
  }

  Color _barColor() {
    if (lastAccuracy == null) return const Color(0xFFE0E7FF);
    switch (lastAccuracy!) {
      case _Accuracy.Perfect:
        return const Color(0xFF10B981);
      case _Accuracy.Great:
        return const Color(0xFF22C55E);
      case _Accuracy.Good:
        return const Color(0xFFF59E0B);
      case _Accuracy.Normal:
        return const Color(0xFF8B5CF6);
      case _Accuracy.Bad:
        return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    double left = _barLeft();
    double top = _barTop();
    double width = barWidth();
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: width,
        height: widget.barThickness,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            if (lastAccuracy != null)
              BoxShadow(
                color: _barColor().withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
          color: _barColor(),
        ),
      ),
    );
  }

  _Accuracy _randomAccuracy() {
    int r = Random().nextInt(100);
    if (r < 20) return _Accuracy.Perfect;
    if (r < 45) return _Accuracy.Great;
    if (r < 70) return _Accuracy.Good;
    if (r < 90) return _Accuracy.Normal;
    return _Accuracy.Bad;
  }
}

enum _Accuracy { Perfect, Great, Good, Normal, Bad }

// 싱크+슬라이딩 가사 위젯 (중앙 강조, 이전/다음 줄 흐리게, N줄, 클릭 이동 지원)
class _LyricSliderN extends StatelessWidget {
  final List<_LyricLine> lyricLines;
  final int currentIndex;
  final int visibleCount;
  final void Function(int)? onTap;
  const _LyricSliderN({
    required this.lyricLines,
    required this.currentIndex,
    this.visibleCount = 7,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> lines = [];
    int half = visibleCount ~/ 2;
    for (int i = -half; i <= half; i++) {
      int idx = currentIndex + i;
      if (idx < 0 || idx >= lyricLines.length) {
        lines.add(const SizedBox(height: 28));
        continue;
      }
      final isCurrent = i == 0;
      Widget textWidget = AnimatedDefaultTextStyle(
        duration: Duration(milliseconds: 200),
        style: TextStyle(
          fontSize: isCurrent ? 28 : 16,
          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
          color: isCurrent ? const Color(0xFF8B5CF6) : const Color(0xFF6B7280),
          shadows: isCurrent
              ? [
                  Shadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Text(
          lyricLines[idx].text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
      if (!isCurrent) {
        textWidget = Opacity(opacity: 0.4, child: textWidget);
      }
      lines.add(
        GestureDetector(
          onTap: () {
            if (onTap != null) onTap!(idx);
          },
          behavior: HitTestBehavior.translucent,
          child: textWidget,
        ),
      );
    }
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: lines);
  }
}

Future<String> fetchAlbumCoverUrl(String artist, String title) async {
  try {
    // 백엔드 API를 통해 presigned URL 생성
    final apiUrl =
        'http://localhost:8000/api/s3/album_cover?artist=${Uri.encodeComponent(artist)}&title=${Uri.encodeComponent(title)}';
    print('앨범커버 API 요청: $apiUrl');

    final response = await http.get(Uri.parse(apiUrl));
    print('앨범커버 API 응답 코드: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final presignedUrl = data['url'];
      print('앨범커버 presigned URL 생성 성공: $presignedUrl');
      return presignedUrl;
    } else {
      print('앨범커버 API 실패 (${response.statusCode}): ${response.body}');
      // API 실패 시 직접 S3 접근 시도
      return await _tryDirectS3Access(artist, title);
    }
  } catch (e) {
    print('앨범커버 API 요청 실패: $e');
    // API 실패 시 직접 S3 접근 시도
    return await _tryDirectS3Access(artist, title);
  }
}

Future<String> _tryDirectS3Access(String artist, String title) async {
  try {
    // 파일명에서 특수문자 제거 및 공백을 언더스코어로 변경
    String safeArtist = artist
        .replaceAll(RegExp(r'[^\w\s가-힣]'), '')
        .replaceAll(' ', '_');
    String safeTitle = title
        .replaceAll(RegExp(r'[^\w\s가-힣]'), '')
        .replaceAll(' ', '_');

    // 여러 가능한 파일명 패턴 시도
    List<String> possibleUrls = [
      'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/album_cover/$safeArtist\_$safeTitle.jpg',
      'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/album_cover/$artist\_$title.jpg',
      'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/album_cover/$safeArtist/$safeTitle.jpg',
      'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/album_cover/$artist/$title.jpg',
    ];

    for (String s3Url in possibleUrls) {
      print('앨범커버 직접 S3 요청 시도: $s3Url');
      try {
        final response = await http.head(Uri.parse(s3Url));
        print('앨범커버 직접 S3 응답 코드: ${response.statusCode}');

        if (response.statusCode == 200) {
          print('앨범커버 직접 S3 성공: $s3Url');
          return s3Url;
        }
      } catch (e) {
        print('앨범커버 직접 S3 요청 실패: $e');
        continue;
      }
    }

    print('모든 앨범커버 URL 시도 실패');
    return 'https://via.placeholder.com/150x150?text=앨범커버';
  } catch (e) {
    print('앨범커버 직접 S3 접근 실패: $e');
    return 'https://via.placeholder.com/150x150?text=앨범커버';
  }
}

// SRT 시간 형식을 초 단위로 변환하는 함수
double _parseSrtTime(String timeStr) {
  // 00:00:01,000 형식을 초 단위로 변환
  final parts = timeStr.split(':');
  if (parts.length == 3) {
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final secondsParts = parts[2].split(',');
    final seconds = int.tryParse(secondsParts[0]) ?? 0;
    final milliseconds =
        int.tryParse(secondsParts.length > 1 ? secondsParts[1] : '0') ?? 0;

    return hours * 3600 + minutes * 60 + seconds + milliseconds / 1000;
  }
  return 0.0;
}

Future<List<_LyricLine>> fetchLyrics(String artist, {String? songTitle}) async {
  try {
    // 백엔드 API를 통해 가사 데이터 가져오기
    final songName = songTitle ?? 'Never Ending Story';
    final apiUrl =
        'http://localhost:8000/api/s3/lyrics?artist=${Uri.encodeComponent(artist)}&song=${Uri.encodeComponent(songName)}';
    print('가사 API 요청: $apiUrl');

    final response = await http.get(Uri.parse(apiUrl));
    print('가사 API 응답 코드: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final lyricsData = data['lyrics'] as List;

      List<_LyricLine> lyrics = [];
      for (var lyric in lyricsData) {
        lyrics.add(
          _LyricLine(text: lyric['text'], time: lyric['time'].toDouble()),
        );
      }

      print('API에서 파싱된 가사 개수: ${lyrics.length}');
      return lyrics;
    } else {
      print('가사 API 실패 (${response.statusCode}): ${response.body}');
      // API 실패 시 직접 S3 접근 시도
      return await _tryDirectS3LyricsAccess(artist, songTitle);
    }
  } catch (e) {
    print('가사 API 요청 실패: $e');
    // API 실패 시 직접 S3 접근 시도
    return await _tryDirectS3LyricsAccess(artist, songTitle);
  }
}

Future<List<_LyricLine>> _tryDirectS3LyricsAccess(
  String artist,
  String? songTitle,
) async {
  try {
    // 파일명에서 특수문자 제거 및 공백을 언더스코어로 변경
    String safeArtist = artist
        .replaceAll(RegExp(r'[^\w\s가-힣]'), '')
        .replaceAll(' ', '_');
    String safeTitle =
        songTitle?.replaceAll(RegExp(r'[^\w\s가-힣]'), '').replaceAll(' ', '_') ??
        'Never_Ending_Story';

    // 여러 가능한 파일명 패턴 시도
    List<String> possibleUrls = [
      'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/lyrics/$safeArtist/${safeArtist}_$safeTitle.srt',
      'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/lyrics/$artist/${artist}_$safeTitle.srt',
      'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/lyrics/$safeArtist/$safeTitle.srt',
      'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/lyrics/$artist/$safeTitle.srt',
    ];

    for (String s3Url in possibleUrls) {
      print('가사 직접 S3 요청 시도: $s3Url');
      try {
        final response = await http.get(Uri.parse(s3Url));
        print('가사 직접 S3 응답 코드: ${response.statusCode}');

        if (response.statusCode == 200) {
          print('가사 직접 S3 로딩 성공: $s3Url');
          print('S3 응답 body 길이: ${response.body.length}');
          if (response.body.length > 100) {
            print('S3 응답 body 앞 100자: ${response.body.substring(0, 100)}');
          }

          // 인코딩 문제 해결을 위해 여러 인코딩 시도
          String decodedContent = '';
          List<int> bytes = response.bodyBytes;

          // BOM 확인 및 제거
          if (bytes.length >= 3 &&
              bytes[0] == 0xEF &&
              bytes[1] == 0xBB &&
              bytes[2] == 0xBF) {
            bytes = bytes.sublist(3); // UTF-8 BOM 제거
            print('UTF-8 BOM 제거됨');
          }

          // UTF-8 시도
          try {
            decodedContent = utf8.decode(bytes);
            print('UTF-8 디코딩 성공');
          } catch (e) {
            print('UTF-8 디코딩 실패, 다른 인코딩 시도');
            // EUC-KR 시도 (한국어에서 자주 사용)
            try {
              decodedContent = latin1.decode(bytes);
              print('Latin1 디코딩 성공');
            } catch (e) {
              print('Latin1 디코딩도 실패, 원본 사용');
              decodedContent = response.body;
            }
          }

          // 디코딩된 내용 로그 출력
          if (decodedContent.length > 200) {
            print('디코딩된 내용 앞 200자: ${decodedContent.substring(0, 200)}');
          }

          final lines = LineSplitter.split(decodedContent).toList();
          List<_LyricLine> lyrics = [];

          // SRT 파일 파싱
          for (int i = 0; i < lines.length; i++) {
            String line = lines[i].trim();

            // 시간 라인 찾기 (00:00:01,000 --> 00:00:04,000 형식)
            if (line.contains('-->')) {
              final timeParts = line.split(' --> ');
              if (timeParts.length == 2) {
                final startTime = _parseSrtTime(timeParts[0]);

                // 다음 라인이 가사인지 확인
                if (i + 1 < lines.length) {
                  String lyricText = lines[i + 1].trim();
                  if (lyricText.isNotEmpty && !lyricText.contains('-->')) {
                    lyrics.add(_LyricLine(text: lyricText, time: startTime));
                  }
                }
              }
            }
          }

          if (lyrics.isNotEmpty) {
            print('SRT에서 파싱된 가사 개수: ${lyrics.length}');
            return lyrics;
          } else {
            print('SRT 파싱 결과 가사가 없음');
          }
        } else {
          print('가사 직접 S3 요청 실패 (${response.statusCode}): $s3Url');
        }
      } catch (e) {
        print('가사 직접 S3 요청 중 오류: $e');
        continue;
      }
    }

    print('모든 가사 URL 시도 실패, 기본 가사 사용');
    return exampleLyrics;
  } catch (e) {
    print('가사 직접 S3 접근 실패: $e');
    return exampleLyrics;
  }
}
