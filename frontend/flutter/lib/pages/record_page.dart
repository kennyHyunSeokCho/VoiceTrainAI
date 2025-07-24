import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:SingSang/audio_compare_plugin.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/song.dart';
import '../services/s3_service.dart';
import 'score_page.dart';
import 'package:SingSang/services/tensor_dsp_service.dart';

// MIDI 노트 데이터 클래스
class _MidiNote {
  final double startTime; // 시작 시간 (초)
  final double duration; // 지속 시간 (초)
  final int pitch; // 음정 (MIDI 노트 번호)
  final int velocity; // 음량 (0-127)
  final int channel; // MIDI 채널

  _MidiNote({
    required this.startTime,
    required this.duration,
    required this.pitch,
    required this.velocity,
    required this.channel,
  });

  // MIDI 노트를 화면 위치로 변환
  double get visualPitch {
    // MIDI 노트 번호를 화면 Y 좌표로 변환 (높은 음정일수록 위쪽)
    // 일반적인 가창 음역대: C3(48) ~ C6(84) = 36개 노트
    const double minPitch = 48.0; // C3
    const double maxPitch = 84.0; // C6
    const double visualHeight = 40.0; // 시각화 영역 높이

    double normalizedPitch = (pitch - minPitch) / (maxPitch - minPitch);
    normalizedPitch = normalizedPitch.clamp(0.0, 1.0);
    return (1.0 - normalizedPitch) * visualHeight; // 높은 음정일수록 위쪽
  }
}

// MIDI 파일 파싱 클래스
class _MidiParser {
  static Future<List<_MidiNote>> parseMidiFromBytes(List<int> bytes) async {
    try {
      List<_MidiNote> notes = [];

      // MIDI 헤더 확인
      if (bytes.length < 14 ||
          bytes[0] != 0x4D ||
          bytes[1] != 0x54 ||
          bytes[2] != 0x68 ||
          bytes[3] != 0x64) {
        print('유효하지 않은 MIDI 파일');
        return _generateSampleNotes();
      }

      // 기본 설정
      double tempo = 500000.0; // 마이크로초/비트 (120 BPM)
      double ticksPerBeat = 1920.0;

      // 헤더에서 ticks per beat 추출
      int headerLength =
          (bytes[4] << 24) + (bytes[5] << 16) + (bytes[6] << 8) + bytes[7];
      if (headerLength >= 6) {
        ticksPerBeat = ((bytes[12] << 8) + bytes[13]).toDouble();
        print('Ticks per beat: $ticksPerBeat');
      }

      // 템포 이벤트 찾기
      for (int i = 0; i < bytes.length - 6; i++) {
        if (bytes[i] == 0xFF && bytes[i + 1] == 0x51 && bytes[i + 2] == 0x03) {
          int tempoValue =
              (bytes[i + 3] << 16) + (bytes[i + 4] << 8) + bytes[i + 5];
          tempo = tempoValue.toDouble();
          print('템포 발견: ${(60000000 / tempo).toStringAsFixed(1)} BPM');
          break;
        }
      }

      // 트랙 데이터 파싱
      int offset = 14; // 헤더 이후
      Map<String, double> activeNotes = {}; // note_channel -> startTime
      double currentTime = 0.0;

      while (offset < bytes.length - 8) {
        // 트랙 헤더 확인
        if (bytes[offset] == 0x4D &&
            bytes[offset + 1] == 0x54 &&
            bytes[offset + 2] == 0x72 &&
            bytes[offset + 3] == 0x6B) {
          int trackLength =
              (bytes[offset + 4] << 24) +
              (bytes[offset + 5] << 16) +
              (bytes[offset + 6] << 8) +
              bytes[offset + 7];
          offset += 8;
          int trackEnd = offset + trackLength;

          while (offset < trackEnd && offset < bytes.length - 1) {
            // 델타 타임 읽기
            int deltaTicks = 0;
            int shift = 0;
            while (offset < trackEnd && (bytes[offset] & 0x80) != 0) {
              deltaTicks |= (bytes[offset] & 0x7F) << shift;
              shift += 7;
              offset++;
            }
            if (offset < trackEnd) {
              deltaTicks |= (bytes[offset] & 0x7F) << shift;
              offset++;
            }

            // 델타 타임을 초로 변환
            double deltaTime = _ticksToSeconds(deltaTicks, tempo, ticksPerBeat);
            currentTime += deltaTime;

            if (offset >= trackEnd || offset >= bytes.length) break;

            // 이벤트 타입 확인
            int eventType = bytes[offset];

            if (eventType == 0xFF) {
              // 메타 이벤트
              if (offset + 2 < trackEnd) {
                int metaLength = bytes[offset + 2];
                offset += 3 + metaLength;
              } else {
                break;
              }
            } else if ((eventType & 0xF0) == 0x90) {
              // Note On
              if (offset + 2 < trackEnd) {
                int note = bytes[offset + 1];
                int velocity = bytes[offset + 2];
                int channel = eventType & 0x0F;

                if (velocity > 0) {
                  String noteKey = '${note}_$channel';
                  activeNotes[noteKey] = currentTime;
                } else {
                  // velocity 0은 Note Off와 동일
                  String noteKey = '${note}_$channel';
                  if (activeNotes.containsKey(noteKey)) {
                    double startTime = activeNotes[noteKey]!;
                    double duration = currentTime - startTime;

                    if (duration > 0.05) {
                      // 최소 50ms
                      notes.add(
                        _MidiNote(
                          startTime: startTime,
                          duration: duration,
                          pitch: note,
                          velocity: 100,
                          channel: channel,
                        ),
                      );
                    }
                    activeNotes.remove(noteKey);
                  }
                }
                offset += 3;
              } else {
                break;
              }
            } else if ((eventType & 0xF0) == 0x80) {
              // Note Off
              if (offset + 2 < trackEnd) {
                int note = bytes[offset + 1];
                int channel = eventType & 0x0F;
                String noteKey = '${note}_$channel';

                if (activeNotes.containsKey(noteKey)) {
                  double startTime = activeNotes[noteKey]!;
                  double duration = currentTime - startTime;

                  if (duration > 0.05) {
                    // 최소 50ms
                    notes.add(
                      _MidiNote(
                        startTime: startTime,
                        duration: duration,
                        pitch: note,
                        velocity: 100,
                        channel: channel,
                      ),
                    );
                  }
                  activeNotes.remove(noteKey);
                }
                offset += 3;
              } else {
                break;
              }
            } else {
              // 다른 이벤트는 건너뛰기
              offset++;
            }
          }
        } else {
          offset++;
        }
      }

      // 시작 시간순으로 정렬
      notes.sort((a, b) => a.startTime.compareTo(b.startTime));

      print('MIDI 파싱 완료: ${notes.length}개 노트');

      // 노트가 없으면 빈 리스트 반환 (하드코딩된 샘플 노트 제거)
      if (notes.isEmpty) {
        print('MIDI 파일에 노트가 없음');
        return [];
      }

      return notes;
    } catch (e) {
      print('MIDI 파싱 오류: $e');
      return []; // 하드코딩된 샘플 노트 대신 빈 리스트 반환
    }
  }

