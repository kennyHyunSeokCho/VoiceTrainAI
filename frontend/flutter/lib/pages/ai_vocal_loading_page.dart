import 'package:flutter/material.dart';
import '../models/song.dart';

class AiVocalLoadingPage extends StatelessWidget {
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
            // 진행바
            Container(
              width: 310,
              height: 17,
              decoration: BoxDecoration(
                color: Color(0xFFB69DF8),
                borderRadius: BorderRadius.circular(10000),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 220, // 진행 정도에 따라 width 조절
                  height: 17,
                  decoration: BoxDecoration(
                    color: Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(1000),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        offset: Offset(0, 4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 40),
            // 테스트용: 합성 완료 페이지로 이동 버튼
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/ai-vocal-ready', arguments: song);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                minimumSize: Size(180, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text('합성 완료(테스트)', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
