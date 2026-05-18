import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ipc/helper_client.dart';
import '../../core/storage/settings.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/heart_logo.dart';
import '../../shared/widgets/section_header.dart';
import 'update_card.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String? _helperStatus;
  Color _helperColor = KissColors.textLow;

  @override
  void initState() {
    super.initState();
    _probeHelper();
  }

  Future<void> _probeHelper() async {
    setState(() {
      _helperStatus = 'Проверяем…';
      _helperColor = KissColors.textLow;
    });
    final hc = HelperClient();
    try {
      final v = await hc.call('version', timeout: const Duration(seconds: 2));
      final elevated = v['is_elevated'] == true;
      if (mounted) {
        setState(() {
          if (elevated) {
            _helperStatus = 'Запущен от администратора · v${v['version']} · '
                'TUN доступен';
            _helperColor = KissColors.success;
          } else {
            _helperStatus = 'Запущен без прав администратора · v${v['version']} · '
                'TUN-режим работать не будет — перезапустите от админа';
            _helperColor = KissColors.warning;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _helperStatus = 'Не запущен — нужен для TUN-режима';
          _helperColor = KissColors.warning;
        });
      }
    } finally {
      await hc.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsControllerProvider);
    final c = ref.read(settingsControllerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          KissSpacing.x4, KissSpacing.x3, KissSpacing.x4, KissSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            eyebrow: 'Параметры',
            title: 'Настройки',
            subtitle:
                'Тонкая настройка маршрутизации, поведения окна и автозапуска.',
          ),
          const SizedBox(height: KissSpacing.xl),
          _Section(title: 'Обновления', children: const [
            Padding(
              padding: EdgeInsets.zero,
              child: UpdateCard(),
            ),
          ]),
          const SizedBox(height: KissSpacing.lg),
          _Section(title: 'Подключение', children: [
            _Row(
              title: 'Kill switch',
              subtitle:
                  'Блокировать весь трафик, если VPN внезапно упал. Работает через Helper Service.',
              trailing: Switch(value: s.killswitch, onChanged: c.setKillswitch),
            ),
            _Row(
              title: 'Режим маршрутизации',
              subtitle:
                  'rule — по правилам подписки · global — всё через прокси · direct — без прокси',
              trailing: DropdownButton<String>(
                value: s.routingMode,
                items: const [
                  DropdownMenuItem(value: 'rule', child: Text('rule')),
                  DropdownMenuItem(value: 'global', child: Text('global')),
                  DropdownMenuItem(value: 'direct', child: Text('direct')),
                ],
                onChanged: (v) {
                  if (v != null) c.setRoutingMode(v);
                },
              ),
            ),
          ]),
          const SizedBox(height: KissSpacing.lg),
          _Section(title: 'Helper Service', children: [
            _Row(
              title: 'Статус',
              subtitle: _helperStatus,
              subtitleColor: _helperColor,
              trailing: IconButton(
                tooltip: 'Проверить заново',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _probeHelper,
              ),
            ),
            const _Row(
              title: 'Установка',
              subtitle:
                  'Чтобы поднять как службу Windows, запустите от администратора: KissVPNHelper.exe install',
            ),
          ]),
          const SizedBox(height: KissSpacing.lg),
          _Section(title: 'Запуск и окно', children: [
            _Row(
              title: 'Запускать вместе с Windows',
              trailing: Switch(value: s.autostart, onChanged: c.setAutostart),
            ),
            _Row(
              title: 'Сворачивать в трей при закрытии',
              subtitle: 'Закрытие окна крестиком прячет приложение в трей.',
              trailing:
                  Switch(value: s.closeToTray, onChanged: c.setCloseToTray),
            ),
          ]),
          const SizedBox(height: KissSpacing.lg),
          _Section(title: 'О приложении', children: [
            const _AboutHeader(),
            const _Row(
              title: 'Версия',
              subtitle: '0.1.0',
            ),
            _Row(
              title: 'Сайт',
              subtitle: 'kissmain.ru',
              trailing: _LinkChip(
                label: 'Открыть',
                onTap: () => _open('https://kissmain.ru'),
              ),
            ),
          ]),
          const SizedBox(height: KissSpacing.lg),
          _Section(title: 'Авторы', children: [
            _AuthorRow(
              name: 'melanholy',
              role: 'разработка, дизайн, идея',
              telegram: 'm3lanh0lyy',
              onTap: () => _open('https://t.me/m3lanh0lyy'),
            ),
          ]),
          const SizedBox(height: KissSpacing.x3),
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {/* ignore */}
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: KissSpacing.lg, vertical: KissSpacing.lg),
      child: Row(
        children: [
          const HeartLogo(size: 36, glow: true),
          const SizedBox(width: KissSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kiss VPN',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Клиент для подписки kissmain.ru. VLESS + Reality, TUN-режим, '
                  'split-tunneling по правилам.',
                  style: TextStyle(
                    color: KissColors.textMid,
                    fontSize: 12.5,
                    height: 1.4,
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

class _AuthorRow extends StatefulWidget {
  const _AuthorRow({
    required this.name,
    required this.role,
    required this.telegram,
    required this.onTap,
  });
  final String name;
  final String role;
  final String telegram;
  final VoidCallback onTap;

  @override
  State<_AuthorRow> createState() => _AuthorRowState();
}

class _AuthorRowState extends State<_AuthorRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: KissSpacing.lg, vertical: KissSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: KissGradients.brand,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: KissSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.name,
                          style: TextStyle(
                            color: _hover ? KissColors.pink : KissColors.textHi,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '@${widget.telegram}',
                          style: const TextStyle(
                            color: KissColors.textLow,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.role,
                      style: const TextStyle(
                        color: KissColors.textMid,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _LinkChip(label: 'Telegram', icon: Icons.send_rounded, onTap: widget.onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkChip extends StatefulWidget {
  const _LinkChip({required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<_LinkChip> createState() => _LinkChipState();
}

class _LinkChipState extends State<_LinkChip> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: KissDurations.fast,
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hover
                ? KissColors.pink.withValues(alpha: 0.14)
                : KissColors.bg3,
            border: Border.all(
              color: _hover
                  ? KissColors.pink.withValues(alpha: 0.5)
                  : KissColors.stroke,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 13, color: KissColors.pink),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: const TextStyle(
                  color: KissColors.textHi,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: KissSpacing.sm),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: KissColors.textLow,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              fontSize: 10.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: KissColors.bg2.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(KissRadius.md),
            border: Border.all(color: KissColors.stroke, width: 1),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1, thickness: 1, color: KissColors.stroke),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: KissSpacing.lg, vertical: KissSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: KissColors.textHi,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: subtitleColor ?? KissColors.textMid,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
