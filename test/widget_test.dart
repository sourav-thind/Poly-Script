import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:poly_cript/widgets/subtitle_overlay.dart';

void main() {
  testWidgets('Start and Stop buttons toggle listening state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SubtitleOverlay()));

    expect(find.text('Press Start to begin listening'), findsOneWidget);
    expect(find.text('IDLE'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(find.text('Listening for subtitles…'), findsOneWidget);
    expect(find.text('LISTENING'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();

    expect(find.text('Press Start to begin listening'), findsOneWidget);
    expect(find.text('IDLE'), findsOneWidget);
  });
}
