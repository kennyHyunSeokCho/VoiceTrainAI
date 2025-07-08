import 'package:flutter/material.dart';
import '../models/song.dart';

class AiVocalPlayPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Song song = ModalRoute.of(context)!.settings.arguments as Song;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('AI Vocal 합성'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // 앨범커버 자리
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.music_note, size: 100, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            Text(
              song.title,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              '동욱넴 Ver.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            // 재생바
            Row(
              children: [
                Text('1:46', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                Expanded(
                  child: Slider(
                    value: 106,
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
            // 플레이어 컨트롤
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: Icon(Icons.skip_previous), onPressed: () {}),
                IconButton(icon: Icon(Icons.play_arrow, size: 36), onPressed: () {}),
                IconButton(icon: Icon(Icons.skip_next), onPressed: () {}),
                IconButton(icon: Icon(Icons.favorite_border), onPressed: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
