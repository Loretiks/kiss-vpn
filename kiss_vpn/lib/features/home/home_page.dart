import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mihomo/vpn_controller.dart';
import '../../core/rules/server_selection.dart';
import '../../core/storage/settings.dart';
import '../../core/subscription/subscription_repository.dart';
import '../../core/subscription/vless_proxy.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/utils/country.dart';
import '../../shared/widgets/connect_button.dart';
import '../../shared/widgets/flag.dart';
import '../../shared/widgets/option_card.dart';
import '../../shared/widgets/stat_chip.dart';
import 'home_shell.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpn = ref.watch(vpnControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final settingsCtl = ref.read(settingsControllerProvider.notifier);

    return LayoutBuilder(
      builder: (context, c) {
        final tightHeight = c.maxHeight < 720;
        final connectSize = tightHeight ? 184.0 : 220.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              KissSpacing.x4, KissSpacing.lg, KissSpacing.x4, KissSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight - KissSpacing.x4),
            child: Column(
              // Center the stack vertically when the viewport is taller than
              // the content — otherwise it sticks to the top and leaves the
              // bottom of the window empty.
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ConnectButton(
                  size: connectSize,
                  status: vpn.status,
                  onTap: () =>
                      ref.read(vpnControllerProvider.notifier).toggle(),
                ),
                const SizedBox(height: KissSpacing.md),
                _StatusLine(state: vpn),
                SizedBox(height: tightHeight ? KissSpacing.lg : KissSpacing.xl),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: Column(
                    children: [
                      const _ServerLine(),
                      const SizedBox(height: KissSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: StatChip(
                              label: 'СКАЧИВАНИЕ',
                              icon: Icons.arrow_downward_rounded,
                              bytesPerSecond: vpn.downloadBps,
                              totalBytes: vpn.totalDown,
                              color: KissColors.success,
                            ),
                          ),
                          const SizedBox(width: KissSpacing.md),
                          Expanded(
                            child: StatChip(
                              label: 'ЗАГРУЗКА',
                              icon: Icons.arrow_upward_rounded,
                              bytesPerSecond: vpn.uploadBps,
                              totalBytes: vpn.totalUp,
                              color: KissColors.violet,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KissSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: OptionCard(
                              label: 'Правила',
                              icon: Icons.tune_rounded,
                              value: _routingLabel(settings.routingMode),
                              onTap: () => settingsCtl.setRoutingMode(
                                  _cycleRouting(settings.routingMode)),
                              tooltip:
                                  'rule = по правилам · global = всё через прокси · direct = без прокси',
                            ),
                          ),
                          const SizedBox(width: KissSpacing.md),
                          Expanded(
                            child: OptionCard(
                              label: 'Режим',
                              icon: Icons.code_rounded,
                              value: settings.engine == VpnEngine.tun
                                  ? 'TUN'
                                  : 'Proxy',
                              onTap: () => settingsCtl.setEngine(
                                  settings.engine == VpnEngine.tun
                                      ? VpnEngine.proxy
                                      : VpnEngine.tun),
                              tooltip:
                                  'Proxy = только системный прокси · TUN = весь трафик через туннель',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (vpn.status == VpnStatus.error && vpn.error != null) ...[
                  const SizedBox(height: KissSpacing.lg),
                  _ErrorBanner(message: vpn.error!),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

String _routingLabel(String mode) {
  switch (mode) {
    case 'global':
      return 'Global';
    case 'direct':
      return 'Direct';
    default:
      return 'Правила';
  }
}

String _cycleRouting(String mode) {
  switch (mode) {
    case 'rule':
      return 'global';
    case 'global':
      return 'direct';
    default:
      return 'rule';
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});
  final VpnState state;

  Color get _dotColor => switch (state.status) {
        VpnStatus.connected => KissColors.success,
        VpnStatus.connecting => KissColors.warning,
        VpnStatus.disconnecting => KissColors.warning,
        VpnStatus.error => KissColors.danger,
        VpnStatus.disconnected => KissColors.textLow,
      };

  String get _label => switch (state.status) {
        VpnStatus.connected => state.usingTun
            ? 'Подключено • TUN'
            : 'Подключено • системный прокси',
        VpnStatus.connecting => 'Поднимаем туннель',
        VpnStatus.disconnecting => 'Закрываем туннель',
        VpnStatus.disconnected => 'Не подключено',
        VpnStatus.error => 'Ошибка подключения',
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: _dotColor.withValues(alpha: 0.55), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(width: KissSpacing.sm),
        Text(
          _label,
          style: const TextStyle(
            color: KissColors.textMid,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _ServerLine extends ConsumerWidget {
  const _ServerLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpn = ref.watch(vpnControllerProvider);
    final saved = ref.watch(serverSelectionProvider);
    final name = vpn.currentServer ?? saved;

    // Tapping the card jumps straight to the Servers tab so the user
    // can swap server without going through the rail manually.
    void openServers() =>
        ref.read(activeTabProvider.notifier).state = HomeTab.servers;

    if (name == null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: openServers,
          borderRadius: BorderRadius.circular(KissRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: KissSpacing.lg, vertical: KissSpacing.lg),
            decoration: BoxDecoration(
              color: KissColors.bg2.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(KissRadius.md),
              border: Border.all(color: KissColors.stroke, width: 1),
            ),
            child: const Row(
              children: [
                Icon(Icons.public_off_rounded, color: KissColors.textLow),
                SizedBox(width: KissSpacing.md),
                Expanded(
                  child: Text(
                    'Сервер не выбран — нажмите, чтобы выбрать.',
                    style: TextStyle(color: KissColors.textMid),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: KissColors.textLow),
              ],
            ),
          ),
        ),
      );
    }

    String? endpoint = vpn.currentEndpoint;
    if (endpoint == null) {
      final list = ref.watch(proxiesProvider).valueOrNull ?? const [];
      final found = list.firstWhere(
        (p) => p.name == name,
        orElse: () => const VlessProxy(
            name: '', uuid: '', server: '', port: 0, network: 'tcp'),
      );
      if (found.server.isNotEmpty) {
        endpoint = '${found.server}:${found.port}';
      }
    }

    final country = Country.parse(name);
    final connected = vpn.status == VpnStatus.connected;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: openServers,
        borderRadius: BorderRadius.circular(KissRadius.md),
        splashColor: KissColors.violet.withValues(alpha: 0.08),
        highlightColor: KissColors.violet.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(KissSpacing.lg),
          decoration: BoxDecoration(
            color: KissColors.bg2.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(KissRadius.md),
            border: Border.all(color: KissColors.stroke, width: 1),
          ),
          child: Row(
            children: [
              FlagBadge(country: country, size: 44),
              const SizedBox(width: KissSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        country.clean.isEmpty ? name : country.clean,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: KissColors.textHi,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!connected) ...[
                      const SizedBox(width: KissSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: KissColors.violet.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color:
                                  KissColors.violet.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'ВЫБРАН',
                          style: TextStyle(
                            color: KissColors.violet,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  endpoint ?? '—',
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    color: KissColors.textLow,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (vpn.latencyMs != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: KissSpacing.md, vertical: 6),
              decoration: BoxDecoration(
                color: KissColors.bg3,
                borderRadius: BorderRadius.circular(KissRadius.pill),
              ),
              child: Text(
                '${vpn.latencyMs} мс',
                style: const TextStyle(
                  color: KissColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(width: KissSpacing.sm),
          const Icon(Icons.chevron_right_rounded,
              color: KissColors.textLow, size: 18),
        ],
      ),
    ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KissSpacing.lg),
      constraints: const BoxConstraints(maxWidth: 580),
      decoration: BoxDecoration(
        color: KissColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KissRadius.md),
        border: Border.all(
            color: KissColors.danger.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline,
              color: KissColors.danger, size: 18),
          const SizedBox(width: KissSpacing.md),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: KissColors.danger,
                fontSize: 12.5,
                fontFamily: 'JetBrains Mono',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
