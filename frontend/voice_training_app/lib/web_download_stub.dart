// 웹이 아닌 플랫폼용 stub 구현
Future<void> downloadFile(String sourcePath, String fileName) async {
  // 웹이 아닌 환경에서는 아무것도 하지 않음
  print('데스크톱 환경: 다운로드 기능 불필요');
} 