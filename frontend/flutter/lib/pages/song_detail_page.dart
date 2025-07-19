import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import '../models/song.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import '../services/s3_service.dart';
import '../services/vocal_range_service.dart';

class SongDetailPage extends StatefulWidget {
  final Map<String, String> songData;

  const SongDetailPage({super.key, required this.songData});

  @override
  State<SongDetailPage> createState() => _SongDetailPageState();
}

class _SongDetailPageState extends State<SongDetailPage> {
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  File? _uploadedFile;
  bool _isUploading = false;
  VocalRangeAnalysis? _vocalRangeAnalysis;
  bool _isAnalyzingVocalRange = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
    
    // 페이지 로드 시 음역대 분석 시작
    _analyzeVocalRange();
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  /// 음역대 분석을 수행합니다.
  Future<void> _analyzeVocalRange() async {
    final songData = widget.songData;
    final title = songData['title'] ?? '';
    final artist = songData['artist'] ?? '';

    if (title.isEmpty || artist.isEmpty) {
      return;
    }

    setState(() {
      _isAnalyzingVocalRange = true;
    });

    try {
      final analysis = await VocalRangeService.analyzeVocalRangeSafe(title, artist);
      setState(() {
        _vocalRangeAnalysis = analysis;
        _isAnalyzingVocalRange = false;
      });
    } catch (e) {
      setState(() {
        _isAnalyzingVocalRange = false;
      });
      print('음역대 분석 오류: $e');
    }
  }

  Future<void> _uploadSongFile() async {
    try {
      setState(() {
        _isUploading = true;
      });

      // 파일 선택 (오디오 파일만)
      final XFile? file = await _picker.pickMedia(
        imageQuality: 100,
        requestFullMetadata: false,
      );

      if (file == null) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      // 파일 확장자 확인 (오디오 파일만 허용)
      final String extension = file.path.split('.').last.toLowerCase();
      final List<String> allowedExtensions = ['mp3', 'wav', 'm4a', 'aac', 'ogg'];
      
      if (!allowedExtensions.contains(extension)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('오디오 파일만 업로드 가능합니다. (mp3, wav, m4a, aac, ogg)'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isUploading = false;
        });
        return;
      }

      // 파일 크기 확인 (50MB 이하)
      final File audioFile = File(file.path);
      final int fileSizeInBytes = await audioFile.length();
      final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);
      
