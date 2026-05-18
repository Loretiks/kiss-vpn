import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Owns the system tray icon and menu for Kiss VPN.
class TrayService with TrayListener {
  TrayService._();
  static final TrayService instance = TrayService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    trayManager.addListener(this);

    final iconPath = await _extractIcon();
    if (iconPath != null) {
      await trayManager.setIcon(iconPath);
    }
    await trayManager.setToolTip('Kiss VPN');
    await _refreshMenu(connected: false);
  }

  Future<void> _refreshMenu({required bool connected}) async {
    final menu = Menu(items: [
      MenuItem(
        key: 'toggle',
        label: connected ? 'Отключиться' : 'Подключиться',
      ),
      MenuItem.separator(),
      MenuItem(key: 'show', label: 'Показать окно'),
      MenuItem(key: 'quit', label: 'Выйти'),
    ]);
    await trayManager.setContextMenu(menu);
  }

  Future<String?> _extractIcon() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'kiss_tray.ico'));
      if (!await file.exists()) {
        final bytes = await rootBundle.load('assets/images/tray.ico');
        await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      }
      return file.path;
    } catch (_) {
      return null;
    }
  }

  @override
  void onTrayIconMouseDown() => windowManager.show();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        break;
      case 'quit':
        windowManager.destroy();
        break;
      case 'toggle':
        // Connect toggling is wired in by HomeViewModel via a callback once
        // the tray is hooked into the VPN controller (Фаза 1+).
        windowManager.show();
        break;
    }
  }
}
