import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 앱의 다양한 캐시를 관리하는 서비스 클래스
class CacheService {
  /// 앱 캐시 디렉토리 삭제 (이미지, 파일 등)
  static Future<void> clearAppCache() async {
    try {
      if (kIsWeb) {
        print('⚠️ 웹 환경에서는 캐시 삭제가 제한적입니다.');
        return;
      }

      // 앱 캐시 디렉토리 가져오기
      final cacheDir = await getTemporaryDirectory();
      
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('✅ 앱 캐시 삭제 완료: ${cacheDir.path}');
      } else {
        print('ℹ️ 삭제할 캐시가 없습니다.');
      }
    } catch (e) {
      print('❌ 앱 캐시 삭제 실패: $e');
    }
  }

  /// 앱 데이터 캐시 삭제 (녹음 파일 제외)
  static Future<void> clearDataCache() async {
    try {
      if (kIsWeb) {
        print('⚠️ 웹 환경에서는 데이터 캐시 삭제가 제한적입니다.');
        return;
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final cacheSubDirs = ['images', 'temp', 'cache'];
      
      for (String subDir in cacheSubDirs) {
        final dir = Directory('${appDocDir.path}/$subDir');
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          print('✅ $subDir 캐시 삭제 완료');
        }
      }
    } catch (e) {
      print('❌ 데이터 캐시 삭제 실패: $e');
    }
  }

  /// 개발 모드에서만 캐시 디버그 정보 출력
  static Future<void> debugCacheInfo() async {
    if (kDebugMode) {
      print('🔍 캐시 디버그 정보');
      
      try {
        if (!kIsWeb) {
          final tempDir = await getTemporaryDirectory();
          final appDocDir = await getApplicationDocumentsDirectory();
          
          print('- 임시 디렉토리: ${tempDir.path}');
          print('- 앱 문서 디렉토리: ${appDocDir.path}');
          
          if (await tempDir.exists()) {
            final tempSize = await _calculateDirectorySize(tempDir);
            print('- 임시 캐시 크기: ${_formatBytes(tempSize)}');
          }
        }
      } catch (e) {
        print('❌ 캐시 정보 수집 실패: $e');
      }
    }
  }

  /// 디렉토리 크기 계산
  static Future<int> _calculateDirectorySize(Directory directory) async {
    int size = 0;
    
    try {
      await for (var entity in directory.list(recursive: true)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
    } catch (e) {
      print('디렉토리 크기 계산 오류: $e');
    }
    
    return size;
  }

  /// 바이트를 읽기 쉬운 형식으로 변환
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
} 