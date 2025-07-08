import 'dart:html' as html;

// 웹 플랫폼용 다운로드 기능

// 웹에서 파일 다운로드
Future<void> downloadFile(String sourcePath, String fileName) async {
  try {
    final anchor = html.AnchorElement(href: sourcePath)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    
    print('💾 웹 다운로드 완료: $fileName');
  } catch (e) {
    print('웹 다운로드 오류: $e');
  }
} 