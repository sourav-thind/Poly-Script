import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Connection lifecycle states exposed by [GeminiLiveService].
enum GeminiLiveState {
  /// No active connection and no reconnect in progress.
  disconnected,

  /// A connection attempt is in flight for the first time.
  connecting,

  /// The socket is open and the setup frame has been sent.
  connected,

  /// The connection dropped and a reconnect is being attempted.
  reconnecting,

  /// The connection could not be established or was permanently lost.
  error,
}

/// A thin client around the Gemini Live Translate / Transcribe WebSocket API.
///
/// It owns the socket lifecycle, sends the initial setup handshake, streams raw
/// 16kHz 16-bit mono PCM audio to the server, and exposes a continuous stream of
/// cleaned French subtitle text.
class GeminiLiveService {
  GeminiLiveService({
    this.modelOverride,
    this.targetLanguageCode = 'fr',
    this.connectTimeout = const Duration(seconds: 15),
  });

  /// Speech-to-text only model.
  static const String modelTranscribe = 'gemini-3.5-transcribe-live-preview';

  /// Model that performs live speech translation directly.
  static const String modelLiveTranslate = 'gemini-3.5-live-translate-preview';

  static const String _host = 'wss://generativelanguage.googleapis.com';
  static const String _path =
      '/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';

  static const int _maxReconnectAttempts = 5;
  static const Duration _maxBackoff = Duration(seconds: 30);

  /// Optional explicit model identifier. Mode selection is used when absent.
  final String? modelOverride;

  /// BCP-47 code of the language to translate subtitles into.
  String targetLanguageCode;

  /// How long to wait for the socket handshake before giving up.
  final Duration connectTimeout;

  final StreamController<String> _subtitleController =
      StreamController<String>.broadcast();
  final StreamController<String> _translationController =
      StreamController<String>.broadcast();
  final StreamController<String> _interimSubtitleController =
      StreamController<String>.broadcast();
  final StreamController<String> _interimTranslationController =
      StreamController<String>.broadcast();
  final StreamController<GeminiLiveState> _stateController =
      StreamController<GeminiLiveState>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;

  GeminiLiveState _state = GeminiLiveState.disconnected;
  String? _apiKey;
  String? _lastError;
  bool _showTranslation = false;
  bool _manuallyClosed = true;
  bool _opening = false;
  int _reconnectAttempts = 0;

  /// Continuous, cleaned source-language transcription text.
  Stream<String> get subtitleStream => _subtitleController.stream;

  /// Continuous, cleaned translated text. Only populated while translation is
  /// enabled for the active connection.
  Stream<String> get translationStream => _translationController.stream;

  /// Low-latency provisional source text, replaced by [subtitleStream].
  Stream<String> get interimSubtitleStream => _interimSubtitleController.stream;

  /// Low-latency provisional translated text, replaced by [translationStream].
  Stream<String> get interimTranslationStream =>
      _interimTranslationController.stream;

  /// Emits whenever the connection lifecycle state changes.
  Stream<GeminiLiveState> get stateStream => _stateController.stream;

  /// Emits human-readable error messages (bad key, socket errors, ...).
  Stream<String> get errorStream => _errorController.stream;

  /// The current connection lifecycle state.
  GeminiLiveState get state => _state;

  /// Whether audio can currently be sent to the server.
  bool get isConnected => _state == GeminiLiveState.connected;

  /// Model identifier used by the current mode.
  String get activeModel => modelForMode(_showTranslation);

  /// Resolves the unchanged model constants for [showTranslation].
  String modelForMode(bool showTranslation) {
    final model =
        modelOverride ??
        (showTranslation ? modelLiveTranslate : modelTranscribe);
    return model.startsWith('models/') ? model : 'models/$model';
  }

  /// The most recent error message, if any.
  String? get lastError => _lastError;

