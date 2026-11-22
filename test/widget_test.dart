import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/legacy.dart' show DragToResizeArea;

import 'package:poly_cript/services/api_key_store.dart';
import 'package:poly_cript/services/gemini_live_service.dart';
import 'package:poly_cript/services/translation_languages.dart';
import 'package:poly_cript/widgets/subtitle_overlay.dart';

class _FakeApiKeyStore extends ApiKeyStore {
  String? key;
  bool includeMic = false;
  bool showTranslation = false;
  String targetLanguageCode = defaultTargetLanguageCode;

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

  @override
  Future<String> readTargetLanguage() async => targetLanguageCode;

  @override
  Future<void> setTargetLanguage(String code) async =>
      targetLanguageCode = code.trim();
}

class _FakeGeminiLiveService extends GeminiLiveService {
  final StreamController<GeminiLiveState> _states =
      StreamController<GeminiLiveState>.broadcast();
  final StreamController<String> _subtitles =
      StreamController<String>.broadcast();
  final StreamController<String> _translations =
      StreamController<String>.broadcast();
  final StreamController<String> _interimSubtitles =
      StreamController<String>.broadcast();
  final StreamController<String> _interimTranslations =
      StreamController<String>.broadcast();

  String? connectedTargetLanguageCode;
  String? connectedModel;

  @override
  Stream<GeminiLiveState> get stateStream => _states.stream;

  @override
  Stream<String> get subtitleStream => _subtitles.stream;

  @override
  Stream<String> get translationStream => _translations.stream;

  @override
  Stream<String> get interimSubtitleStream => _interimSubtitles.stream;

  @override
  Stream<String> get interimTranslationStream => _interimTranslations.stream;

  void emitSubtitle(String text) => _subtitles.add(text);

  void emitTranslation(String text) => _translations.add(text);

  void emitInterimSubtitle(String text) => _interimSubtitles.add(text);

  void emitInterimTranslation(String text) => _interimTranslations.add(text);

  @override
  Future<void> connect(
    String apiKey, {
    bool showTranslation = false,
    String? targetLanguageCode,
  }) async {
    connectedTargetLanguageCode = targetLanguageCode;
    connectedModel = modelForMode(showTranslation);
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {
    await _states.close();
    await _subtitles.close();
    await _translations.close();
    await _interimSubtitles.close();
    await _interimTranslations.close();
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
    expect(find.text('MONO MODE'), findsOneWidget);
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

    final translationToggle = find.byKey(
      const ValueKey('show-translation-toggle'),
    );
    expect(tester.widget<Checkbox>(translationToggle).value, isFalse);

    await tester.enterText(find.byType(TextField), 'saved-key');
    await tester.pump();
    await tester.tap(translationToggle);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.showTranslation, isTrue);
    expect(find.text('T-MODE'), findsOneWidget);
  });

  testWidgets('shows a separate translation box when translation is on', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 160);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _FakeApiKeyStore()
      ..key = 'saved-key'
      ..showTranslation = true;

    await tester.pumpWidget(
      MaterialApp(
        home: SubtitleOverlay(
          keyStore: store,
          gemini: _FakeGeminiLiveService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('T-MODE'), findsOneWidget);
    expect(find.text('Translation…'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
  });

  testWidgets('target language defaults to French and can be saved', (
    WidgetTester tester,
  ) async {
    final store = _FakeApiKeyStore();
    final gemini = _FakeGeminiLiveService();

    await tester.pumpWidget(
      MaterialApp(
        home: SubtitleOverlay(keyStore: store, gemini: gemini),
      ),
    );
    await tester.pumpAndSettle();

    final dropdown = find.byKey(const ValueKey('target-language-dropdown'));
    expect(tester.widget<DropdownButton<String>>(dropdown).value, 'fr');

    await tester.enterText(find.byType(TextField), 'test-api-key');
    await tester.pump();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('German').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.targetLanguageCode, 'de');
    expect(gemini.connectedTargetLanguageCode, 'de');
  });

  testWidgets('settings panel fits the 800x160 window with language dropdown', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 160);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SubtitleOverlay(
          keyStore: _FakeApiKeyStore(),
          gemini: _FakeGeminiLiveService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('target-language-dropdown')),
      findsOneWidget,
    );
  });

  testWidgets('interim source text is replaced by final text', (
    WidgetTester tester,
  ) async {
    final store = _FakeApiKeyStore()..key = 'saved-key';
    final gemini = _FakeGeminiLiveService();

    await tester.pumpWidget(
      MaterialApp(
        home: SubtitleOverlay(keyStore: store, gemini: gemini),
      ),
    );
    await tester.pumpAndSettle();

    expect(gemini.connectedModel, 'models/gemini-3.5-transcribe-live');

    gemini.emitInterimSubtitle('Hello wor');
    await tester.pumpAndSettle();
    expect(find.text('Hello wor'), findsOneWidget);

    gemini.emitInterimSubtitle('');
    gemini.emitSubtitle('Hello world');
    await tester.pumpAndSettle();

    expect(find.text('Hello wor'), findsNothing);
    expect(find.text('Hello world'), findsOneWidget);
  });

  testWidgets('interim translation is replaced by final translation', (
    WidgetTester tester,
  ) async {
    final store = _FakeApiKeyStore()
      ..key = 'saved-key'
      ..showTranslation = true;
    final gemini = _FakeGeminiLiveService();

    await tester.pumpWidget(
      MaterialApp(
        home: SubtitleOverlay(keyStore: store, gemini: gemini),
      ),
    );
    await tester.pumpAndSettle();

    expect(gemini.connectedModel, 'models/gemini-3.5-live-translate-preview');

    gemini.emitInterimTranslation('Bonjour le mon');
    await tester.pumpAndSettle();
    expect(find.text('Bonjour le mon'), findsOneWidget);

    gemini.emitInterimTranslation('');
    gemini.emitTranslation('Bonjour le monde');
    await tester.pumpAndSettle();

    expect(find.text('Bonjour le mon'), findsNothing);
    expect(find.text('Bonjour le monde'), findsOneWidget);
  });

  testWidgets('overlay exposes cursor-driven resize handles', (
    WidgetTester tester,
  ) async {
    final store = _FakeApiKeyStore()..key = 'saved-key';

    await tester.pumpWidget(
      MaterialApp(
        home: SubtitleOverlay(
          keyStore: store,
          gemini: _FakeGeminiLiveService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DragToResizeArea), findsOneWidget);
  });

  test('model constants remain unchanged and switch by mode', () async {
    final service = GeminiLiveService();

    expect(GeminiLiveService.modelTranscribe, 'gemini-3.5-transcribe-live');
    expect(
      GeminiLiveService.modelLiveTranslate,
      'gemini-3.5-live-translate-preview',
    );
    expect(service.modelForMode(false), 'models/gemini-3.5-transcribe-live');
    expect(
      service.modelForMode(true),
      'models/gemini-3.5-live-translate-preview',
    );

    await service.dispose();
  });
}
