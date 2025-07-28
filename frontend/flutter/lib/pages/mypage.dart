import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/s3_service.dart';
import '../main.dart'; // CurrentUser 사용을 위해
import 'user_recording_play_page.dart'; // 재생 페이지 import 추가

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserUploads();
    _startAutoRefresh();
    _connectWebSocket();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _disconnectWebSocket();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    setState(() {
      _isPageActive = state == AppLifecycleState.resumed;
    });

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
  void _connectWebSocket() {
    if (currentUserId == null) return;

    try {
      final wsUrl = 'ws://192.168.0.47:8000/ws/$currentUserId';
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
        if (mounted) {
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
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      // 현재 로그인된 사용자 ID 가져오기
      currentUserId = CurrentUser.getUserNickname();
      if (currentUserId == null) {
        print('❌ 로그인된 사용자 정보가 없습니다.');
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      // 사용자의 업로드된 파일 목록 가져오기
      final uploads = await S3Service.getUserUploads(currentUserId!);
      if (mounted) {
        setState(() {
          userUploads = uploads;
          isLoading = false;
        });

        // 새로고침 완료 알림 (새 파일이 있는 경우)
        if (uploads.isNotEmpty) {
          print('✅ Cover Song 목록 업데이트 완료: ${uploads.length}개 파일');
        }
      }
    } catch (e) {
      print('❌ 사용자 업로드 파일 로드 실패: $e');
      if (mounted) {
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cover Song 목록이 새로고침되었습니다.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
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
                // 점수 변화 그래프
                const Text(
                  '점수 변화 그래프',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      '점수 변화 그래프가 여기에 표시됩니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
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

  Widget _songTile(String title, String imageUrl) => Column(
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
                  return Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.music_note, color: Colors.grey),
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
}
