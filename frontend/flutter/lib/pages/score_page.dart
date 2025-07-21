import 'package:SingSang/pages/vocal_compare_page.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../models/song.dart';

class ScorePage extends StatefulWidget {
  final Song song;
  final int pitchScore;
  final int rhythmScore;
  final int totalScore;
  final List<String> recommendedSongs;
  final bool hasRecording;

  const ScorePage({
    Key? key,
    required this.song,
    required this.pitchScore,
    required this.rhythmScore,
    required this.totalScore,
    required this.recommendedSongs,
    required this.hasRecording,
  }) : super(key: key);

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> with TickerProviderStateMixin {
  late AnimationController _scoreAnimationController;
  late AnimationController _starAnimationController;
  late Animation<double> _scoreAnimation;
  late Animation<double> _starAnimation;

  @override
  void initState() {
    super.initState();

    _scoreAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _starAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scoreAnimation =
        Tween<double>(
          begin: 0,
          end: widget.hasRecording ? widget.totalScore.toDouble() : 0,
        ).animate(
          CurvedAnimation(
            parent: _scoreAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _starAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _starAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    // 애니메이션 시작
    Future.delayed(const Duration(milliseconds: 500), () {
      _scoreAnimationController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      _starAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _scoreAnimationController.dispose();
    _starAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더
            _buildHeader(),

            // 메인 점수 영역
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // 종합 점수 카드
                    _buildTotalScoreCard(),

                    const SizedBox(height: 24),

                    // 세부 점수 카드들
                    _buildDetailScoreCards(),

                    const SizedBox(height: 24),

                    // 추천곡 카드
                    _buildRecommendationCard(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // 하단 버튼들
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: Color(0xFF8B5CF6),
              size: 24,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '연습 결과',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                Text(
                  widget.song.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 별 아이콘
          AnimatedBuilder(
            animation: _starAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _starAnimation.value,
                child: Icon(Icons.star_rounded, color: Colors.white, size: 48),
              );
            },
          ),

          const SizedBox(height: 16),

          // 점수 텍스트
          AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (context, child) {
              return Text(
                '${_scoreAnimation.value.toInt()}',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              );
            },
          ),

          Text(
            '/ 100',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.8),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            widget.hasRecording ? '훌륭한 연습이었어요!' : '녹음이 없어서 점수를 매길 수 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailScoreCards() {
    return Row(
      children: [
        // 음정 점수 카드
        Expanded(
          child: _buildScoreCard(
            title: '음정',
            score: widget.pitchScore,
            icon: Icons.music_note_rounded,
            color: const Color(0xFF10B981),
            hasRecording: widget.hasRecording,
          ),
        ),

        const SizedBox(width: 12),

        // 박자 점수 카드
        Expanded(
          child: _buildScoreCard(
            title: '박자',
            score: widget.rhythmScore,
            icon: Icons.timer_rounded,
            color: const Color(0xFFF59E0B),
            hasRecording: widget.hasRecording,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCard({
    required String title,
    required int score,
    required IconData icon,
    required Color color,
    required bool hasRecording,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),

          const SizedBox(height: 12),

          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            hasRecording ? '$score' : '0',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),

          Text(
            '/ 100',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.recommend_rounded,
                color: const Color(0xFF8B5CF6),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '추천 곡',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (widget.hasRecording && widget.recommendedSongs.isNotEmpty)
            ...widget.recommendedSongs
                .take(3)
                .map((song) => _buildRecommendationItem(song))
          else
            Text(
              '녹음이 없어서 추천곡을 제공할 수 없어요',
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF6B7280),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String song) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              song,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
          ),

          Icon(
            Icons.play_arrow_rounded,
            color: const Color(0xFF8B5CF6),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 다시 연습하기 버튼
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => VocalComparePage(
                      userId: '사용자ID', // 실제 사용자 ID로 교체 필요
                      songTitle: widget.song.title,
                      artist: widget.song.artist,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                '보컬 비교 하러가기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w200),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 홈으로 돌아가기 버튼
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () {
                // 메인 레이아웃으로 이동하고 홈 탭(인덱스 0)으로 설정
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/main',
                  (route) => false, // 모든 이전 라우트 제거
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                '홈으로 돌아가기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
