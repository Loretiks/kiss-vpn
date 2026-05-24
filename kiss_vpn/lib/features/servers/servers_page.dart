import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mihomo/mihomo_api.dart';
import '../../core/mihomo/vpn_controller.dart';
import '../../core/probes/tcp_ping.dart';
import '../../core/rules/server_selection.dart';
import '../../core/subscription/subscription_repository.dart';
import '../../core/subscription/vless_proxy.dart';
import '../../shared/theme/kiss_theme.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/server_card.dart';

/// «Серверы» — список с флагами, выбором активного и пингом каждого.
///
/// Пинг — прямой TCP до `host:port` через `dart:io Socket` (точно так же,
/// как делают SnowVPN, FlClashX, Hiddify). Ядро запускать не нужно, ничего
/// эфемерного не поднимаем — это банальный замер RTT до edge сервера.
class ServersPage extends ConsumerStatefulWidget {
  const ServersPage({super.key});

  @override
  ConsumerState<ServersPage> createState() => _ServersPageState();
}

class _ServersPageState extends ConsumerState<ServersPage> {
  List<VlessProxy> _proxies = const [];
  final Map<String, int?> _delays = {};
  bool _loading = true;
  bool _pinging = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final proxies =
          await ref.read(subscriptionRepositoryProvider).loadProxies();
      if (mounted) setState(() => _proxies = proxies);
    } catch (_) {
      if (mounted) setState(() => _proxies = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pingAll() async {
    if (_proxies.isEmpty) return;
    setState(() {
      _pinging = true;
      // Reset stale numbers so the UI shows fresh activity.
      for (final p in _proxies) {
        _delays[p.name] = null;
      }
    });

    final targets = <String, ({String host, int port})>{
      for (final p in _proxies) p.name: (host: p.server, port: p.port),
    };

    // Stream results back as each socket settles. Doing this per-server
    // (instead of waiting for the whole batch) gives the user instant
    // feedback — same UX as SnowVPN's per-row spinner-to-number flip.
    await Future.wait(targets.entries.map((e) async {
      final ms = await TcpPing.probe(e.value.host, e.value.port);
      if (!mounted) return;
      setState(() => _delays[e.key] = ms == -1 ? 0 : ms);
    }));

    if (mounted) setState(() => _pinging = false);
  }

  /// Selecting a server has two effects, applied in order:
  ///   1. **Optimistic** — persist the pick immediately so the card lights up
  ///      and the next Connect uses it. No network roundtrip blocks the UI.
  ///   2. **Live** — if the core is up, fan-out the choice into every
  ///      Selector group that contains this proxy (notably `→ Remnawave`
  ///      AND `GLOBAL`), so traffic switches whether the user is in `rule`
  ///      or `global` routing mode.
  void _select(VlessProxy p) {
    ref.read(serverSelectionProvider.notifier).select(p.name);
    () async {
      final api = MihomoApi();
      if (!await api.isAlive()) return;
      await api.selectProxyEverywhere(p.name);
    }();
  }

  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    final vpn = ref.watch(vpnControllerProvider);
    final busy = vpn.status == VpnStatus.connecting ||
        vpn.status == VpnStatus.disconnecting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          KissSpacing.x4, KissSpacing.x3, KissSpacing.x4, KissSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            eyebrow: 'Сеть',
            title: 'Серверы',
            subtitle: _proxies.isEmpty
                ? null
                : 'Доступно: ${_proxies.length} · '
                    '${vpn.status == VpnStatus.connected ? "ядро запущено" : "эфемерный режим"}',
            action: _pinging
                ? const _PingingSpinner()
                : GradientButton(
                    label: 'Пинговать все',
                    icon: Icons.network_check_rounded,
                    compact: true,
                    onPressed:
                        (_proxies.isEmpty || busy) ? null : _pingAll,
                  ),
          ),
          const SizedBox(height: KissSpacing.xl),
          Expanded(child: _body(vpn, t)),
        ],
      ),
    );
  }

  Widget _body(VpnState vpn, KissTheme t) {
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(color: t.accent));
    }
    if (_proxies.isEmpty) {
      return Center(
        child: Text(
          'Список пуст — добавьте подписку на вкладке «Подписка».',
          style: TextStyle(color: t.textMid),
        ),
      );
    }
    final saved = ref.watch(serverSelectionProvider);
    final current = saved ?? vpn.currentServer;
    return ListView.separated(
      itemCount: _proxies.length,
      separatorBuilder: (_, __) => const SizedBox(height: KissSpacing.sm),
      itemBuilder: (_, i) {
        final p = _proxies[i];
        return ServerCard(
          proxy: p,
          selected: current == p.name,
          delayMs: _delays[p.name],
          onTap: () => _select(p),
        );
      },
    );
  }
}

class _PingingSpinner extends StatelessWidget {
  const _PingingSpinner();
  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: KissSpacing.lg, vertical: KissSpacing.sm + 1),
      decoration: BoxDecoration(
        color: t.bg2,
        border: Border.all(color: t.stroke),
        borderRadius: BorderRadius.circular(KissRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: t.accent),
          ),
          SizedBox(width: KissSpacing.sm),
          Text(
            'Пингуем…',
            style: TextStyle(
              color: t.textHi,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
