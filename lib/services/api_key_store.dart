import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's Gemini API key and related preferences locally using
/// encrypted platform storage (Windows Credential Manager / DPAPI on Windows).
///
/// Values survive app restarts and are scoped to the current OS user.
class ApiKeyStore {
  ApiKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _apiKeyKey = 'gemini_api_key';
  static const String _includeMicKey = 'include_microphone';

  final FlutterSecureStorage _storage;

  /// Returns the stored API key, or `null` when none has been saved.
  Future<String?> readKey() async {
    final value = await _storage.read(key: _apiKeyKey);
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Saves [key]. Empty values are treated as a removal.
  Future<void> saveKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await clearKey();
      return;
    }
    await _storage.write(key: _apiKeyKey, value: trimmed);
  }

  /// Removes the stored API key.
  Future<void> clearKey() => _storage.delete(key: _apiKeyKey);

  /// Whether microphone audio should be captured alongside system audio.
  Future<bool> readIncludeMicrophone() async {
    final value = await _storage.read(key: _includeMicKey);
    return value == 'true';
  }

  /// Persists the microphone preference.
  Future<void> setIncludeMicrophone(bool include) {
    return _storage.write(key: _includeMicKey, value: include ? 'true' : 'false');
  }
}
