// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:voice_training_app/main.dart';

void main() {
  testWidgets('Voice recorder app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Verify that our app has a recording button.
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.text('녹음 시작'), findsOneWidget);
  });
}
