// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:typed_data';

import 'package:desktop_audio_capture/audio_capture.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/legacy.dart';

import '../services/api_key_store.dart';
import '../services/audio_mixer.dart';
import '../services/gemini_live_service.dart';
import 'settings_panel.dart';

/// Floating subtitle pill shown in the transparent, always-on-top overlay
/// window.
class SubtitleOverlay extends StatefulWidget {
  const SubtitleOverlay({super.key, this.keyStore, this.gemini});

  /// Injectable storage, primarily for tests.
  final ApiKeyStore? keyStore;

  /// Injectable Gemini client, primarily for tests.
  final GeminiLiveService? gemini;

  @override
  State<SubtitleOverlay> createState() => _SubtitleOverlayState();
}

class _SubtitleOverlayState extends State<SubtitleOverlay> {
  late final GeminiLiveService _gemini;
  late final ApiKeyStore _keyStore;
  final PcmMixer _mixer = PcmMixer();

  StreamSubscription<String>? _subtitleSub;
  StreamSubscription<GeminiLiveState>? _stateSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<Uint8List>? _audioSub;

  SystemAudioCapture? _systemCapture;
  MicAudioCapture? _micCapture;

  bool _isListening = false;
  bool _isSettingsOpen = false;
  bool _hasSavedKey = false;
  bool _includeMicrophone = false;
  bool _showTranslation = false;
  String _subtitle = '';
  String? _errorMessage;
  GeminiLiveState _connectionState = GeminiLiveState.disconnected;

