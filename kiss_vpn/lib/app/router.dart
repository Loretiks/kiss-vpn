import 'package:flutter/material.dart';

import '../features/home/home_shell.dart';
import '../features/logs/logs_page.dart';
import '../features/mode/mode_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/servers/servers_page.dart';
import '../features/settings/settings_page.dart';
import '../features/subscription/subscription_page.dart';

class AppRouter {
  static const home = '/';
  static const servers = '/servers';
  static const mode = '/mode';
  static const subscription = '/subscription';
  static const settings = '/settings';
  static const logs = '/logs';
  static const onboarding = '/onboarding';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return _page(const HomeShell());
      case servers:
        return _page(const ServersPage());
      case mode:
        return _page(const ModePage());
      case subscription:
        return _page(const SubscriptionPage());
      case AppRouter.settings:
        return _page(const SettingsPage());
      case logs:
        return _page(const LogsPage());
      case onboarding:
        return _page(const OnboardingPage());
    }
    return null;
  }

  static MaterialPageRoute _page(Widget child) =>
      MaterialPageRoute(builder: (_) => child);
}
