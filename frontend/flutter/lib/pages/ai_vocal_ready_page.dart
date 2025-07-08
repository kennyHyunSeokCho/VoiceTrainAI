import 'package:flutter/material.dart';
import '../models/song.dart';

class AiVocalReadyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Song song = ModalRoute.of(context)!.settings.arguments as Song;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 앨범커버 자리 (이미지 없으니 Container로 대체)
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Color(0xFFA8C7FF),
                borderRadius: BorderRadius.circular(90),
              ),
              child: Icon(Icons.music_note, size: 100, color: Colors.white),
            ),
            SizedBox(height: 32),
            Text(
              'AI Vocal 합성 중',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'NanumSquare',
              ),
            ),
            SizedBox(height: 8),
            Text(
              'connecting',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontFamily: 'NanumSquare',
              ),
            ),
            SizedBox(height: 32),
            // 보라색 진행바
            Container(
              width: 310,
              height: 17,
              decoration: BoxDecoration(
                color: Color(0xFF7F67BE),
                borderRadius: BorderRadius.circular(10000),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    offset: Offset(0, 4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            SizedBox(height: 40),
            // "들어본나" 버튼
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/ai-vocal-play', arguments: song);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                minimumSize: Size(180, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text('들어본나', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}
