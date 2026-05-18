import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/subscription/sub_fetcher.dart';
import '../../core/subscription/subscription_repository.dart';
import '../../core/subscription/vless_proxy.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/utils/country.dart';
import '../../shared/utils/format.dart';
import '../../shared/widgets/flag.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/section_header.dart';

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  final _urlCtl = TextEditingController();
  bool _loading = false;
  String? _error;
  List<VlessProxy> _lastProxies = const [];
  SubInfo? _info;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void dispose() {
    _urlCtl.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final url = await repo.getUrl();
    if (url != null) _urlCtl.text = url;
    final info = await repo.cachedInfo();
    final upd = await repo.lastUpdate();
    final cached =
        await repo.loadProxies().catchError((_) => <VlessProxy>[]);
    if (mounted) {
      setState(() {
        _info = info;
        _updatedAt = upd;
        _lastProxies = cached;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.setUrl(_urlCtl.text.trim());
      final proxies = await repo.refresh();
      final info = await repo.cachedInfo();
      final upd = await repo.lastUpdate();
      if (mounted) {
        setState(() {
          _lastProxies = proxies;
          _info = info;
          _updatedAt = upd;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatUpdated(DateTime t) {
    final loc = t.toLocal();
    final hh = loc.hour.toString().padLeft(2, '0');
    final mm = loc.minute.toString().padLeft(2, '0');
    return '${loc.day.toString().padLeft(2, '0')}.${loc.month.toString().padLeft(2, '0')}.${loc.year} в $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          KissSpacing.x4, KissSpacing.x3, KissSpacing.x4, KissSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            eyebrow: 'Подключение',
            title: 'Подписка',
            subtitle:
                'Вставьте ссылку с kissmain.ru — мы скачаем список серверов и настроим Mihomo за вас.',
          ),
          const SizedBox(height: KissSpacing.xl),
          _UrlCard(
            controller: _urlCtl,
            loading: _loading,
            updatedAt: _updatedAt == null
                ? null
                : 'Последнее обновление: ${_formatUpdated(_updatedAt!)}',
            onRefresh: _refresh,
            error: _error,
          ),
          const SizedBox(height: KissSpacing.lg),
          if (_info != null) _SubInfoCard(info: _info!),
          const SizedBox(height: KissSpacing.lg),
          Text(
            'Серверы (${_lastProxies.length})',
            style: const TextStyle(
              color: KissColors.textMid,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: KissSpacing.sm),
          for (final p in _lastProxies)
            Padding(
              padding: const EdgeInsets.only(bottom: KissSpacing.sm),
              child: _MiniServerRow(proxy: p),
            ),
        ],
      ),
    );
  }
}

class _UrlCard extends StatelessWidget {
  const _UrlCard({
    required this.controller,
    required this.loading,
    required this.updatedAt,
    required this.onRefresh,
    required this.error,
  });
  final TextEditingController controller;
  final bool loading;
  final String? updatedAt;
  final VoidCallback onRefresh;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KissSpacing.xl),
      decoration: BoxDecoration(
        color: KissColors.bg2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(KissRadius.md),
        border: Border.all(color: KissColors.stroke, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Ссылка на подписку',
              hintText: 'https://kissmain.ru/sub/...',
              prefixIcon: Icon(Icons.link_rounded,
                  size: 18, color: KissColors.textLow),
            ),
          ),
          const SizedBox(height: KissSpacing.lg),
          Row(
            children: [
              GradientButton(
                label: loading ? 'Обновляем…' : 'Обновить сейчас',
                icon: loading ? null : Icons.refresh_rounded,
                compact: true,
                onPressed: loading ? null : onRefresh,
              ),
              const SizedBox(width: KissSpacing.md),
              if (updatedAt != null)
                Expanded(
                  child: Text(
                    updatedAt!,
                    style: const TextStyle(color: KissColors.textLow),
                  ),
                ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: KissSpacing.md),
            Container(
              padding: const EdgeInsets.all(KissSpacing.md),
              decoration: BoxDecoration(
                color: KissColors.danger.withValues(alpha: 0.08),
                border: Border.all(
                    color: KissColors.danger.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(KissRadius.sm),
              ),
              child: Text(
                error!,
                style: const TextStyle(
                  color: KissColors.danger,
                  fontSize: 12,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubInfoCard extends StatelessWidget {
  const _SubInfoCard({required this.info});
  final SubInfo info;

  @override
  Widget build(BuildContext context) {
    final ratio = info.total == 0
        ? 0.0
        : (info.used / info.total).clamp(0.0, 1.0);
    final left =
        info.total == 0 ? null : Format.bytes(info.remaining.clamp(0, 1 << 62));

    return Container(
      padding: const EdgeInsets.all(KissSpacing.xl),
      decoration: BoxDecoration(
        color: KissColors.bg2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(KissRadius.md),
        border: Border.all(color: KissColors.stroke, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Трафик',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (info.expire != null)
                Text(
                  'до ${info.expire!.toLocal().day}.${info.expire!.toLocal().month}.${info.expire!.toLocal().year}',
                  style: const TextStyle(color: KissColors.textMid),
                ),
            ],
          ),
          const SizedBox(height: KissSpacing.md),
          Row(
            children: [
              Text(
                Format.bytes(info.used),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: KissColors.textHi,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (info.total > 0) ...[
                const SizedBox(width: KissSpacing.sm),
                Text(
                  '/ ${Format.bytes(info.total)}',
                  style: const TextStyle(
                    color: KissColors.textMid,
                    fontSize: 14,
                  ),
                ),
              ],
              const Spacer(),
              if (left != null)
                Text(
                  'осталось $left',
                  style: const TextStyle(color: KissColors.textMid),
                ),
            ],
          ),
          const SizedBox(height: KissSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: KissColors.bg3),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: const DecoratedBox(
                      decoration:
                          BoxDecoration(gradient: KissGradients.brand),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniServerRow extends StatelessWidget {
  const _MiniServerRow({required this.proxy});
  final VlessProxy proxy;
  @override
  Widget build(BuildContext context) {
    final country = Country.parse(proxy.name);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: KissSpacing.md, vertical: KissSpacing.sm + 2),
      decoration: BoxDecoration(
        color: KissColors.bg2,
        borderRadius: BorderRadius.circular(KissRadius.sm),
        border: Border.all(color: KissColors.stroke, width: 1),
      ),
      child: Row(
        children: [
          FlagBadge(country: country, size: 32),
          const SizedBox(width: KissSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  country.clean.isEmpty ? proxy.name : country.clean,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${proxy.server}:${proxy.port} · ${proxy.security ?? "plain"}'
                  '${proxy.flow != null ? ' · ${proxy.flow}' : ''}',
                  style: const TextStyle(
                    color: KissColors.textLow,
                    fontSize: 11.5,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
