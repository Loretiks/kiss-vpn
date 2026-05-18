import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/tokens.dart';
import '../../shared/widgets/mesh_background.dart';
import '../../shared/widgets/titlebar.dart';
import '../logs/logs_page.dart';
import '../mode/mode_page.dart';
import '../servers/servers_page.dart';
import '../settings/settings_page.dart';
import '../subscription/subscription_page.dart';
import 'home_page.dart';

/// Active nav tab — exposed as a provider so any widget on the home
/// screen can navigate (e.g. tapping the active-server card jumps to
/// the Servers tab).
final activeTabProvider = StateProvider<int>((_) => 0);

/// Stable indices for known tabs.
class HomeTab {
  static const home = 0;
  static const servers = 1;
  static const mode = 2;
  static const subscription = 3;
  static const logs = 4;
  static const settings = 5;
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  bool _pinned = false;

  static const _items = [
    _NavItem(Icons.power_settings_new_rounded, 'Главная'),
    _NavItem(Icons.dns_rounded, 'Серверы'),
    _NavItem(Icons.tune_rounded, 'Режим'),
    _NavItem(Icons.link_rounded, 'Подписка'),
    _NavItem(Icons.terminal_rounded, 'Логи'),
    _NavItem(Icons.settings_rounded, 'Настройки'),
  ];

  Widget _page(int i) {
    switch (i) {
      case 0:
        return const HomePage();
      case 1:
        return const ServersPage();
      case 2:
        return const ModePage();
      case 3:
        return const SubscriptionPage();
      case 4:
        return const LogsPage();
      default:
        return const SettingsPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(activeTabProvider);
    return Scaffold(
      backgroundColor: KissColors.bg0,
      body: MeshBackground(
        intensity: index == 0 ? 1.0 : 0.55,
        child: Column(
          children: [
            Titlebar(
              pinned: _pinned,
              onPin: () => setState(() => _pinned = !_pinned),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NavRail(
                    index: index,
                    items: _items,
                    onSelect: (i) =>
                        ref.read(activeTabProvider.notifier).state = i,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: KissDurations.med,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.02, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(index),
                        child: _page(index),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.index,
    required this.items,
    required this.onSelect,
  });
  final int index;
  final List<_NavItem> items;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: KissSpacing.lg),
      decoration: const BoxDecoration(
        color: Color(0x801A1A26),
        border: Border(right: BorderSide(color: KissColors.stroke)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _NavButton(
              item: items[i],
              selected: i == index,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: KissSpacing.sm, vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Tooltip(
            message: widget.item.label,
            waitDuration: const Duration(milliseconds: 400),
            child: AnimatedContainer(
              duration: KissDurations.fast,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                // Discord-rail style: only hover gets a subtle wash; active
                // state lives entirely in the icon/label colour change.
                color: _hover && !widget.selected
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(KissRadius.md),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.item.icon,
                    size: 22,
                    color: widget.selected
                        ? KissColors.pink
                        : KissColors.textMid,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: widget.selected
                          ? KissColors.textHi
                          : KissColors.textLow,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
