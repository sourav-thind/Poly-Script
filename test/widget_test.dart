import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:poly_cript/services/api_key_store.dart';
import 'package:poly_cript/services/gemini_live_service.dart';
import 'package:poly_cript/widgets/subtitle_overlay.dart';

class _FakeApiKeyStore extends ApiKeyStore {
  String? key;
  bool includeMic = false;
  bool showTranslation = false;

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

  @override
  Future<bool> readShowTranslation() async => showTranslation;

  @override
  Future<void> setShowTranslation(bool show) async => showTranslation = show;
}

class _FakeGeminiLiveService extends GeminiLiveService {
  final StreamController<GeminiLiveState> _states =
      StreamController<GeminiLiveState>.broadcast();

  @override
  Stream<GeminiLiveState> get stateStream => _states.stream;

  @override
  Future<void> connect(String apiKey, {bool showTranslation = false}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {
    await _states.close();
  }
}

void main() {
  testWidgets('opens settings automatically when no key is saved', (
    WidgetTester tester,
  ) async {
    final store = _FakeApiKeyStore();

    await tester.pumpWidget(
      MaterialApp(
        home: SubtitleOverlay(
          keyStore: store,
          gemini: _FakeGeminiLiveService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gemini API Key'), findsOneWidget);
    expect(find.text('No key set'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
    expect(find.text('Stop'), findsNothing);
  });

  testWidgets('saving a key persists it and starts listening automatically', (
    WidgetTester tester,
  ) async {
    final store = _FakeApiKeyStore();

    await tester.pumpWidget(
      MaterialApp(
        home: SubtitleOverlay(
          keyStore: store,
          gemini: _FakeGeminiLiveService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'test-api-key');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.key, 'test-api-key');
    expect(find.text('Gemini API Key'), findsNothing);
    expect(find.text('STARTING'), findsOneWidget);
  });

  testWidgets('toggling microphone preference is persisted with the key', (
    WidgetTester tester,
  ) async {
    final store = _FakeApiKeyStore();

    await tester.pumpWidget(
      MaterialApp(
        home: SubtitleOverlay(
          keyStore: store,
          gemini: _FakeGeminiLiveService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'saved-key');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('include-microphone-toggle')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.key, 'saved-key');
    expect(store.includeMic, isTrue);
    expect(store.showTranslation, isFalse);
  });

  testWidgets('show translation is off by default and can be enabled', (
    WidgetTester tester,
  ) async {
    final store = _FakeApiKeyStore();

    await tester.pumpWidget(
      MaterialApp(
        home: SubtitleOverlay(
          keyStore: store,
          gemini: _FakeGeminiLiveService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final translationToggle =
        find.byKey(const ValueKey('show-translation-toggle'));
    expect(tester.widget<Checkbox>(translationToggle).value, isFalse);

    await tester.enterText(find.byType(TextField), 'saved-key');
    await tester.pump();
    await tester.tap(translationToggle);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.showTranslation, isTrue);
  });
}
