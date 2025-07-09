import 'package:flutter/material.dart';
import '../models/song.dart';

class RecordPage extends StatefulWidget {
  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  bool isRecording = false;

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
              // 앨범커버 + 배경
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 배경 이미지(예시)
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(80),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.1),
                            blurRadius: 30,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                    ),
                    // 앨범커버 이미지
                    ClipRRect(
                      borderRadius: BorderRadius.circular(70),
                      child: Image.asset(
                        song.albumCover.isNotEmpty
                            ? song.albumCover
                            : 'assets/images/Img.png',
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // 노래 정보
              Center(
                child: Column(
                  children: [
                    Text(
                      song.artist,
                      style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Chip(
                          label: Text(
                            song.difficulty,
                            style: TextStyle(fontSize: 14),
                          ),
                          backgroundColor: Colors.deepPurple[50],
                        ),
                        SizedBox(width: 8),
                        Chip(
                          label: Text(
                            song.range,
                            style: TextStyle(fontSize: 14),
                          ),
                          backgroundColor: Colors.deepPurple[50],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // 점수/포인트
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 20),
                  SizedBox(width: 4),
                  Text(
                    '76/100',
                    style: TextStyle(fontSize: 16, color: Colors.deepPurple),
                  ),
                  SizedBox(width: 12),
                  Text(
                    '+5points',
                    style: TextStyle(fontSize: 12, color: Colors.purple[200]),
                  ),
                ],
              ),
              SizedBox(height: 24),
              // 가사/슬라이딩 가사
              Center(
                child: Text(
                  '🎵 Lyrics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  song.lyrics,
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
              SizedBox(height: 16),
              // 재생 바
              Row(
                children: [
                  Text(
                    '1:20',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
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
                  Text(
                    song.duration,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 8),
              // 녹음/일시정지 버튼
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(
                        isRecording ? Icons.pause_circle_filled : Icons.mic,
                        size: 28,
                        color: Colors.black,
                      ),
                      label: Text(
                        isRecording ? '일시정지' : '녹음 시작',
                        style: TextStyle(fontSize: 18, color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        minimumSize: Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        setState(() {
                          isRecording = !isRecording;
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // 예시: 하단에 이미지 아이콘 추가
              Center(
                child: Image.asset(
                  'assets/images/iu.webp',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
