import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/s3_service.dart';
import '../main.dart'; // CurrentUser 사용을 위해
import 'user_recording_play_page.dart'; // 재생 페이지 import 추가
import '../services/api_config_service.dart'; // ApiConfigService 추가
import '../services/score_service.dart'; // ScoreService 추가

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with WidgetsBindingObserver {
  List<Map<String, dynamic>> userUploads = [];
  bool isLoading = true;
  String? currentUserId;
  Timer? _autoRefreshTimer;
  bool _isPageActive = true;

  // WebSocket 관련 변수
  WebSocketChannel? _channel;
  bool _isWebSocketConnected = false;

  // 점수 그래프 관련 변수
  List<Map<String, dynamic>> scoreGraphData = [];
  bool isScoreLoading = false;
  double? avgScore;
  double? maxScore;
  double? minScore;

  // 위젯 dispose 상태 추적
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserUploads();
    _loadScoreGraphData(); // 점수 그래프 데이터 로드 추가
    _startAutoRefresh();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _isDisposed = true; // dispose 상태 추적
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _disconnectWebSocket();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (mounted && !_isDisposed) {
      setState(() {
        _isPageActive = state == AppLifecycleState.resumed;
      });
    }

    if (state == AppLifecycleState.resumed) {
      // 앱이 포커스를 받으면 즉시 새로고침
      _loadUserUploads();
      _connectWebSocket();
    } else if (state == AppLifecycleState.paused) {
      // 앱이 백그라운드로 가면 WebSocket 연결 해제
      _disconnectWebSocket();
    }
  }

  void _startAutoRefresh() {
    // 30초마다 자동 새로고침 (페이지가 활성화된 경우에만)
    _autoRefreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isPageActive && mounted) {
        print('🔄 자동 새로고침 실행...');
        _loadUserUploads();
      }
    });
  }

  // WebSocket 연결
  void _connectWebSocket() async {
    if (currentUserId == null) return;

    try {
      final baseUrl = await ApiConfigService.baseUrl;
      final wsUrl =
          'ws://${baseUrl.replaceFirst('http://', '')}/ws/$currentUserId';
      print('🔗 WebSocket 연결 시도: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isWebSocketConnected = true;

      // 메시지 수신 리스너
      _channel!.stream.listen(
        (message) {
          print('📨 WebSocket 메시지 수신: $message');
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          print('❌ WebSocket 오류: $error');
          _isWebSocketConnected = false;
          // 재연결 시도
          Timer(Duration(seconds: 5), () {
            if (mounted && _isPageActive) {
              _connectWebSocket();
            }
          });
        },
        onDone: () {
          print('🔌 WebSocket 연결 종료');
          _isWebSocketConnected = false;
        },
      );

      print('✅ WebSocket 연결 성공');
    } catch (e) {
      print('❌ WebSocket 연결 실패: $e');
      _isWebSocketConnected = false;
    }
  }

  // WebSocket 연결 해제
  void _disconnectWebSocket() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
      _isWebSocketConnected = false;
      print('🔌 WebSocket 연결 해제');
    }
  }

  // WebSocket 메시지 처리
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString());

      if (data['type'] == 'file_update') {
        final fileInfo = data['data'];
        print('🆕 새로운 파일 업데이트 알림: $fileInfo');

        // UI 업데이트
        if (mounted && !_isDisposed) {
          setState(() {
            // 새 파일을 목록 맨 앞에 추가
            userUploads.insert(0, {
              'key': fileInfo['key'],
              'filename': fileInfo['filename'],
              'song_title': fileInfo['song_title'],
              'artist': fileInfo['artist'],
              'type': fileInfo['type'],
              'timestamp': fileInfo['timestamp'],
            });
          });

          // 알림 표시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('새로운 Cover Song이 추가되었습니다!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
              action: SnackBarAction(
                label: '확인',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ WebSocket 메시지 처리 오류: $e');
    }
  }

  Future<void> _loadUserUploads() async {
    if (!mounted || _isDisposed) return;

    if (mounted && !_isDisposed) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      // 현재 로그인된 사용자 ID 가져오기
      currentUserId = CurrentUser.getUserNickname();

      // 디버깅을 위한 상세 로그
      print('🔍 마이페이지 Cover Song 로드 디버깅:');
      print('  - 현재 사용자 ID: $currentUserId');
      print('  - 사용자 ID가 null인가? ${currentUserId == null}');

      if (currentUserId == null) {
        // 테스트용으로 '테스트사용자' ID 사용
        currentUserId = '테스트사용자';
        print('  - 테스트 사용자로 설정: $currentUserId');
      }

      // 사용자의 업로드된 파일 목록 가져오기
      print('  - API 호출 시작: S3Service.getUserUploads($currentUserId)');
      final uploads = await S3Service.getUserUploads(currentUserId!);

      print('  - API 응답 받음: ${uploads.length}개 파일');
      if (uploads.isNotEmpty) {
        print('  - 파일 목록:');
        for (var upload in uploads) {
          print(
            '    * ${upload['artist']} - ${upload['song_title']} (${upload['type']})',
          );
        }
      } else {
        print('  - 업로드된 파일이 없습니다.');
      }

      if (mounted && !_isDisposed) {
        setState(() {
          userUploads = uploads;
          isLoading = false;
        });

        // 새로고침 완료 알림 (새 파일이 있는 경우)
        if (uploads.isNotEmpty) {
          print('✅ Cover Song 목록 업데이트 완료: ${uploads.length}개 파일');
        } else {
          print('⚠️ Cover Song 목록이 비어있습니다. S3 버킷과 파일 경로를 확인해주세요.');
        }
      }
    } catch (e) {
      print('❌ 사용자 업로드 파일 로드 실패: $e');
      print('❌ 오류 상세 정보: ${e.runtimeType}');
      if (mounted && !_isDisposed) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // 수동 새로고침 함수
  Future<void> _refreshData() async {
    print('🔄 수동 새로고침 시작...');
    await _loadUserUploads();
    await _loadScoreGraphData(); // 점수 데이터도 새로고침

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('데이터가 새로고침되었습니다.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 점수 그래프 데이터 로드
  Future<void> _loadScoreGraphData() async {
    if (!mounted) return;

    // 안전한 setState 호출을 위한 헬퍼 함수
    void safeSetState(VoidCallback fn) {
      if (mounted && !_isDisposed) {
        setState(fn);
      }
    }

    safeSetState(() {
      isScoreLoading = true;
    });

    try {
      // 현재 사용자 ID가 없으면 테스트 사용자로 시도
      final userId = currentUserId ?? '테스트사용자';

      print('📈 점수 그래프 데이터 로드 시작: $userId');

      // 테스트용 API 호출 (최근 10개 곡만 가져오기)
      final result = await ScoreService.getTestScoreGraphData(
        userId: userId,
        days: 30,
        limit: 10,
      );

      // 비동기 작업 후 위젯 상태 재확인
      if (!mounted || _isDisposed) return;

      if (result['success']) {
        final data = result['data'];
        final dataPoints = data['data'] ?? [];

        safeSetState(() {
          scoreGraphData = List<Map<String, dynamic>>.from(dataPoints);

          if (scoreGraphData.isNotEmpty) {
            final scores = scoreGraphData
                .map((point) => point['score'] as double)
                .toList();
            avgScore = scores.reduce((a, b) => a + b) / scores.length;
            maxScore = scores.reduce((a, b) => a > b ? a : b);
            minScore = scores.reduce((a, b) => a < b ? a : b);
          } else {
            avgScore = null;
            maxScore = null;
            minScore = null;
          }

          isScoreLoading = false;
        });

        print('✅ 점수 그래프 데이터 로드 성공: ${scoreGraphData.length}개 데이터');
      } else {
        safeSetState(() {
          scoreGraphData = [];
          avgScore = null;
          maxScore = null;
          minScore = null;
          isScoreLoading = false;
        });
        print('❌ 점수 그래프 데이터 로드 실패: ${result['error']}');
      }
    } catch (e) {
      print('❌ 점수 그래프 데이터 로드 중 오류: $e');
      safeSetState(() {
        scoreGraphData = [];
        avgScore = null;
        maxScore = null;
        minScore = null;
        isScoreLoading = false;
      });
    }
  }

  void _navigateToPlayPage(Map<String, dynamic> upload) {
    print('🎵 재생 페이지로 이동:');
    print('  - 노래 제목: ${upload['song_title']}');
    print('  - 아티스트: ${upload['artist']}');
    print('  - 오디오 URL: ${upload['url']}');
    print('  - 파일 타입: ${upload['type']}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserRecordingPlayPage(
          songTitle: upload['song_title'] ?? 'Unknown Song',
          artist: upload['artist'] ?? 'Unknown Artist',
          audioUrl: upload['url'] ?? '',
          albumCoverUrl: '', // 앨범 커버 URL은 재생 페이지에서 다시 가져올 예정
        ),
      ),
    ).then((_) {
      // 재생 페이지에서 돌아오면 목록 새로고침
      _loadUserUploads();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 새로고침 버튼 추가
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 프로필 섹션
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.purple.shade100,
                      child: Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.purple.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUserId ?? '사용자',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(
                                  '#보컬트레이너',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(
                                  '#감성보컬',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.purple.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 점수 통계 섹션
                _buildScoreStatsSection(),

                const SizedBox(height: 24),
                // Cover Song 섹션
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cover Song',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        if (isLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        const SizedBox(width: 8),
                        // 실시간 업데이트 상태 표시
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isPageActive
                                ? Colors.green.shade50
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _isPageActive
                                      ? Colors.green
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isPageActive ? '실시간' : '대기',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _isPageActive
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // WebSocket 연결 상태 표시
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isWebSocketConnected
                                ? Colors.blue.shade50
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _isWebSocketConnected
                                      ? Colors.blue
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isWebSocketConnected ? '연결' : '연결안됨',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _isWebSocketConnected
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('업로드된 파일을 불러오는 중...'),
                    ),
                  )
                else if (userUploads.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        '아직 업로드된 파일이 없습니다.\n노래를 녹음하거나 파일을 업로드해보세요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: userUploads.length,
                      itemBuilder: (context, index) {
                        final upload = userUploads[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () {
                              _navigateToPlayPage(upload);
                            },
                            child: _songTileWithAlbumCover(
                              upload['song_title'] ?? 'Unknown Song',
                              upload['artist'] ?? 'Unknown Artist',
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 24),
                // 설정 섹션
                const Text(
                  '설정',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(Icons.settings, color: Colors.grey.shade600),
                  title: const Text('앱 설정'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // 설정 페이지로 이동
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.help_outline,
                    color: Colors.grey.shade600,
                  ),
                  title: const Text('도움말'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // 도움말 페이지로 이동
                  },
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red.shade600),
                  title: const Text('로그아웃'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // 로그아웃 처리
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _songTileWithAlbumCover(String title, String artist) {
    return FutureBuilder<String?>(
      future: S3Service.getAlbumCoverUrlByTitle(title),
      builder: (context, snapshot) {
        String imageUrl = '';
        if (snapshot.hasData && snapshot.data != null) {
          imageUrl = snapshot.data!;
        }

        print('🎵 앨범 커버 디버깅 (백엔드 API):');
        print('  - 제목: $title');
        print('  - 이미지 URL: $imageUrl');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('❌ 앨범 커버 로드 실패: $error');
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.grey,
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.music_note, color: Colors.grey),
                    ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 100,
              child: Text(
                title,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        );
      },
    );
  }

  // 점수 통계 섹션 빌드
  Widget _buildScoreStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '나의 점수 변화',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (isScoreLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 점수 통계 카드들
          if (scoreGraphData.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: _buildScoreCard(
                    '평균 점수',
                    avgScore?.toStringAsFixed(1) ?? '0',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildScoreCard(
                    '최고 점수',
                    maxScore?.toStringAsFixed(1) ?? '0',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildScoreCard(
                    '최저 점수',
                    minScore?.toStringAsFixed(1) ?? '0',
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 간단한 점수 변화 그래프 (선 그래프 형태)
            _buildSimpleScoreChart(),

            const SizedBox(height: 12),
            Text(
              '최근 ${scoreGraphData.take(10).length}회 연습 기록 (최대 10회)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ] else ...[
            Container(
              height: 100,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '아직 연습 기록이 없습니다',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '노래를 연습하고 점수를 확인해보세요!',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 점수 카드 위젯
  Widget _buildScoreCard(String title, String score, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Color.lerp(color, Colors.black, 0.3),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            score,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color.lerp(color, Colors.black, 0.4),
            ),
          ),
        ],
      ),
    );
  }

  // 선 그래프 (점을 잇는 형태)
  Widget _buildSimpleScoreChart() {
    if (scoreGraphData.isEmpty) return const SizedBox.shrink();

    // 최근 10개 데이터만 사용 (역순으로 정렬하여 최신 순서대로)
    final chartData = scoreGraphData.take(10).toList().reversed.toList();

    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      child: CustomPaint(
        size: const Size(double.infinity, 80),
        painter: LineChartPainter(
          data: chartData.map((item) => item['score'] as double).toList(),
          maxScore: 100,
          minScore: 0,
        ),
      ),
    );
  }
}

// 선 그래프를 그리는 CustomPainter
class LineChartPainter extends CustomPainter {
  final List<double> data;
  final double maxScore;
  final double minScore;

  LineChartPainter({
    required this.data,
    required this.maxScore,
    required this.minScore,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFF8B5CF6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 격자선 그리기 (수평선)
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 데이터 포인트 계산
    final points = <Offset>[];
    final stepX = size.width / (data.length - 1).clamp(1, double.infinity);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedValue = (data[i] - minScore) / (maxScore - minScore);
      final y = size.height * (1 - normalizedValue);
      points.add(Offset(x, y));
    }

    // 선 그리기
    if (points.length > 1) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);

      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }

      canvas.drawPath(path, paint);
    }

    // 점 그리기
    for (int i = 0; i < points.length; i++) {
      final point = points[i];

      // 배경 원 (흰색)
      canvas.drawCircle(
        point,
        4.0,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );

      // 테두리 원
      canvas.drawCircle(
        point,
        4.0,
        Paint()
          ..color = const Color(0xFF8B5CF6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      // 점수 표시 (점 위에)
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${data[i].toInt()}',
          style: const TextStyle(
            color: Color(0xFF8B5CF6),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          point.dx - textPainter.width / 2,
          point.dy - textPainter.height - 8,
        ),
      );

      // X축 라벨 (연습 순서)
      final labelPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}회',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      );

      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(point.dx - labelPainter.width / 2, size.height + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
