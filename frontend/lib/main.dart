import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/record/providers/recording_provider.dart';

// 웹 환경 조건부 import
import 'core/utils/web_download_stub.dart'
    if (dart.library.html) 'core/utils/web_download_web.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RecordingProvider()),
      ],
      child: MaterialApp(
        title: '🎤 음성 녹음 앱',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const VoiceTrainingApp(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// 메인 앱 화면
class VoiceTrainingApp extends StatelessWidget {
  const VoiceTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('🎤 음성 녹음'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<RecordingProvider>(
        builder: (context, recordingProvider, child) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🎤 녹음 상태 및 시간 표시
                  _buildRecordingStatus(recordingProvider),
                  
                  const SizedBox(height: 60),

                  // 🎵 메인 녹음 버튼
                  _buildMainRecordButton(context, recordingProvider),
                  
                  const SizedBox(height: 40),
                  
                  // 💡 간단한 안내 메시지
                  _buildHelpText(recordingProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 녹음 상태 및 시간 표시
  Widget _buildRecordingStatus(RecordingProvider provider) {
    return Column(
      children: [
        // 녹음 상태 아이콘
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: provider.isRecording ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            border: Border.all(
              color: provider.isRecording ? Colors.red : Colors.grey,
              width: 3,
            ),
          ),
          child: Icon(
            provider.isRecording ? Icons.graphic_eq : Icons.mic_none,
            size: 60,
            color: provider.isRecording ? Colors.red : Colors.grey[600],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // 녹음 시간 또는 상태 텍스트
        if (provider.isRecording) ...[
          Text(
            _formatDuration(provider.recordingDuration),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w300,
              fontFamily: 'monospace',
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '녹음 중...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else ...[
          Text(
            '00:00',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w300,
              fontFamily: 'monospace',
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '녹음 준비됨',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  // 메인 녹음 버튼
  Widget _buildMainRecordButton(BuildContext context, RecordingProvider provider) {
    return GestureDetector(
      onTap: () async {
        print('👆 버튼 클릭됨! 현재 녹음 상태: ${provider.isRecording}');
        
        try {
          if (provider.isRecording) {
            print('🔄 UI: 녹음 중지 버튼 클릭');
            await provider.stopRecording();
            
            // 완료 메시지
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(kIsWeb ? '다운로드 완료!' : '녹음 완료!'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          } else {
            print('🔄 UI: 녹음 시작 버튼 클릭');
            
            // 즉시 안내 메시지 표시
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.mic, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text('🎤 마이크 권한을 허용해주세요...'),
                  ],
                ),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            
            await provider.startRecording();
            
            // 녹음 시작 성공 메시지
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.fiber_manual_record, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text('🎤 녹음이 시작되었습니다!'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        } catch (e) {
          print('❌❌❌ UI: 심각한 오류 발생 - $e');
          print('❌❌❌ 오류 타입: ${e.runtimeType}');
          print('❌❌❌ 스택 트레이스: ${StackTrace.current}');
          
          // 오류 발생 시 모든 스낵바 지우고 오류 메시지 표시
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white),
                      const SizedBox(width: 12),
                      const Text('❌ 녹음 오류 발생'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('상세 오류: $e', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  const Text(
                    '💡 해결방법:\n• F12를 눌러 콘솔 확인\n• 마이크 권한 허용\n• 페이지 새로고침 후 재시도',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 8),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: provider.isRecording 
                ? [Colors.red.shade400, Colors.red.shade600]
                : [Colors.blue.shade400, Colors.blue.shade600],
          ),
          boxShadow: [
            BoxShadow(
              color: (provider.isRecording ? Colors.red : Colors.blue).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              provider.isRecording ? Icons.stop : Icons.mic,
              size: 60,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              provider.isRecording ? '중지' : '녹음',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 도움말 텍스트
  Widget _buildHelpText(RecordingProvider provider) {
    if (provider.isRecording) {
      return Text(
        '버튼을 눌러 녹음을 중지하세요',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey[600],
          height: 1.5,
        ),
      );
    } else {
      return Text(
        '큰 버튼을 눌러 녹음을 시작하세요\n${kIsWeb ? '완료 후 자동으로 다운로드됩니다' : '파일이 로컬에 저장됩니다'}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey[600],
          height: 1.5,
        ),
      );
    }
  }

  // 시간 포맷팅 함수
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds % 60);
    return '$minutes:$seconds';
  }
} 