      if (fileSizeInMB > 50) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('파일 크기는 50MB 이하여야 합니다.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isUploading = false;
        });
        return;
      }

      setState(() {
        _uploadedFile = audioFile;
        _isUploading = false;
      });

      // 업로드 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('파일이 성공적으로 업로드되었습니다: ${file.name}'),
          backgroundColor: const Color(0xFF8B5CF6),
        ),
      );

      // TODO: 실제 서버 업로드 로직 구현
      // await _uploadToServer(audioFile);

    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('파일 업로드 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _playOriginalSong() async {
    final songData = widget.songData;
    final artist = songData['artist'] ?? '';
    final title = songData['title'] ?? '';

    if (artist.isEmpty || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('곡 정보가 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final songUrl = S3Service.getOriginalSongUrl(artist, title);
      print('Generated S3 URL: $songUrl'); // 디버깅용 로그
      
      if (_isPlaying) {
        await _audioPlayer!.stop();
      } else {
        await _audioPlayer!.play(UrlSource(songUrl));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오디오 재생 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final songData = widget.songData;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: Stack(
        children: [
          // 메인 콘텐츠
          CustomScrollView(
            slivers: [
              // 커스텀 앱바
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                pinned: true,
                backgroundColor: const Color(0xFFF8F7FF),
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
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
                      Icons.arrow_back_ios_rounded,
                      size: 20,
                      color: const Color(0xFF6B46C1),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

              // 메인 콘텐츠
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // 앨범 아트 (더 큰 크기, 부드러운 그림자)
                      Center(
                        child: Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF8B5CF6,
                                ).withOpacity(0.15),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: _buildAlbumCover(songData['image'] ?? ''),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 곡 정보 (더 세련된 타이포그래피)
                      Center(
                        child: Column(
                          children: [
                            Text(
                              songData['artist'] ?? '',
                              style: TextStyle(
                                fontSize: 18,
                                color: const Color(0xFF8B5CF6),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              songData['title'] ?? '',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1F2937),
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 태그 (더 세련된 디자인)
                      Center(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (_isAnalyzingVocalRange)
                              _buildTag('음역대 분석 중...', const Color(0xFFE0E7FF))
                            else if (_vocalRangeAnalysis != null)
                              _buildTag(_vocalRangeAnalysis!.totalRange, const Color(0xFFE0E7FF))
                            else
                              _buildTag('음역대 분석 실패', const Color(0xFFFEE2E2)),
                            if (_isAnalyzingVocalRange)
                              _buildDifficultyTag('분석 중')
                            else if (_vocalRangeAnalysis != null)
                              _buildDifficultyTag(_vocalRangeAnalysis!.difficulty)
                            else
                              _buildDifficultyTag('분석 실패'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 업로드된 파일 정보 표시
                      if (_uploadedFile != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF8B5CF6).withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.music_note_rounded,
                                    color: const Color(0xFF8B5CF6),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '업로드된 파일',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF8B5CF6),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _uploadedFile!.path.split('/').last,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: const Color(0xFF10B981),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '업로드 완료',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(0xFF10B981),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _uploadedFile = null;
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('업로드된 파일이 제거되었습니다.'),
                                          backgroundColor: Color(0xFF8B5CF6),
                                        ),
                                      );
                                    },
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: const Color(0xFF6B7280),
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 퀵 액션 버튼들 (더 세련된 디자인)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            GestureDetector(
                              onTap: _uploadSongFile,
                              child: _buildQuickAction(
                                _isUploading ? Icons.upload_file_rounded : Icons.upload_rounded,
                                _isUploading ? '업로드 중...' : '노래 파일 올리기',
                              ),
                            ),
                            _buildQuickAction(
                              Icons.history_rounded,
                              '피드백 히스토리',
                            ),
                            GestureDetector(
                              onTap: () {
                                final song = Song(
                                  title: songData['title'] ?? '',
                                  artist: songData['artist'] ?? '',
                                  albumCover: songData['image'] ?? '',
                                  difficulty: '분석 예정',
                                  range: '분석 예정',
                                  lyrics: songData['lyrics'] ?? '',
                                  duration: '분석 예정',
                                );
                                Navigator.pushNamed(
                                  context,
                                  '/ai-vocal-loading',
                                  arguments: song,
                                );
                              },
                              child: _buildQuickAction(
                                Icons.graphic_eq_rounded,
                                'AI 보컬 합성',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 메인 액션 버튼들 (연보라색 테마)
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF8B5CF6,
                                    ).withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: _isLoading ? null : _playOriginalSong,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isLoading)
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
                                          _isPlaying 
                                            ? Icons.pause_rounded 
                                            : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _isLoading 
                                          ? '로딩 중...' 
                                          : (_isPlaying ? '일시정지' : '전체 듣기'),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFE0E7FF),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF8B5CF6,
                                    ).withOpacity(0.1),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {},
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.favorite_border_rounded,
                                        color: const Color(0xFF8B5CF6),
                                        size: 28,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '즐겨찾기',
                                        style: TextStyle(
                                          color: const Color(0xFF8B5CF6),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // 음역대 분석 결과 섹션
                      if (_vocalRangeAnalysis != null && _vocalRangeAnalysis!.analysisStatus == 'completed') ...[
                        _buildSectionTitle('음역대 분석'),
                        const SizedBox(height: 20),
                        
                        // 음역대 분석 결과 카드
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.graphic_eq_rounded,
                                    color: const Color(0xFF8B5CF6),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '음역대 분석 결과',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF8B5CF6),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // 전체 음역대
                              _buildRangeInfo('전체 음역대', _vocalRangeAnalysis!.totalRange, Icons.music_note_rounded),
                              const SizedBox(height: 12),
                              
                              // 편안한 음역대
                              _buildRangeInfo('편안한 음역대', _vocalRangeAnalysis!.comfortableRange, Icons.favorite_rounded),
                              const SizedBox(height: 12),
                              
                              // 핵심 음역대
                              _buildRangeInfo('핵심 음역대', _vocalRangeAnalysis!.coreRange, Icons.star_rounded),
                              const SizedBox(height: 16),
                              
                              // 난이도
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getDifficultyColor(_vocalRangeAnalysis!.difficulty).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getDifficultyColor(_vocalRangeAnalysis!.difficulty).withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  '난이도: ${_vocalRangeAnalysis!.difficulty}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _getDifficultyColor(_vocalRangeAnalysis!.difficulty),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],

                      // Cover Song 섹션
                      _buildSectionTitle('Cover Song'),
                      const SizedBox(height: 20),

                      // Cover Song 카드 (연보라색 테마)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.grey[200],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: _buildAlbumCover(
                                  songData['image'] ?? '',
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    songData['title'] ?? '',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${songData['artist']} • Cover Version',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: const Color(0xFF8B5CF6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.play_circle_outline_rounded,
                              color: const Color(0xFF8B5CF6),
                              size: 36,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 가사 섹션
                      _buildSectionTitle('가사'),
                      const SizedBox(height: 20),

                      // 가사 (완전한 중앙 정렬)
                      Center(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _formatLyrics(songData['lyrics'] ?? '가사 정보가 없습니다.'),
                            style: TextStyle(
                              height: 2.0,
                              fontSize: 16,
                              color: const Color(0xFF374151),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 하단 녹음 버튼 (연보라색 테마)
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    final song = Song(
                      title: songData['title'] ?? '',
                      artist: songData['artist'] ?? '',
                      albumCover: songData['image'] ?? '',
                      difficulty: '분석 예정',
                      range: '분석 예정',
                      lyrics: songData['lyrics'] ?? '',
                      duration: '분석 예정',
                    );
                    Navigator.pushNamed(context, '/record', arguments: song);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mic_rounded, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        '녹음하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCover(String imagePath) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.music_note, color: Colors.grey[400], size: 80),
          );
        },
      );
    } else {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.music_note, color: Colors.grey[400], size: 80),
          );
        },
      );
    }
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B46C1),
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0E7FF)),
          ),
          child: Icon(icon, size: 28, color: const Color(0xFF8B5CF6)),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B46C1),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1F2937),
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildDifficultyTag(String difficulty) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (difficulty.toLowerCase()) {
      case '초급':
      case 'beginner':
        backgroundColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF166534);
        icon = Icons.star_rounded;
        break;
      case '중급':
      case 'intermediate':
        backgroundColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        icon = Icons.star_rounded;
        break;
      case '고급':
      case 'advanced':
        backgroundColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        icon = Icons.star_rounded;
        break;
      default:
        backgroundColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF6B7280);
        icon = Icons.star_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 6),
          Text(
            difficulty,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 음역대 정보를 표시하는 위젯
  Widget _buildRangeInfo(String label, String range, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF8B5CF6)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
        Text(
          range,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  /// 난이도에 따른 색상을 반환합니다.
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case '초급':
        return const Color(0xFF10B981);
      case '중급':
        return const Color(0xFFF59E0B);
      case '고급':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  /// 가사에 줄바꿈을 추가하는 함수
  /// 문장 끝에 마침표, 느낌표, 물음표가 있으면 줄바꿈을 추가합니다.
  String _formatLyrics(String lyrics) {
    if (lyrics.isEmpty || lyrics == '가사 정보가 없습니다.') {
      return lyrics;
    }

    // 문장 끝 부호들 (마침표, 느낌표, 물음표) 뒤에 줄바꿈 추가
    String formattedLyrics = lyrics
        .replaceAll('. ', '.\n')
        .replaceAll('! ', '!\n')
        .replaceAll('? ', '?\n')
        .replaceAll('。 ', '。\n') // 일본어/한국어 마침표
        .replaceAll('！ ', '！\n') // 일본어/한국어 느낌표
        .replaceAll('？ ', '？\n'); // 일본어/한국어 물음표

    // 마지막 문장도 줄바꿈 처리
    if (formattedLyrics.endsWith('.') ||
        formattedLyrics.endsWith('!') ||
        formattedLyrics.endsWith('?') ||
        formattedLyrics.endsWith('。') ||
        formattedLyrics.endsWith('！') ||
        formattedLyrics.endsWith('？')) {
      formattedLyrics += '\n';
    }

    return formattedLyrics;
  }
}
