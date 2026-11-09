import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:poly_cript/services/api_key_store.dart';
import 'package:poly_cript/widgets/subtitle_overlay.dart';

class _FakeApiKeyStore extends ApiKeyStore {
  String? key;
  bool includeMic = false;

  @override
  Future<String?> readKey() async => key;

  @override
  Future<void> saveKey(String value) async => key = value.trim();

  @override
  Future<void> clearKey() async => key = null;

  @override
  Future<bool> readIncludeMicrophone() async => includeMic;

  @override
  Future<void> setIncludeMicrophone(bool include) async => includeMic = include;
}

void main() {
  testWidgets('shows idle state and opens settings when no key is saved', (
    WidgetTester tester,
  ) async {
    final store = _FakeApiKeyStore();

    await tester.pumpWidget(
      MaterialApp(home: SubtitleOverlay(keyStore: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Press Start to begin listening'), findsOneWidget);
    expect(find.text('IDLE'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('Gemini API Key'), findsOneWidget);
    expect(find.text('No key set'), findsOneWidget);
  });

  testWidgets('saving a key persists it and closes the settings panel', (
    WidgetTester tester,
  ) async {
    final store = _FakeApiKeyStore();

    await tester.pumpWidget(
      MaterialApp(home: SubtitleOverlay(keyStore: store)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'test-api-key');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.key, 'test-api-key');
    expect(find.text('Gemini API Key'), findsNothing);
    expect(find.text('IDLE'), findsOneWidget);
  });

  testWidgets('toggling microphone preference is persisted with the key', (
    WidgetTester tester,
  ) async {
    final store = _FakeApiKeyStore();

    await tester.pumpWidget(
      MaterialApp(home: SubtitleOverlay(keyStore: store)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'saved-key');
    await tester.pump();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.key, 'saved-key');
    expect(store.includeMic, isTrue);
  });
}
