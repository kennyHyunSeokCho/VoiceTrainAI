import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/song.dart';
import 'pages/record_page.dart';
import 'pages/ai_vocal_loading_page.dart';
import 'pages/ai_vocal_ready_page.dart';
import 'pages/ai_vocal_play_page.dart';
import 'pages/login_page.dart';
import 'pages/search.dart';
import 'pages/notification_page.dart';
import 'main_layout.dart';
import 'services/api_config_service.dart';

/// 현재 로그인된 사용자 정보를 전역으로 관리하는 클래스
class CurrentUser {
  static String? _userId;
  static String? _userNickname;
  static String? _userEmail;
  static String? _provider;

  static void setUser(
    String id,
    String nickname,
    String email,
    String provider,
  ) {
    _userId = id;
    _userNickname = nickname;
    _userEmail = email;
    _provider = provider;
    print('✅ 사용자 정보 저장됨: $nickname ($email)');
  }

  static String? getUserId() => _userId;
  static String? getUserNickname() => _userNickname;
  static String? getUserEmail() => _userEmail;
  static String? getProvider() => _provider;

  static bool isLoggedIn() => _userId != null;

  static void clearUser() {
    _userId = null;
    _userNickname = null;
    _userEmail = null;
    _provider = null;
    print('🔄 사용자 정보 초기화됨');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 파일 로딩
  try {
    await dotenv.load(fileName: ".env");
    print('✅ .env 파일 로딩 성공');
  } catch (e) {
    print('⚠️ .env 파일 로딩 실패: $e (기본값 사용)');
  }

  // API 환경 설정 로그 출력
  await ApiConfigService.logCurrentEnvironment();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final Song sampleSong = Song(
    title: 'Never Ending Story',
    artist: 'IU',
    albumCover: 'assets/images/iu.webp',
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
        textTheme: GoogleFonts.notoSansKrTextTheme(Theme.of(context).textTheme),

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
          labelStyle: GoogleFonts.notoSansKr(color: Colors.grey[600]),
          hintStyle: GoogleFonts.notoSansKr(color: Colors.grey[500]),
        ),
      ),
      onGenerateRoute: (settings) {
        if (settings.name == '/login') {
          return MaterialPageRoute(builder: (context) => const LoginPage());
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
          final song = settings.arguments as Song;
          return MaterialPageRoute(
            builder: (context) => AiVocalReadyPage(),
            settings: RouteSettings(arguments: song),
          );
        }
        if (settings.name == '/ai-vocal-play') {
          final song = settings.arguments as Song;
          return MaterialPageRoute(
            builder: (context) => AiVocalPlayPage(),
            settings: RouteSettings(arguments: song),
          );
        }
        if (settings.name == '/notification') {
          return MaterialPageRoute(builder: (context) => NotificationPage());
        }
        if (settings.name == '/search') {
          return MaterialPageRoute(builder: (context) => SearchPage());
        }
        if (settings.name == '/main') {
          return MaterialPageRoute(builder: (context) => MainLayout());
        }
        return null;
      },
    );
  }
}