  // MIDI 틱을 초로 변환
  static double _ticksToSeconds(int ticks, double tempo, double ticksPerBeat) {
    double secondsPerBeat = tempo / 1000000.0;
    double secondsPerTick = secondsPerBeat / ticksPerBeat;
    return ticks * secondsPerTick;
  }

  // 샘플 노트 생성 (MIDI 파싱 실패 시 사용) - 가사 음절별 노트
  static List<_MidiNote> _generateSampleNotes() {
    return [
      // 첫 번째 음절: "그날"
      _MidiNote(
        startTime: 0.0,
        duration: 0.3,
        pitch: 60,
        velocity: 100,
        channel: 0,
      ), // C4
      _MidiNote(
        startTime: 0.3,
        duration: 0.3,
        pitch: 62,
        velocity: 100,
        channel: 0,
      ), // D4
      // 두 번째 음절: "이후로"
      _MidiNote(
        startTime: 0.6,
        duration: 0.2,
        pitch: 64,
        velocity: 100,
        channel: 0,
      ), // E4
      _MidiNote(
        startTime: 0.8,
        duration: 0.2,
        pitch: 65,
        velocity: 100,
        channel: 0,
      ), // F4
      _MidiNote(
        startTime: 1.0,
        duration: 0.2,
        pitch: 67,
        velocity: 100,
        channel: 0,
      ), // G4
      // 세 번째 음절: "난"
      _MidiNote(
        startTime: 1.2,
        duration: 0.4,
        pitch: 69,
        velocity: 100,
        channel: 0,
      ), // A4
      // 네 번째 음절: "이렇게"
      _MidiNote(
        startTime: 1.6,
        duration: 0.2,
        pitch: 71,
        velocity: 100,
        channel: 0,
      ), // B4
      _MidiNote(
        startTime: 1.8,
        duration: 0.2,
        pitch: 72,
        velocity: 100,
        channel: 0,
      ), // C5
      _MidiNote(
        startTime: 2.0,
        duration: 0.2,
        pitch: 71,
        velocity: 100,
        channel: 0,
      ), // B4
      // 다섯 번째 음절: "살고"
      _MidiNote(
        startTime: 2.2,
        duration: 0.3,
        pitch: 69,
        velocity: 100,
        channel: 0,
      ), // A4
      _MidiNote(
        startTime: 2.5,
        duration: 0.3,
        pitch: 67,
        velocity: 100,
        channel: 0,
      ), // G4
      // 여섯 번째 음절: "더는"
      _MidiNote(
        startTime: 2.8,
        duration: 0.2,
        pitch: 65,
        velocity: 100,
        channel: 0,
      ), // F4
      _MidiNote(
        startTime: 3.0,
        duration: 0.2,
        pitch: 64,
        velocity: 100,
        channel: 0,
      ), // E4
      // 일곱 번째 음절: "기타"
      _MidiNote(
        startTime: 3.2,
        duration: 0.2,
        pitch: 62,
        velocity: 100,
        channel: 0,
      ), // D4
      _MidiNote(
        startTime: 3.4,
        duration: 0.2,
        pitch: 60,
        velocity: 100,
        channel: 0,
      ), // C4
      // 여덟 번째 음절: "한번도"
      _MidiNote(
        startTime: 3.6,
        duration: 0.2,
        pitch: 62,
        velocity: 100,
        channel: 0,
      ), // D4
      _MidiNote(
        startTime: 3.8,
        duration: 0.2,
        pitch: 64,
        velocity: 100,
        channel: 0,
      ), // E4
      _MidiNote(
        startTime: 4.0,
        duration: 0.2,
        pitch: 65,
        velocity: 100,
        channel: 0,
      ), // F4
      // 아홉 번째 음절: "들지"
      _MidiNote(
        startTime: 4.2,
        duration: 0.3,
        pitch: 67,
        velocity: 100,
        channel: 0,
      ), // G4
      _MidiNote(
        startTime: 4.5,
        duration: 0.3,
        pitch: 69,
        velocity: 100,
        channel: 0,
      ), // A4
      // 열 번째 음절: "못하고"
      _MidiNote(
        startTime: 4.8,
        duration: 0.2,
        pitch: 71,
        velocity: 100,
        channel: 0,
      ), // B4
      _MidiNote(
        startTime: 5.0,
        duration: 0.2,
        pitch: 72,
        velocity: 100,
        channel: 0,
      ), // C5
      _MidiNote(
        startTime: 5.2,
        duration: 0.2,
        pitch: 71,
        velocity: 100,
        channel: 0,
      ), // B4
    ];
  }
}

