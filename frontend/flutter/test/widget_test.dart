import 'package:flutter/material.dart';
import 'models/song.dart';
import 'pages/record_page.dart';
import 'pages/ai_vocal_loading_page.dart';
import 'pages/ai_vocal_ready_page.dart';
import 'pages/ai_vocal_play_page.dart';
import 'pages/login_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final Song sampleSong = Song(
    title: 'Never Ending Story',
    artist: 'IU',
    albumCover: '',
    difficulty: '중급',
    range: 'F3 ~ D5',
    lyrics: '그리워하면 언젠가 만나게 되는 ... (가사 생략)',
    duration: '3:40',
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SingSang',
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        if (settings.name == '/login') {
          return MaterialPageRoute(
            builder: (context) => const LoginPage(),
          );
        }
        if (settings.name == '/ai-vocal-loading') {
          return MaterialPageRoute(
            builder: (context) => AiVocalLoadingPage(),
            settings: RouteSettings(arguments: sampleSong),
          );
        }
        if (settings.name == '/ai-vocal-ready') {
          return MaterialPageRoute(
            builder: (context) => AiVocalReadyPage(),
            settings: RouteSettings(arguments: sampleSong),
          );
        }
        if (settings.name == '/ai-vocal-play') {
          return MaterialPageRoute(
            builder: (context) => AiVocalPlayPage(),
            settings: RouteSettings(arguments: sampleSong),
          );
        }
        if (settings.name == '/record') {
          return MaterialPageRoute(
            builder: (context) => RecordPage(),
            settings: RouteSettings(arguments: sampleSong),
          );
        }
        return null;
      },
    );
  }
}

// ... (MyApp 클래스 등)