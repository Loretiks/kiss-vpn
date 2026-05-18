import 'package:shared_preferences/shared_preferences.dart';

/// Persistent key/value store for sensitive but low-risk data.
///
/// For the MVP this is plain SharedPreferences. We deliberately wrap it so
/// that swapping in Windows DPAPI (via the `win32` package) in Phase 5 only
/// changes this file. Treat the abstraction as future-DPAPI from day one:
/// never iterate keys, never serialize big structures.
class SecretsStore {
  SecretsStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<SecretsStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return SecretsStore(prefs);
  }

  Future<String?> read(String key) async => _prefs.getString(key);

  Future<void> write(String key, String? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }

  Future<void> delete(String key) async {
    await _prefs.remove(key);
  }
}
