import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return MaterialApp(
      title: 'Kiss VPN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.home,
    );
  }
}
