import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/settings.dart';

/// Persisted active-server choice.
///
/// Survives navigation between tabs and app restarts. When the VPN is
/// running the choice also pushes through to Mihomo's selector group so
/// the running session switches immediately.
class ServerSelectionController extends StateNotifier<String?> {
  ServerSelectionController(this._prefs) : super(_prefs.getString(_key));

  final SharedPreferences _prefs;
  static const _key = 'kiss.selectedServer';

  void select(String? name) {
    state = name;
    if (name == null || name.isEmpty) {
      _prefs.remove(_key);
    } else {
      _prefs.setString(_key, name);
    }
  }
}

final serverSelectionProvider =
    StateNotifierProvider<ServerSelectionController, String?>((ref) {
  return ServerSelectionController(ref.watch(sharedPreferencesProvider));
});