  /// Opens the WebSocket connection and performs the setup handshake.
  ///
  /// When [showTranslation] is `false` the service emits the source
  /// transcription; when `true` it emits the translated text instead.
  ///
  /// When supplied, [targetLanguageCode] replaces the target language used for
  /// this and subsequent sessions.
  ///
  /// Missing or empty [apiKey] values are rejected gracefully: the service
  /// emits an error and moves to [GeminiLiveState.error] instead of throwing.
  Future<void> connect(
    String apiKey, {
    bool showTranslation = false,
    String? targetLanguageCode,
  }) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      _manuallyClosed = true;
      _emitError('API key is missing. Provide a valid Gemini API key.');
      _setState(GeminiLiveState.error);
      return;
    }

    _apiKey = trimmed;
    _showTranslation = showTranslation;
    if (targetLanguageCode != null) {
      this.targetLanguageCode = targetLanguageCode;
    }
    _manuallyClosed = false;
    _reconnectAttempts = 0;
    await _openConnection();
  }

  /// Closes the connection and stops any pending reconnect attempts.
  Future<void> disconnect() async {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    await _teardownSocket();
    _setState(GeminiLiveState.disconnected);
  }

  /// Sends a chunk of raw 16kHz 16-bit mono PCM audio to the server.
  ///
  /// No-op when the socket is not connected, so callers can stream freely
  /// without guarding every frame.
  void sendAudioChunk(Uint8List pcmData) {
    if (pcmData.isEmpty) return;
    final channel = _channel;
    if (channel == null || _state != GeminiLiveState.connected) return;

    final payload = <String, dynamic>{
      'realtimeInput': {
        'audio': {
          'mimeType': 'audio/pcm;rate=16000',
          'data': base64Encode(pcmData),
        },
      },
    };
    channel.sink.add(jsonEncode(payload));
  }

  /// Releases all resources. The instance cannot be reused afterwards.
  Future<void> dispose() async {
    await disconnect();
    await _subtitleController.close();
    await _translationController.close();
    await _interimSubtitleController.close();
    await _interimTranslationController.close();
    await _stateController.close();
    await _errorController.close();
  }

  Future<void> _openConnection() async {
    if (_opening) return;
    _opening = true;

    await _teardownSocket();
    _clearInterim();

    final apiKey = _apiKey;
    if (apiKey == null || _manuallyClosed) {
      _opening = false;
      return;
    }

    _setState(
      _reconnectAttempts == 0
          ? GeminiLiveState.connecting
          : GeminiLiveState.reconnecting,
    );

    final uri = Uri.parse(
      '$_host$_path?key=${Uri.encodeQueryComponent(apiKey)}',
    );

    try {
      final channel = IOWebSocketChannel.connect(
        uri,
        pingInterval: const Duration(seconds: 20),
      );
      _channel = channel;

      await channel.ready.timeout(connectTimeout);

      _setState(GeminiLiveState.connected);
      _reconnectAttempts = 0;
      _sendSetup();

      _subscription = channel.stream.listen(
        _handleIncoming,
        onError: _handleSocketError,
        onDone: _handleSocketDone,
        cancelOnError: false,
      );
    } catch (error) {
      _handleSocketError(error);
    } finally {
      _opening = false;
    }
  }

  void _sendSetup() {
    final resolvedModel = activeModel;
    final isTranslate = _showTranslation;

    final generationConfig = <String, dynamic>{
      'responseModalities': isTranslate ? ['AUDIO'] : ['TEXT'],
    };

    if (isTranslate) {
      generationConfig['translationConfig'] = <String, dynamic>{
        'targetLanguageCode': targetLanguageCode,
        'echoTargetLanguage': true,
      };
    }

    final setup = <String, dynamic>{
      'model': resolvedModel,
      'generationConfig': generationConfig,
      'inputAudioTranscription': <String, dynamic>{},
    };

    if (isTranslate) {
      setup['outputAudioTranscription'] = <String, dynamic>{};
    }

    _channel?.sink.add(jsonEncode({'setup': setup}));
  }

  void _handleIncoming(dynamic data) {
    final String raw;
    if (data is String) {
      raw = data;
    } else if (data is List<int>) {
      raw = utf8.decode(data);
    } else {
      return;
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;

    if (decoded.containsKey('setupComplete')) return;

    final error = decoded['error'];
    if (error is Map) {
      final message =
          error['message']?.toString() ??
          'Gemini API returned an unknown error.';
      _emitError(message);
      return;
    }

    final serverContent = decoded['serverContent'];
    if (serverContent is! Map) return;

    // Interim text is emitted immediately as a provisional value. A final
    // transcript clears that provisional value before appending the final
    // chunk, so the UI never shows both versions at once.
    final source = _cleanDisfluencies(
      _transcriptText(serverContent['inputTranscription']),
    );
    final interimSource = _cleanDisfluencies(
      _transcriptText(serverContent['interimInputTranscription']),
    );
    if (source.isNotEmpty) {
      _emitInterim(_interimSubtitleController, '');
      _subtitleController.add(source);
    } else if (interimSource.isNotEmpty) {
      _emitInterim(_interimSubtitleController, interimSource);
    }

    if (_showTranslation) {
      final translated = _cleanDisfluencies(
        _transcriptText(serverContent['outputTranscription']),
      );
      final interimTranslated = _cleanDisfluencies(
        _transcriptText(serverContent['interimOutputTranscription']),
      );
      if (translated.isNotEmpty) {
        _emitInterim(_interimTranslationController, '');
        _translationController.add(translated);
      } else if (interimTranslated.isNotEmpty) {
        _emitInterim(_interimTranslationController, interimTranslated);
      }
    }
  }

  String _transcriptText(dynamic transcription) {
    if (transcription is! Map) return '';
    final text = transcription['text'];
    return text is String ? text : '';
  }

  void _emitInterim(StreamController<String> controller, String text) {
    if (!controller.isClosed) {
      controller.add(text);
    }
  }

  void _clearInterim() {
    _emitInterim(_interimSubtitleController, '');
    _emitInterim(_interimTranslationController, '');
  }

  void _handleSocketError(Object error) {
    _emitError(_describeError(error));
    _scheduleReconnect();
  }

  void _handleSocketDone() {
    final channel = _channel;
    final code = channel?.closeCode;
    final reason = channel?.closeReason;

    if (_manuallyClosed) {
      _setState(GeminiLiveState.disconnected);
      return;
    }

    if (code != null && code != ws_status.normalClosure) {
      final suffix = (reason != null && reason.isNotEmpty) ? ': $reason' : '.';
      _emitError('Connection closed (code $code)$suffix');
    }

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manuallyClosed || _apiKey == null) {
      _setState(GeminiLiveState.disconnected);
      return;
    }
    if (_reconnectTimer?.isActive ?? false) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _emitError(
        'Unable to reconnect after $_maxReconnectAttempts attempts. '
        'Check your API key and network connection.',
      );
      _setState(GeminiLiveState.error);
      return;
    }

    _reconnectAttempts++;
    _setState(GeminiLiveState.reconnecting);

    _reconnectTimer = Timer(_backoffFor(_reconnectAttempts), () async {
      if (_manuallyClosed) return;
      await _openConnection();
    });
  }

  Duration _backoffFor(int attempt) {
    final seconds = 1 << (attempt - 1);
    return Duration(
      seconds: seconds > _maxBackoff.inSeconds
          ? _maxBackoff.inSeconds
          : seconds,
    );
  }

  Future<void> _teardownSocket() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();

    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await channel.sink.close(ws_status.normalClosure);
      } catch (_) {
        // Already closed or failed mid-handshake; nothing left to do.
      }
    }
  }

  void _setState(GeminiLiveState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  void _emitError(String message) {
    _lastError = message;
    if (!_errorController.isClosed) {
      _errorController.add(message);
    }
  }

  String _describeError(Object error) {
    if (error is TimeoutException) {
      return 'Connection to Gemini timed out. Check your network connection.';
    }
    final text = error.toString();
    if (text.contains('401') || text.contains('403')) {
      return 'Invalid or unauthorized API key.';
    }
    return 'WebSocket error: $text';
  }

  /// Removes markdown noise and common French disfluencies from server text so
  /// only the translated subtitle string reaches the UI.
  String _cleanDisfluencies(String raw) {
    var text = raw;

    // Strip markdown formatting characters that the model may leak through.
    text = text.replaceAll(RegExp(r'[`*_#>~]'), '');

    // Drop standalone French filler words (conservative list to avoid eating
    // meaningful vocabulary such as "bon" or "voilà").
    text = text.replaceAll(
      RegExp(r'\b(?:euh+|heu+|hum+|hmm+|bah|ben|hein)\b', caseSensitive: false),
      ' ',
    );

    // Collapse runs of whitespace and trim the result.
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }
}
