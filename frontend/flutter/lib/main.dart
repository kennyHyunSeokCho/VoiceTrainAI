import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      theme: ThemeData(
        // Google Fonts를 사용한 한글 폰트 설정
        textTheme: GoogleFonts.notoSansKrTextTheme(
          Theme.of(context).textTheme,
        ),
        
        // 색상 테마
        primarySwatch: Colors.purple,
        primaryColor: Colors.purple[600],
        
        // 앱바 테마
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          titleTextStyle: GoogleFonts.notoSansKr(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        // 버튼 테마
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: GoogleFonts.notoSansKr(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        // 입력 필드 테마
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: GoogleFonts.notoSansKr(
            color: Colors.grey[600],
          ),
          hintStyle: GoogleFonts.notoSansKr(
            color: Colors.grey[500],
          ),
        ),
      ),
      onGenerateRoute: (settings) {
        if (settings.name == '/login') {
          return MaterialPageRoute(
            builder: (context) => const LoginPage(),
          );
        }
        if (settings.name == '/record') {
          final song = settings.arguments as Song;
          return MaterialPageRoute(
            builder: (context) => RecordPage(),
            settings: RouteSettings(arguments: song),
          );
        }
        if (settings.name == '/ai-vocal-loading') {
          final song = settings.arguments as Song;
          return MaterialPageRoute(
            builder: (context) => AiVocalLoadingPage(),
            settings: RouteSettings(arguments: song),
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
        return null;
      },
    );
  }
}

class SongCard extends StatelessWidget {
  // ...생략...
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 210, // 높이 명시적으로 지정
      child: Column(
        mainAxisSize: MainAxisSize.min, // 추가
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ...생략...
        ],
      ),
    );
  }
}