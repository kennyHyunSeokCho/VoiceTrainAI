  import 'package:flutter/material.dart';
  import '../models/song.dart';
  
class RecordPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Song song = ModalRoute.of(context)!.settings.arguments as Song;

    return Scaffold(
      backgroundColor: Color(0xFFF8F0F8),
      appBar: AppBar(
        title: Text(song.title, style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 노래 정보
              Row(
                children: [
                  // 앨범커버 자리(이미지 없으니 Container로 대체)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.music_note, size: 40, color: Colors.grey[600]),
                  ),
                  SizedBox(width: 16),
                  // 노래 정보
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.artist, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                      Text(song.difficulty, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(song.range, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                  Spacer(),
                  // 점수/포인트 자리
                  Column(
                    children: [
                      Text('76/100', style: TextStyle(fontSize: 16, color: Colors.deepPurple)),
                      Text('+5points', style: TextStyle(fontSize: 10, color: Colors.purple[200])),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 24),
              // 가사/슬라이딩 가사
              Center(
                child: Text(
                  '🎵 Lyrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
              ),
              SizedBox(height: 8),
              Text(
                song.lyrics,
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              // 재생 바
              SizedBox(height: 16),
              Row(
                children: [
                  Text('1:20', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  Expanded(
                    child: Slider(
                      value: 80,
                      min: 0,
                      max: 220,
                      onChanged: (v) {},
                      activeColor: Colors.deepPurple,
                      inactiveColor: Colors.grey[300],
                    ),
                  ),
                  Text(song.duration, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
              // 하단 녹음/AI보컬합성 버튼
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.mic),
                      label: Text('녹음하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/ai-vocal-loading', arguments: song);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}