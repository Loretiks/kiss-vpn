import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../core/mihomo/vpn_controller.dart';
import '../core/platform/tray.dart';
import '../core/storage/settings.dart';
import '../core/updater/update_controller.dart';
import '../shared/theme/app_theme.dart';
import 'router.dart';

class KissVpnApp extends ConsumerStatefulWidget {
  const KissVpnApp({super.key});

  @override
  ConsumerState<KissVpnApp> createState() => _KissVpnAppState();
}

class _KissVpnAppState extends ConsumerState<KissVpnApp> {
  Timer? _updateCheckTimer;

  @override
  void initState() {
    super.initState();
    // First check ~2 s after launch so the window and IPC settle before
    // we hit the network; then every 6 hours while the app is open.
    Future<void>.delayed(const Duration(seconds: 2), _silentCheck);
    _updateCheckTimer =
        Timer.periodic(const Duration(hours: 6), (_) => _silentCheck());

    TrayService.instance.setCallbacks(
      onToggle: () => ref.read(vpnControllerProvider.notifier).toggle(),
      onQuit: () async {
        await ref.read(vpnControllerProvider.notifier).disconnect();
        await windowManager.destroy();
      },
    );
  }

  void _silentCheck() {
    if (!mounted) return;
    ref.read(updateControllerProvider.notifier).checkSilent();
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeStr = ref.watch(settingsControllerProvider).themeMode;

    final vpnStatus = ref.watch(vpnControllerProvider).status;
    TrayService.instance.updateConnected(vpnStatus == VpnStatus.connected);

    // Three themes: kiss (branded), dark (neutral), light.
    // MaterialApp only supports theme + darkTheme + themeMode, so we pick
    // the right ThemeData directly and force ThemeMode.light or .dark.
    final ThemeData effectiveTheme;
    final ThemeMode effectiveMode;
    switch (themeStr) {
      case 'light':
        effectiveTheme = AppTheme.light();
        effectiveMode = ThemeMode.light;
      case 'dark':
        effectiveTheme = AppTheme.dark();
        effectiveMode = ThemeMode.dark;
      default: // 'kiss'
        effectiveTheme = AppTheme.kiss();
        effectiveMode = ThemeMode.dark;
    }

    return MaterialApp(
      title: 'Kiss VPN',
      debugShowCheckedModeBanner: false,
      theme: themeStr == 'light' ? effectiveTheme : AppTheme.light(),
      darkTheme: themeStr == 'light' ? null : effectiveTheme,
      themeMode: effectiveMode,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.home,
    );
  }
}