  @override
  void initState() {
    super.initState();
    _gemini = widget.gemini ?? GeminiLiveService();
    _keyStore = widget.keyStore ?? ApiKeyStore();

    _subtitleSub = _gemini.subtitleStream.listen((text) {
      if (!mounted) return;
      setState(() => _subtitle = _appendSubtitle(_subtitle, text));
    });
    _stateSub = _gemini.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _connectionState = state);
    });
    _errorSub = _gemini.errorStream.listen((message) {
      if (!mounted) return;
      setState(() => _errorMessage = message);
    });

    unawaited(_loadSettings());
  }

  @override
  void dispose() {
    _subtitleSub?.cancel();
    _stateSub?.cancel();
    _errorSub?.cancel();
    unawaited(_stopCapture());
    unawaited(_gemini.dispose());
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final key = await _keyStore.readKey();
      final includeMic = await _keyStore.readIncludeMicrophone();
      final showTranslation = await _keyStore.readShowTranslation();
      if (!mounted) return;
      setState(() {
        _hasSavedKey = key != null;
        _includeMicrophone = includeMic;
        _showTranslation = showTranslation;
      });
      await _startListening();
    } catch (_) {
      // Storage unavailable (e.g. widget tests); stay idle.
    }
  }

  Future<void> _startListening() async {
    if (_isListening) return;

    String? key;
    try {
      key = await _keyStore.readKey();
    } catch (_) {
      key = null;
    }

    if (!mounted) return;

    if (key == null) {
      setState(() {
        _isSettingsOpen = true;
        _errorMessage = 'Add your Gemini API key in Settings.';
      });
      return;
    }

    setState(() {
      _isListening = true;
      _isSettingsOpen = false;
      _errorMessage = null;
      _subtitle = '';
    });

    await _gemini.connect(key, showTranslation: _showTranslation);
    await _startCapture();
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    setState(() => _isListening = false);
    await _stopCapture();
    await _gemini.disconnect();
  }

  Future<void> _startCapture() async {
    await _stopCapture();

    final sources = <Stream<Uint8List>>[];

    try {
      // Request a rate above any common device mix rate so the plugin forwards
      // every captured frame instead of truncating them. The actual rate is
      // inferred and resampled to 16 kHz below.
      final system = SystemAudioCapture(
        config: SystemAudioConfig(sampleRate: 192000, channels: 1),
      );
      await system.startCapture();
      _systemCapture = system;
      final stream = system.audioStream;
      if (stream != null) {
        sources.add(resampleSystemAudio(stream));
      }
    } catch (error) {
      _setError('System audio capture failed: $error');
    }

    if (_includeMicrophone) {
      try {
        final mic = MicAudioCapture(
          config: MicAudioConfig(sampleRate: 16000, channels: 1, bitDepth: 16),
        );
        await mic.startCapture();
        _micCapture = mic;
        final stream = mic.audioStream;
        if (stream != null) sources.add(stream);
      } catch (error) {
        _setError('Microphone capture failed: $error');
      }
    }

    if (sources.isEmpty) return;

    _audioSub = _mixer
        .mixStreams(sources)
        .listen((chunk) => _gemini.sendAudioChunk(chunk));
  }

  Future<void> _stopCapture() async {
    await _audioSub?.cancel();
    _audioSub = null;

    final system = _systemCapture;
    _systemCapture = null;
    if (system != null) {
      try {
        await system.stopCapture();
      } catch (_) {}
    }

    final mic = _micCapture;
    _micCapture = null;
    if (mic != null) {
      try {
        await mic.stopCapture();
      } catch (_) {}
    }
  }

  Future<void> _openSettings() async {
    var hasKey = _hasSavedKey;
    try {
      hasKey = (await _keyStore.readKey()) != null;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _hasSavedKey = hasKey;
      _isSettingsOpen = true;
      _errorMessage = null;
    });
  }

  Future<void> _saveSettings(
    String? apiKey,
    bool includeMic,
    bool showTranslation,
  ) async {
    try {
      if (apiKey != null) {
        await _keyStore.saveKey(apiKey);
      }
      await _keyStore.setIncludeMicrophone(includeMic);
      await _keyStore.setShowTranslation(showTranslation);
    } catch (error) {
      _setError('Could not save settings: $error');
      return;
    }

    if (!mounted) return;
    setState(() {
      if (apiKey != null) _hasSavedKey = true;
      _includeMicrophone = includeMic;
      _showTranslation = showTranslation;
      _isSettingsOpen = false;
      _errorMessage = null;
    });

    if (_isListening) {
      await _stopListening();
    }
    await _startListening();
  }

  Future<void> _removeKey() async {
    try {
      await _keyStore.clearKey();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _hasSavedKey = false;
      _isSettingsOpen = false;
    });
    if (_isListening) {
      await _stopListening();
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  String _appendSubtitle(String current, String chunk) {
    final combined = current.isEmpty ? chunk : '$current $chunk';
    final normalized = combined.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 300) return normalized;
    return normalized.substring(normalized.length - 300).trimLeft();
  }

  String get _statusLabel {
    switch (_connectionState) {
      case GeminiLiveState.connecting:
        return 'CONNECTING';
      case GeminiLiveState.reconnecting:
        return 'RECONNECTING';
      case GeminiLiveState.connected:
        return 'LISTENING';
      case GeminiLiveState.error:
        return 'ERROR';
      case GeminiLiveState.disconnected:
        return _isListening ? 'STARTING' : 'IDLE';
    }
  }

  Color get _statusColor {
    switch (_connectionState) {
      case GeminiLiveState.connected:
        return const Color(0xFF34C759);
      case GeminiLiveState.connecting:
      case GeminiLiveState.reconnecting:
        return const Color(0xFFFFB020);
      case GeminiLiveState.error:
        return const Color(0xFFFF453A);
      case GeminiLiveState.disconnected:
        return _isListening
            ? const Color(0xFFFFB020)
            : Colors.white.withOpacity(0.38);
    }
  }

  String get _message {
    if (_subtitle.isNotEmpty) return _subtitle;
    if (_errorMessage != null) return _errorMessage!;
    if (_isListening) return 'Listening for subtitles…';
    return 'Add your Gemini API key in Settings';
  }

  bool get _messageIsError => _subtitle.isEmpty && _errorMessage != null;

  @override
  Widget build(BuildContext context) {
    if (_isSettingsOpen) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SettingsPanel(
            hasSavedKey: _hasSavedKey,
            includeMicrophone: _includeMicrophone,
            showTranslation: _showTranslation,
            onSave: (apiKey, includeMic, showTranslation) => unawaited(
              _saveSettings(apiKey, includeMic, showTranslation),
            ),
            onRemove: () => unawaited(_removeKey()),
            onCancel: () => setState(() => _isSettingsOpen = false),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const _DragHandle(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SubtitleText(
                      statusLabel: _statusLabel,
                      statusColor: _statusColor,
                      message: _message,
                      isError: _messageIsError,
                    ),
                  ),
                  const SizedBox(width: 14),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => unawaited(_openSettings()),
                    icon: const Icon(
                      Icons.settings,
                      size: 20,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 14,
            child: _ModeBadge(showTranslation: _showTranslation),
          ),
        ],
      ),
    );
  }
}

/// Small indicator in the top-left corner describing the current output mode.
class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.showTranslation});

  final bool showTranslation;

  @override
  Widget build(BuildContext context) {
    final color = showTranslation
        ? const Color(0xFF34C759)
        : const Color(0xFFFF453A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        showTranslation ? 'T-MODE' : 'MONO MODE',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Drag handle that lets the user reposition the overlay window.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Drag to move the subtitle window',
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => windowManager.startDragging(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Icon(
              Icons.drag_indicator,
              color: Colors.white.withOpacity(0.6),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtitleText extends StatefulWidget {
  const _SubtitleText({
    required this.statusLabel,
    required this.statusColor,
    required this.message,
    required this.isError,
  });

  final String statusLabel;
  final Color statusColor;
  final String message;
  final bool isError;

  @override
  State<_SubtitleText> createState() => _SubtitleTextState();
}

class _SubtitleTextState extends State<_SubtitleText> {
  static const double _lineHeight = 18 * 1.25;
  static const double _visibleLines = 2;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToEnd();
  }

  @override
  void didUpdateWidget(_SubtitleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _scrollToEnd(
        animate:
            oldWidget.message.isNotEmpty && widget.message.isNotEmpty,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (!animate) {
        _scrollController.jumpTo(target);
        return;
      }
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.statusLabel,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: _lineHeight * _visibleLines,
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Text(
              widget.message,
              style: TextStyle(
                color: widget.isError
                    ? const Color(0xFFFF8A80)
                    : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
