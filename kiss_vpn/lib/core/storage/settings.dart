import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What gets routed through the VPN:
///   * [whole]    — every connection (TUN-mode hijack or system proxy).
///   * [perApp]   — only what the user added to the rules list.
enum VpnScope { whole, perApp }

/// Which transport carries the routed traffic:
///   * [proxy] — Mihomo's mixed-port at 127.0.0.1:7890 (browsers / apps that
///     respect system proxy). No admin needed.
///   * [tun]   — Wintun virtual adapter, OS sees a real network interface.
///     Catches every connection but needs admin via the Helper Service.
enum VpnEngine { proxy, tun }

class AppSettings {
  const AppSettings({
    this.scope = VpnScope.whole,
    this.engine = VpnEngine.proxy,
    this.killswitch = false,
    this.autostart = false,
    this.closeToTray = true,
    this.themeMode = 'dark',
    this.routingMode = 'rule',
  });

  final VpnScope scope;
  final VpnEngine engine;
  final bool killswitch;
  final bool autostart;
  final bool closeToTray;
  final String themeMode;       // dark | light | system
  final String routingMode;     // rule | global | direct

  /// True when the running config should bind a TUN inbound. Defined as a
  /// computed alias for backwards compatibility with `vpn_controller`.
  bool get tunMode => engine == VpnEngine.tun;

  AppSettings copyWith({
    VpnScope? scope,
    VpnEngine? engine,
    bool? killswitch,
    bool? autostart,
    bool? closeToTray,
    String? themeMode,
    String? routingMode,
  }) =>
      AppSettings(
        scope: scope ?? this.scope,
        engine: engine ?? this.engine,
        killswitch: killswitch ?? this.killswitch,
        autostart: autostart ?? this.autostart,
        closeToTray: closeToTray ?? this.closeToTray,
        themeMode: themeMode ?? this.themeMode,
        routingMode: routingMode ?? this.routingMode,
      );
}

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static AppSettings _load(SharedPreferences p) {
    VpnScope scope = VpnScope.whole;
    final scopeRaw = p.getString('kiss.scope');
    if (scopeRaw == 'perApp') scope = VpnScope.perApp;

    VpnEngine engine = VpnEngine.proxy;
    // Migrate from the previous boolean key.
    if (p.getString('kiss.engine') == 'tun' || p.getBool('kiss.tunMode') == true) {
      engine = VpnEngine.tun;
    }

    return AppSettings(
      scope: scope,
      engine: engine,
      killswitch: p.getBool('kiss.killswitch') ?? false,
      autostart: p.getBool('kiss.autostart') ?? false,
      closeToTray: p.getBool('kiss.closeToTray') ?? true,
      themeMode: p.getString('kiss.themeMode') ?? 'dark',
      routingMode: p.getString('kiss.routingMode') ?? 'rule',
    );
  }

  void setScope(VpnScope v) {
    state = state.copyWith(scope: v);
    _prefs.setString('kiss.scope', v.name);
  }

  void setEngine(VpnEngine v) {
    state = state.copyWith(engine: v);
    _prefs.setString('kiss.engine', v.name);
    _prefs.setBool('kiss.tunMode', v == VpnEngine.tun); // legacy key
  }

  /// Legacy: keeps the old call-site in `VpnController` working.
  void setTunMode(bool v) =>
      setEngine(v ? VpnEngine.tun : VpnEngine.proxy);

  void setKillswitch(bool v) {
    state = state.copyWith(killswitch: v);
    _prefs.setBool('kiss.killswitch', v);
  }

  void setAutostart(bool v) {
    state = state.copyWith(autostart: v);
    _prefs.setBool('kiss.autostart', v);
  }

  void setCloseToTray(bool v) {
    state = state.copyWith(closeToTray: v);
    _prefs.setBool('kiss.closeToTray', v);
  }

  void setThemeMode(String v) {
    state = state.copyWith(themeMode: v);
    _prefs.setString('kiss.themeMode', v);
  }

  void setRoutingMode(String v) {
    state = state.copyWith(routingMode: v);
    _prefs.setString('kiss.routingMode', v);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>(
    (ref) => throw UnimplementedError('Override sharedPreferencesProvider in ProviderScope'));

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  return SettingsController(ref.watch(sharedPreferencesProvider));
});
