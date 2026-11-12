import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's Gemini API key and related preferences locally.
///
/// Values survive app restarts and are scoped to the current OS user.
///
/// Note: this uses `shared_preferences`, which stores values as plain text in
/// the app's local data folder. If the key needs to be encrypted at rest, swap
/// this implementation for platform secure storage (e.g. Windows Credential
/// Manager via DPAPI), which requires the Visual C++ ATL build component.
class ApiKeyStore {
  ApiKeyStore({Future<SharedPreferences> Function()? preferencesLoader})
      : _loadPreferences = preferencesLoader ?? SharedPreferences.getInstance;

  static const String _apiKeyKey = 'gemini_api_key';
  static const String _includeMicKey = 'include_microphone';
  static const String _showTranslationKey = 'show_translation';

  final Future<SharedPreferences> Function() _loadPreferences;

  /// Returns the stored API key, or `null` when none has been saved.
  Future<String?> readKey() async {
    final preferences = await _loadPreferences();
    final value = preferences.getString(_apiKeyKey);
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Saves [key]. Empty values are treated as a removal.
  Future<void> saveKey(String key) async {
    final preferences = await _loadPreferences();
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await preferences.remove(_apiKeyKey);
      return;
    }
    await preferences.setString(_apiKeyKey, trimmed);
  }

  /// Removes the stored API key.
  Future<void> clearKey() async {
    final preferences = await _loadPreferences();
    await preferences.remove(_apiKeyKey);
  }

  /// Whether microphone audio should be captured alongside system audio.
  Future<bool> readIncludeMicrophone() async {
    final preferences = await _loadPreferences();
    return preferences.getBool(_includeMicKey) ?? false;
  }

  /// Persists the microphone preference.
  Future<void> setIncludeMicrophone(bool include) async {
    final preferences = await _loadPreferences();
    await preferences.setBool(_includeMicKey, include);
  }

  /// Whether subtitles should show translated text instead of the source
  /// transcription.
  Future<bool> readShowTranslation() async {
    final preferences = await _loadPreferences();
    return preferences.getBool(_showTranslationKey) ?? false;
  }

  /// Persists the translation preference.
  Future<void> setShowTranslation(bool show) async {
    final preferences = await _loadPreferences();
    await preferences.setBool(_showTranslationKey, show);
  }
}
