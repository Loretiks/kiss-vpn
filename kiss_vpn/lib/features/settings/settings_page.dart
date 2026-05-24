import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ipc/helper_client.dart';
import '../../core/storage/settings.dart';
import '../../shared/theme/kiss_theme.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/heart_logo.dart';
import '../../shared/widgets/section_header.dart';
import 'update_card.dart';

enum _HelperStatus { checking, ok, noAdmin, notRunning }

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String? _helperStatus;
  _HelperStatus _helperStatusKind = _HelperStatus.checking;
  String _version = '…';

  @override
  void initState() {
    super.initState();
    _probeHelper();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  Future<void> _probeHelper() async {
    setState(() {
      _helperStatus = 'Проверяем…';
      _helperStatusKind = _HelperStatus.checking;
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
            _helperStatusKind = _HelperStatus.ok;
          } else {
            _helperStatus = 'Запущен без прав администратора · v${v['version']} · '
                'TUN-режим работать не будет — перезапустите от админа';
            _helperStatusKind = _HelperStatus.noAdmin;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _helperStatus = 'Не запущен — нужен для TUN-режима';
          _helperStatusKind = _HelperStatus.notRunning;
        });
      }
    } finally {
      await hc.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    final s = ref.watch(settingsControllerProvider);
    final c = ref.read(settingsControllerProvider.notifier);

    final helperColor = switch (_helperStatusKind) {
      _HelperStatus.checking => t.textLow,
      _HelperStatus.ok => t.success,
      _HelperStatus.noAdmin => t.warning,
      _HelperStatus.notRunning => t.warning,
    };

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
              subtitleColor: helperColor,
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
          _Section(title: 'Внешний вид', children: [
            _Row(
              title: 'Тема оформления',
              subtitle: 'Тёмная, светлая или по системе Windows.',
              trailing: SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor:
                      t.accent.withValues(alpha: 0.18),
                  selectedForegroundColor: t.accent,
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 34),
                ),
                segments: const [
                  ButtonSegment(value: 'kiss', label: Text('Kiss')),
                  ButtonSegment(value: 'dark', label: Text('Тёмная')),
                  ButtonSegment(value: 'light', label: Text('Светлая')),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => c.setThemeMode(v.first),
              ),
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
            _Row(
              title: 'Версия',
              subtitle: _version,
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
    final t = KissTheme.of(context);
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
                Text(
                  'Клиент для подписки kissmain.ru. VLESS + Reality, TUN-режим, '
                  'split-tunneling по правилам.',
                  style: TextStyle(
                    color: t.textMid,
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
    final t = KissTheme.of(context);
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
                            color: _hover ? t.accent : t.textHi,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '@${widget.telegram}',
                          style: TextStyle(
                            color: t.textLow,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.role,
                      style: TextStyle(
                        color: t.textMid,
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
    final t = KissTheme.of(context);
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
                ? t.accent.withValues(alpha: 0.14)
                : t.bg3,
            border: Border.all(
              color: _hover
                  ? t.accent.withValues(alpha: 0.5)
                  : t.stroke,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 13, color: t.accent),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: t.textHi,
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
    final t = KissTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: KissSpacing.sm),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: t.textLow,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              fontSize: 10.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: t.bg2.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(KissRadius.md),
            border: Border.all(color: t.stroke, width: 1),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                      height: 1, thickness: 1, color: t.stroke),
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
    final t = KissTheme.of(context);
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: t.textHi,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: subtitleColor ?? t.textMid,
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
