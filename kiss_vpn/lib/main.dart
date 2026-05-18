import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'core/platform/single_instance.dart';
import 'core/platform/system_proxy.dart';
import 'core/platform/tray.dart';
import 'core/storage/secrets_store.dart';
import 'core/storage/settings.dart';
import 'core/subscription/subscription_repository.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!await SingleInstance.acquire()) {
    exit(0);
  }

  // Startup hygiene: if the last session crashed without reverting the
  // Windows system proxy, Chrome / Edge keep trying a dead 127.0.0.1:7890
  // and show "no internet". Detect & undo before the user notices.
  unawaited(SystemProxy.cleanupIfStale());

  final prefs = await SharedPreferences.getInstance();
  final secrets = SecretsStore(prefs);

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1100, 720),
      minimumSize: Size(900, 600),
      center: true,
      backgroundColor: Colors.transparent,
      title: 'Kiss VPN',
      titleBarStyle: TitleBarStyle.hidden,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  await TrayService.instance.init();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secretsStoreProvider.overrideWithValue(secrets),
      ],
      child: const KissVpnApp(),
    ),
  );
}
