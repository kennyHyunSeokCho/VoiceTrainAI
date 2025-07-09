import 'package:flutter/material.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile image
              Center(
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/cat.webp',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 대표곡 섹션
              const Text(
                '대표곡',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/cat.webp',
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _smallCover(),
                        const SizedBox(width: 8),
                        _smallCover(),
                        const SizedBox(width: 8),
                        _smallCover(),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 사용자 정보
              const Text(
                'Ab - DS',
                style: TextStyle(color: Colors.purpleAccent),
              ),
              const SizedBox(height: 4),
              const Text(
                '동욱넴',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      // TODO : 대표곡 변경 기능 추가
                    },
                    child: const Text('대표곡 변경'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      // TODO : 공유하기? 넣을거임?
                    },
                    child: const Text('공유하기'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 보컬 스타일
              const Text(
                '보컬 스타일',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  Chip(label: Text('#맑은톤')),
                  Chip(label: Text('#마이웨이톤')),
                  Chip(label: Text('#감성보컬')),
                ],
              ),

              const SizedBox(height: 24),
              // Cover Song 섹션
              const Text(
                'Cover Song',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _songTile('Drowning'),
                    const SizedBox(width: 12),
                    _songTile('Never Ending'),
                    const SizedBox(width: 12),
                    _songTile('Another Song'),
                  ],
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
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Text('Chart Placeholder')),
              ),

              const SizedBox(height: 24),
              // 점수 박스
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _scoreBox('호흡', '62'),
                  _scoreBox('리듬', '65'),
                  _scoreBox('발음', '58'),
                ],
              ),

              const SizedBox(height: 24),
              // 분석 요약
              const Text(
                '분석 요약',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• 12월에 확실한 톤을 유지했음\n'
                '• 일정 구간에서 목소리가 불안정하게 떨림',
              ),

              const SizedBox(height: 24),
              // 다음 연습 제안
              const Text(
                '다음 연습 제안',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• 중음 위주의 목소리 강화\n'
                '• 높은 음역대 도전',
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallCover() => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: Image.asset(
      'assets/images/cat.webp',
      width: 60,
      height: 60,
      fit: BoxFit.cover,
    ),
  );

  Widget _iconLabel(IconData icon, String label) => Column(
    children: [
      Icon(icon, size: 28, color: Colors.grey.shade700),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );

  Widget _songTile(String title) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'assets/images/cat.webp',
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      ),
      const SizedBox(height: 4),
      Text(title, style: const TextStyle(fontSize: 12)),
    ],
  );

  Widget _scoreBox(String label, String score) => Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.purpleAccent),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          score,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.purpleAccent,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}