// MIDI 노트를 시각화하는 위젯
class _MidiNoteWidget extends StatefulWidget {
  final _MidiNote note;
  final double progress;
  final double totalDuration;
  final double barAreaWidth;
  final double barAreaHeight;
  final double centerLineX;
  final double currentTime;
  final Function(_Accuracy) onPassed;

  const _MidiNoteWidget({
    required this.note,
    required this.progress,
    required this.totalDuration,
    required this.barAreaWidth,
    required this.barAreaHeight,
    required this.centerLineX,
    required this.currentTime,
    required this.onPassed,
  });

  @override
  State<_MidiNoteWidget> createState() => _MidiNoteWidgetState();
}

class _MidiNoteWidgetState extends State<_MidiNoteWidget> {
  bool passed = false;
  _Accuracy? lastAccuracy;

  @override
  void didUpdateWidget(covariant _MidiNoteWidget oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    double left = _calculateLeft();
    double top = widget.note.visualPitch;
    double width = _calculateWidth();

    // 색상 결정
    Color noteColor = _getNoteColor();

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: width,
        height: 8, // 원래 크기로 복원
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4), // 원래 크기로 복원
          color: noteColor,
        ),
      ),
    );
  }

  double _calculateLeft() {
    // 노트의 시작 시간에 따른 X 위치 계산 (오른쪽에서 왼쪽으로)
    double width = _calculateWidth();
    double totalMove = widget.barAreaWidth - width - 24; // 24: left padding 보정

    // 현재 재생 시간을 기준으로 4초 후의 노트들이 화면에 나타남
    double lookAheadTime = 4.0; // 4초 전부터 노트 표시

    // 노트가 화면에 나타나기 시작하는 시간
    double appearTime = widget.currentTime + lookAheadTime;

    // 노트가 현재 시간보다 미래에 있으면 아직 나타나지 않음
    if (widget.note.startTime > appearTime) {
      return widget.barAreaWidth; // 화면 오른쪽 밖
    }

    // 노트가 이미 지나간 후면 화면에서 사라짐
    if (widget.note.startTime + widget.note.duration < widget.currentTime) {
      return -width; // 화면 왼쪽 밖
    }

    // 노트가 화면에 나타나는 동안의 위치 계산
    double timeFromAppear = widget.note.startTime - widget.currentTime;
    double progress = (lookAheadTime - timeFromAppear) / lookAheadTime;
    progress = progress.clamp(0.0, 1.0);

    // 오른쪽에서 왼쪽으로 이동
    return widget.barAreaWidth - (progress * totalMove);
  }

  double _calculateWidth() {
    // 노트 길이에 따른 너비 계산
    return (widget.note.duration / widget.totalDuration) *
        widget.barAreaWidth *
        1.2;
  }

  bool _isPassingCenter() {
    // 노트가 기준선을 지나가는 시점은 노트의 시작 시간
    double timeDiff = (widget.note.startTime - widget.currentTime).abs();
    return timeDiff <= 0.1; // 0.1초 오차 범위 내에서 감지
  }

  Color _getNoteColor() {
    // 기준선을 지나기 전에는 기본 색상, 지난 후에는 정확도에 따른 색상
    if (lastAccuracy == null) {
      return const Color(0xFF7F8CAA); // 기본 색상 (사용자 요구사항)
    }

    // 정확도에 따른 색상 (사용자 요구사항)
    switch (lastAccuracy!) {
      case _Accuracy.Perfect:
        return const Color(0xFF91C8E4); // Perfect: 91C8E4
      case _Accuracy.Great:
        return const Color(0xFF97B067); // Great: 97B067
      case _Accuracy.Good:
        return const Color(0xFFFFCC00); // Good: FFCC00
      case _Accuracy.Normal:
        return const Color(0xFFFF6F3C); // Normal: FF6F3C
      case _Accuracy.Bad:
        return const Color(0xFFB22222); // Bad: B22222
    }
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
  double currentScore = 0.0; // 점수: TensorDSP 값으로만 갱신
  double currentPitch = 0.0; // 피치: TensorDSP 값으로만 갱신
  Timer? _tensorDspTimer;

  // --- 실시간 분석/점수 관련 변수 모음 ---
  // 피치
  List<double> _pitchHistory = [];

  // 온셋
  double currentOnset = 0.0;
  StreamSubscription<double>? _onsetSub;
  List<double> _onsetHistory = [];
  // --- END ---

  bool isPlaying = false;
  bool isRecording = false;
  int pointDelta = 0;
  int currentLyricIndex = 0;
  double progress = 0.0; // 0~1
  late List<_LyricLine> lyricLines;
  Timer? mainTimer;
  final Random _random = Random();
  bool isFavorite = false; // 즐겨찾기 상태
  String? albumCoverUrl;
  bool loading = true;

  // Inst 파일 재생 관련 변수들
  AudioPlayer? _instPlayer;
  bool _isInstPlaying = false;
  bool _isInstLoading = false;
  double _instDuration = 0.0; // inst 파일의 실제 재생시간

  // MIDI 노트 데이터 (실제 MIDI 파일에서 파싱됨)
  List<_MidiNote> midiNotes = [];
  bool _isMidiLoading = false;

  // 점수 계산 관련 변수들
  bool _hasRecording = false; // 실제 녹음 여부
  int _pitchScore = 0;
  int _rhythmScore = 0;
  int _totalScore = 0;
  List<String> _recommendedSongs = [];

  // 퍼펙트스코어 멜로디 바 데이터 (임시 하드코딩) - MIDI 로드 실패 시 사용
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
  double totalDuration = 50.0; // 예시 전체 길이(초) - inst 파일 로드 후 업데이트됨

  // 예시: 가사-시간 매핑
  // final List<_LyricLine> exampleLyrics = [
  //   _LyricLine(text: '손 닿을 수 없는 저기 어딘가', time: 0),
  //   _LyricLine(text: '오늘도 난 숨 쉬고 있지만', time: 3),
  //   _LyricLine(text: '너와 머물던 작은 의자 위에', time: 6),
  //   _LyricLine(text: '같은 모습의 바람이 지나네', time: 9),
  //   _LyricLine(text: '너는 떠나며 마치 날 떠나가듯이', time: 12),
  //   _LyricLine(text: '손 닿을 수 없는 저기 어딘가2', time: 15),
  //   _LyricLine(text: '오늘도 난 숨 MIDI 파일을 시각화하는 코드MIDI 파일을 시각화하는 코드쉬고 있지만2', time: 20),
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
    _initInstPlayer();
    // 초기에는 타이머를 시작하지 않음 (녹음 시작 시에만 시작)
    _loadData();
    // --- 실시간 피치/온셋 구독 ---
    _onsetSub = AudioComparePlugin.onsetStream.listen((onset) {
      setState(() {
        currentOnset = onset;
        _onsetHistory.add(onset);
        if (_onsetHistory.length > 50) _onsetHistory.removeAt(0);
      });
    });
    // AudioComparePlugin 점수/피치 스트림 구독 및 setState 코드 제거
    _tensorDspTimer = Timer.periodic(Duration(milliseconds: 100), (_) async {
      final data = await TensorDspService.getCurrentPitchScore();
      if (!mounted) return;
      setState(() {
        currentScore = data['score'] ?? 0.0;
        currentPitch = data['pitch'] ?? 0.0;
      });
    });
  }

  void _initInstPlayer() {
    _instPlayer = AudioPlayer();
    _instPlayer!.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isInstPlaying = state == PlayerState.playing;
        });
      }
    });
    _instPlayer!.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _instDuration = duration.inMilliseconds / 1000.0;
          totalDuration = _instDuration; // 실제 inst 파일 길이로 업데이트
        });
      }
    });
    _instPlayer!.onPositionChanged.listen((position) {
      if (mounted && _isInstPlaying) {
        setState(() {
          progress = position.inMilliseconds / 1000.0 / totalDuration;
          if (progress > 1.0) progress = 1.0;
          // 가사 인덱스 갱신
          for (int i = 0; i < lyricLines.length; i++) {
            if (progress * totalDuration >= lyricLines[i].time) {
              currentLyricIndex = i;
            }
          }
        });
      }
    });

    // 노래 종료 시 점수 페이지로 이동
    _instPlayer!.onPlayerComplete.listen((_) {
      if (mounted) {
        _calculateScores();
        _navigateToScorePage();
      }
    });
  }

  void _initInstPlayer() {
    _instPlayer = AudioPlayer();
    _instPlayer!.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isInstPlaying = state == PlayerState.playing;
        });
      }
    });
    _instPlayer!.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _instDuration = duration.inMilliseconds / 1000.0;
          totalDuration = _instDuration; // 실제 inst 파일 길이로 업데이트
        });
      }
    });
    _instPlayer!.onPositionChanged.listen((position) {
      if (mounted && _isInstPlaying) {
        setState(() {
          progress = position.inMilliseconds / 1000.0 / totalDuration;
          if (progress > 1.0) progress = 1.0;
          // 가사 인덱스 갱신
          for (int i = 0; i < lyricLines.length; i++) {
            if (progress * totalDuration >= lyricLines[i].time) {
              currentLyricIndex = i;
            }
          }
        });
      }
    });
    
    // 노래 종료 시 점수 페이지로 이동
    _instPlayer!.onPlayerComplete.listen((_) {
      if (mounted) {
        _calculateScores();
        _navigateToScorePage();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      // initState에서는 context를 직접 사용할 수 없으므로 WidgetsBinding 사용
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        final song = ModalRoute.of(context)?.settings.arguments as Song?;
        if (song == null) {
          print('Song 객체가 null입니다. 데이터 로딩을 건너뜁니다.');
          return;
        }

        // S3에서 실제 데이터 불러오기
        String coverUrl = await fetchAlbumCoverUrl(song.artist, song.title);
        List<_LyricLine> lyrics = await fetchLyrics(
          song.artist,
          songTitle: song.title,
        );

        print('S3에서 불러온 앨범커버: $coverUrl');
        print('S3에서 불러온 가사 개수: ${lyrics.length}');

        // Inst 파일과 MIDI 파일 동시 로드
        await Future.wait([
          _loadInstFile(song.artist, song.title),
          _loadMidiFile(song.artist, song.title),
        ]);

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
      final instUrl = S3Service.getInstSongUrl(artist, title);
      print('Inst 파일 URL: $instUrl');

      setState(() {
        _isInstLoading = true;
      });

      await _instPlayer!.setSourceUrl(instUrl);

      setState(() {
        _isInstLoading = false;
      });

      print('Inst 파일 로드 완료 (자동 재생 안함)');
    } catch (e) {
      print('Inst 파일 로드 실패: $e');
      setState(() {
        _isInstLoading = false;
      });
    }
  }

  Future<void> _loadMidiFile(String artist, String title) async {
    try {
      setState(() {
        _isMidiLoading = true;
      });

      // S3Service를 사용해서 MIDI 파일 URL 생성
      final midiUrl = S3Service.getMidiFileUrl(artist, title);
      print('MIDI 파일 URL: $midiUrl');

      // MIDI 파일 다운로드
      final response = await http.get(Uri.parse(midiUrl));

      if (response.statusCode == 200) {
        print('MIDI 파일 다운로드 성공, 크기: ${response.bodyBytes.length} bytes');

        // MIDI 파일 파싱 - 원본 악보 데이터 그대로 사용
        final notes = await _MidiParser.parseMidiFromBytes(response.bodyBytes);

        if (mounted) {
          setState(() {
            midiNotes = notes;
            _isMidiLoading = false;
          });

          print('MIDI 파싱 완료, 노트 개수: ${notes.length}');

          // MIDI 노트 샘플 출력 (처음 5개)
          if (notes.isNotEmpty) {
            print('=== MIDI 노트 샘플 (처음 5개) ===');
            for (int i = 0; i < notes.length.clamp(0, 5); i++) {
              final note = notes[i];
              print(
                '노트 ${i + 1}: 시작=${note.startTime.toStringAsFixed(2)}s, '
                '길이=${note.duration.toStringAsFixed(2)}s, '
                '음정=${note.pitch} (${_midiNoteToName(note.pitch)}), '
                '높이=${note.visualPitch.toStringAsFixed(1)}px',
              );
            }
            print('===============================');
          }

          // MIDI 노트에서 전체 길이 계산
          if (notes.isNotEmpty) {
            double maxEndTime = notes
                .map((note) => note.startTime + note.duration)
                .reduce(max);
            if (maxEndTime > totalDuration) {
              setState(() {
                totalDuration = maxEndTime;
              });
            }
          }
        }
      } else {
        print('MIDI 파일 다운로드 실패 (${response.statusCode}): $midiUrl');
        setState(() {
          _isMidiLoading = false;
        });
      }
    } catch (e) {
      print('MIDI 파일 로드 실패: $e');
      setState(() {
        _isMidiLoading = false;
      });
    }
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

    if (_isInstPlaying) {
      _instPlayer!.pause();
      _stopMainTimer();
    } else {
      _instPlayer!.resume();
      _startMainTimer();
    }

    setState(() {
      isPlaying = !isPlaying;
    });
  }

  void _onSeek(double value) {
    if (!mounted) return;

    final newPosition = Duration(
      milliseconds: (value * totalDuration * 1000).toInt(),
    );
    _instPlayer!.seek(newPosition);

    setState(() {
      progress = value;
      // 가사 인덱스 갱신
      for (int i = 0; i < lyricLines.length; i++) {
        if (progress * totalDuration >= lyricLines[i].time) {
          currentLyricIndex = i;
        }
      }
    });
  }

  // 점수 계산 메서드
  void _calculateScores() {
    // 실제 녹음 여부 확인 (현재는 임시로 true로 설정)
    _hasRecording = true; // TODO: 실제 녹음 데이터 확인 로직 추가

    if (_hasRecording) {
      // 임시 점수 계산 (실제로는 녹음 데이터 분석 결과 사용)
      _pitchScore = Random().nextInt(40) + 60; // 60-100점
      _rhythmScore = Random().nextInt(40) + 60; // 60-100점
      _totalScore = ((_pitchScore + _rhythmScore) / 2).round();

      // 추천곡 생성 (실제로는 사용자 음역대 분석 결과 사용)
      _recommendedSongs = [
        '아이유 - Blueming',
        'NewJeans - Hype Boy',
        'LE SSERAFIM - UNFORGIVEN',
        'IVE - I AM',
        'aespa - Spicy',
      ];
    } else {
      _pitchScore = 0;
      _rhythmScore = 0;
      _totalScore = 0;
      _recommendedSongs = [];
    }
  }

  // 점수 페이지로 이동
  void _navigateToScorePage() {
    // Song 객체 안전하게 가져오기
    final song = ModalRoute.of(context)?.settings.arguments as Song?;
    if (song == null) {
      print('Song 객체가 null입니다. 점수 페이지 이동을 건너뜁니다.');
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ScorePage(
          song: song,
          pitchScore: _pitchScore,
          rhythmScore: _rhythmScore,
          totalScore: _totalScore,
          recommendedSongs: _recommendedSongs,
          hasRecording: _hasRecording,
        ),
      ),
    );
  }

  void _onRecordButtonPressed() async {
    if (!isRecording) {
      // 녹음 시작 - inst 파일을 처음부터 다시 재생
      List<double> originalPitch = [440.0, 442.0, 445.0];
      List<double> originalOnsets = [0.0, 1.0, 2.0];

      await AudioComparePlugin.startAnalysis({
        'originalPitch': originalPitch,
        'originalOnsets': originalOnsets,
        'sampleRate': 44100,
      });

      // TensorDSP 실시간 분석 시작
      await TensorDspService.initialize();
      await TensorDspService.startRealTimeAnalysis();

      // inst 파일을 처음부터 다시 재생
      if (_instPlayer != null) {
        await _instPlayer!.seek(Duration.zero); // 처음으로 이동
        await _instPlayer!.resume();
        _startMainTimer(); // 타이머도 함께 시작

        // 진행률과 가사 인덱스 초기화
        setState(() {
          progress = 0.0;
          currentLyricIndex = 0;
        });
      }

      setState(() {
        isRecording = true;
        isPlaying = true;
      });
    } else {
      // 녹음 중지와 동시에 inst 파일 일시정지
      await AudioComparePlugin.stopAnalysis();
      await TensorDspService.stopRealTimeAnalysis();

      // inst 파일 일시정지
      if (_instPlayer != null && _isInstPlaying) {
        await _instPlayer!.pause();
        _stopMainTimer(); // 타이머도 함께 중지
      }

      setState(() {
        isRecording = false;
        isPlaying = false;
      });
    }
  }

  @override
  void dispose() {
    _stopMainTimer();
    mainTimer = null;
    _instPlayer?.dispose();
    _onsetSub?.cancel();
    _tensorDspTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Center(child: CircularProgressIndicator());
    final Song? song = ModalRoute.of(context)?.settings.arguments as Song?;
    if (song == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F7FF),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: const Color(0xFF8B5CF6),
                ),
                SizedBox(height: 16),
                Text(
                  '노래 정보를 찾을 수 없습니다',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '홈으로 돌아가서 다시 시도해주세요',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('홈으로 돌아가기'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final double barAreaWidth = MediaQuery.of(context).size.width * 0.92;
    final double barAreaHeight = 54; // 시각화 영역 높이
    final double leftPadding = 24;
    final double centerLineX = barAreaWidth * 0.35; // 기준선을 좀 더 오른쪽으로
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
                          '$currentScore/100',
                          key: ValueKey(currentScore),
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
            // MIDI 노트 시각화 + 세로 기준선
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
                  // MIDI 로딩 중 표시
                  if (_isMidiLoading)
                    Positioned(
                      left: centerLineX - 20,
                      top: barAreaHeight / 2 - 10,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                  // MIDI 노트들 (실제 MIDI 파일에서 파싱된 노트들)
                  if (!_isMidiLoading && midiNotes.isNotEmpty)
                    ...midiNotes.map(
                      (note) => _MidiNoteWidget(
                        note: note,
                        progress: progress,
                        totalDuration: totalDuration,
                        barAreaWidth: barAreaWidth,
                        barAreaHeight: barAreaHeight,
                        centerLineX: centerLineX,
                        currentTime: currentTime,
                        onPassed: (accuracy) {
                          // 실시간 노래 입력이 없으므로 점수 변화 비활성화
                          // if (!mounted) return;
                          // setState(() {
                          //   int delta = 0;
                          //   switch (accuracy) {
                          //     case _Accuracy.Perfect:
                          //       delta = 5;
                          //       break;
                          //     case _Accuracy.Great:
                          //       delta = 3;
                          //       break;
                          //     case _Accuracy.Good:
                          //       delta = 0;
                          //       break;
                          //     case _Accuracy.Normal:
                          //       delta = -3;
                          //       break;
                          //     case _Accuracy.Bad:
                          //       delta = -5;
                          //       break;
                          //   }
                          //   score = max(0, score + delta);
                          //   pointDelta = delta;
                          // });
                        },
                      ),
                    ),
                  // MIDI 로드 실패 시 기본 멜로디 바 표시
                  if (!_isMidiLoading && midiNotes.isEmpty)
                    ...melodyBars.map(
                      (bar) => _MelodyBarWidget(
                        bar: bar,
                        progress: progress,
                        totalDuration: totalDuration,
                        barAreaWidth: barAreaWidth,
                        barAreaHeight: barAreaHeight,
                        centerLineX: centerLineX,
                        onPassed: (accuracy) {
                          // 실시간 노래 입력이 없으므로 점수 변화 비활성화
                          // if (!mounted) return;
                          // setState(() {
                          //   int delta = 0;
                          //   switch (accuracy) {
                          //     case _Accuracy.Perfect:
                          //       delta = 5;
                          //       break;
                          //     case _Accuracy.Great:
                          //       delta = 3;
                          //       break;
                          //     case _Accuracy.Good:
                          //       delta = 0;
                          //       break;
                          //     case _Accuracy.Normal:
                          //       delta = -3;
                          //       break;
                          //     case _Accuracy.Bad:
                          //       delta = -5;
                          //       break;
                          //   }
                          //   score = max(0, score + delta);
                          //   pointDelta = delta;
                          // });
                        },
                        currentTime: currentTime,
                        enableGradient: false,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 18),
            // 중앙 가사 영역 - 상자로 감싸고 긴 문장 처리
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
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
                child: Center(
                  child: _LyricSliderN(
                    lyricLines: lyricLines,
                    currentIndex: currentLyricIndex,
                    visibleCount: 9, // 상자 안에 맞게 줄 수 조정
                    onTap: (idx) {
                      if (!mounted) return;
                      setState(() {
                        currentLyricIndex = idx;
                        progress = lyricLines[idx].time / totalDuration;
                      });
                    },
                  ),
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
                        _formatTime(progress * totalDuration),
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
                        onTap: _onRecordButtonPressed,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isInstLoading)
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Icon(
                                isRecording
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            SizedBox(width: 10),
                            Text(
                              isRecording ? '연주 중지' : '녹음하며 연주',
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
                  SizedBox(height: 16),
                  // --- 실시간 점수 텍스트 제거 (하단)
                  // Text(
                  //   '실시간 점수: {currentScore.toStringAsFixed(1)}',
                  //   style: TextStyle(
                  //     fontSize: 16,
                  //     fontWeight: FontWeight.w600,
                  //     color: const Color(0xFF8B5CF6),
                  //   ),
                  // ),
                  // --- 퍼펙트 스코어 박스 전체 제거 ---
                  // SizedBox(height: 16),
                  // Container(
                  //   padding: const EdgeInsets.all(16),
                  //   decoration: BoxDecoration(
                  //     color: Colors.white,
                  //     borderRadius: BorderRadius.circular(16),
                  //     boxShadow: [
                  //       BoxShadow(
                  //         color: const Color(0xFF8B5CF6).withOpacity(0.08),
                  //         blurRadius: 8,
                  //         offset: const Offset(0, 2),
                  //       ),
                  //     ],
                  //   ),
                  //   child: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.center,
                  //     children: [
                  //       Text(
                  //         '퍼펙트 스코어',
                  //         style: TextStyle(
                  //           fontSize: 18,
                  //           fontWeight: FontWeight.bold,
                  //           color: const Color(0xFF8B5CF6),
                  //         ),
                  //       ),
                  //       SizedBox(height: 8),
                  //       Text(
                  //         '실시간 점수: {currentScore.toStringAsFixed(1)}',
                  //         style: TextStyle(
                  //           fontSize: 24,
                  //           fontWeight: FontWeight.w800,
                  //           color: const Color(0xFF8B5CF6),
                  //         ),
                  //       ),
                  //       SizedBox(height: 8),
                  //       // 피치 그래프 (간단한 Polyline)
                  //       SizedBox(
                  //         height: 60,
                  //         width: double.infinity,
                  //         child: CustomPaint(
                  //           painter: _PitchGraphPainter(_pitchHistory),
                  //           child: Container(),
                  //         ),
                  //       ),
                  //       SizedBox(height: 8),
                  //       // 온셋 바 (최근 온셋 시각화)
                  //       Row(
                  //         mainAxisAlignment: MainAxisAlignment.center,
                  //         children: _onsetHistory
                  //             .map(
                  //               (onset) => Container(
                  //                 margin: const EdgeInsets.symmetric(horizontal: 2),
                  //                 width: 8,
                  //                 height: 24,
                  //                 decoration: BoxDecoration(
                  //                   color: const Color(0xFF8B5CF6),
                  //                   borderRadius: BorderRadius.circular(4),
                  //                 ),
                  //               ),
                  //             )
                  //             .toList(),
                  //       ),
                  //       SizedBox(height: 8),
                  //       Text(
                  //         '실시간 피치: {currentPitch.toStringAsFixed(1)} Hz',
                  //         style: TextStyle(fontSize: 14, color: Colors.black87),
                  //       ),
                  //       Text(
                  //         '실시간 온셋: {currentOnset.toStringAsFixed(2)} s',
                  //         style: TextStyle(fontSize: 14, color: Colors.black54),
                  //       ),
                  //     ],
                  //   ),
                  // ),
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

  // Inst 파일 재생 함수 (S3에서 로드)
  Future<void> _playInst() async {
    if (_instPlayer != null) {
      await _instPlayer!.resume();
    }
  }

  // MIDI 노트 번호를 음계 이름으로 변환하는 헬퍼 함수
  String _midiNoteToName(int midiNote) {
    const List<String> noteNames = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    int octave = (midiNote ~/ 12) - 1;
    String noteName = noteNames[midiNote % 12];
    return '$noteName$octave';
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
          maxLines: 2, // 최대 2줄까지 허용
          overflow: TextOverflow.visible, // 잘림 방지
          softWrap: true, // 자동 줄바꿈 활성화
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
      'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/album_cover/${safeArtist}_$safeTitle.jpg',
      'https://ai-vocal-training.s3.ap-northeast-2.amazonaws.com/album_cover/${artist}_$title.jpg',
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

// --- 피치 그래프용 CustomPainter ---
class _PitchGraphPainter extends CustomPainter {
  final List<double> pitchHistory;
  _PitchGraphPainter(this.pitchHistory);

  @override
  void paint(Canvas canvas, Size size) {
    if (pitchHistory.isEmpty) return;
    final paint = Paint()
      ..color = const Color(0xFF8B5CF6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    double minPitch = pitchHistory.reduce((a, b) => a < b ? a : b);
    double maxPitch = pitchHistory.reduce((a, b) => a > b ? a : b);
    if (minPitch == maxPitch) {
      minPitch -= 1;
      maxPitch += 1;
    }
    for (int i = 0; i < pitchHistory.length; i++) {
      final x = i * size.width / (pitchHistory.length - 1);
      final y =
          size.height -
          ((pitchHistory[i] - minPitch) / (maxPitch - minPitch)) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PitchGraphPainter oldDelegate) {
    return oldDelegate.pitchHistory != pitchHistory;
  }
}

// --- END ---
