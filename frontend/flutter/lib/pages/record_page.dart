import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../models/song.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:audioplayers/audioplayers.dart';

class RecordPage extends StatefulWidget {
  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  bool isPlaying = true;
  int score = 0;
  int pointDelta = 0;
  int currentLyricIndex = 0;
  double progress = 0.0; // 0~1
  late List<_LyricLine> lyricLines;
  Timer? mainTimer;
  final Random _random = Random();
  bool isFavorite = false; // 즐겨찾기 상태

  late AudioPlayer _audioPlayer;

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
  double totalDuration = 50.0; // 예시 전체 길이(초)

  // 예시: 가사-시간 매핑
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

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    lyricLines = exampleLyrics;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMainTimer();
    });
  }

  void _startMainTimer() {
    mainTimer?.cancel();
    mainTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      if (!isPlaying) return;
      setState(() {
        progress += 0.1 / totalDuration; // 0.1초씩 진행
        if (progress > 1.0) progress = 1.0;
        // 가사 인덱스 갱신
        for (int i = 0; i < lyricLines.length; i++) {
          if (progress * totalDuration >= lyricLines[i].time) {
            currentLyricIndex = i;
          }
        }
      });
    });
  }

  void _stopMainTimer() {
    mainTimer?.cancel();
  }

  void _togglePlay() {
    if (!mounted) return;
    setState(() {
      isPlaying = !isPlaying;
      if (isPlaying) {
        _startMainTimer();
        _audioPlayer.resume();
      } else {
        _stopMainTimer();
        _audioPlayer.pause();
      }
    });
  }

  void _onSeek(double value) {
    if (!mounted) return;
    setState(() {
      progress = value;
      _audioPlayer.seek(Duration(seconds: (value * totalDuration).toInt()));
      // 가사 인덱스 갱신
      for (int i = 0; i < lyricLines.length; i++) {
        if (progress * totalDuration >= lyricLines[i].time) {
          currentLyricIndex = i;
        }
      }
    });
  }

  @override
  void dispose() {
    _stopMainTimer();
    _audioPlayer.dispose();
    mainTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Song song = ModalRoute.of(context)!.settings.arguments as Song;
    double currentTime = progress * totalDuration;

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
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        song.albumCover.isNotEmpty
                            ? song.albumCover
                            : 'assets/images/Img.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/images/Img.png',
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final barAreaWidth = constraints.maxWidth - 48; // Padding 24*2
                final barAreaHeight = 100.0; // 고정 높이
                final centerLineX = barAreaWidth / 2;

                return SizedBox(
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
                          totalDuration: totalDuration,
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
                );
              },
            ),
            SizedBox(height: 18),
            // 중앙 가사(11줄) - 클릭 이동만 지원
            Expanded(
              child: Center(
                child: _LyricSliderN(
                  lyricLines: lyricLines,
                  currentIndex: currentLyricIndex,
                  visibleCount: 11, // 강조 가사 위/아래 5줄씩 보이게
                  onTap: (idx) {
                    if (!mounted) return;
                    setState(() {
                      currentLyricIndex = idx;
                      progress = lyricLines[idx].time / totalDuration;
                      _audioPlayer.seek(Duration(seconds: lyricLines[idx].time.toInt()));
                    });
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
                        _formatTime(currentTime),
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: progress,
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
                        _formatTime(totalDuration),
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
    final minutes = (seconds ~/ 60).toInt();
    final remainingSeconds = (seconds % 60).toInt();
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // 오디오 재생 함수 예시
  Future<void> playInst() async {
    await _audioPlayer.play(AssetSource('audio/song1_inst.wav'));
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
    double totalMove = widget.barAreaWidth - width - 48; // 24: left padding 보정
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
