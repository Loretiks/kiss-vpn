import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../ipc/helper_client.dart';
import '../platform/system_proxy.dart';
import '../rules/rule.dart';
import '../rules/rules_builder.dart';
import '../storage/settings.dart';
import '../rules/server_selection.dart';
import '../subscription/subscription_repository.dart';
import '../xray/grpc_bridge.dart';
import 'config_patcher.dart';
import 'config_writer.dart';
import 'mihomo_api.dart';
import 'process_manager.dart';

enum VpnStatus { disconnected, connecting, connected, disconnecting, error }

class VpnState {
  const VpnState({
    this.status = VpnStatus.disconnected,
    this.currentServer,
    this.currentEndpoint,
    this.latencyMs,
    this.downloadBps = 0,
    this.uploadBps = 0,
    this.totalDown = 0,
    this.totalUp = 0,
    this.connectedSince,
    this.usingHelper = false,
    this.usingTun = false,
    this.error,
  });

  final VpnStatus status;
  final String? currentServer;
  final String? currentEndpoint;
  final int? latencyMs;
  final int downloadBps;
  final int uploadBps;
  final int totalDown;
  final int totalUp;
  final DateTime? connectedSince;
  final bool usingHelper;
  final bool usingTun;
  final String? error;

  String get statusLabel {
    switch (status) {
      case VpnStatus.connected:
        final mode = usingTun ? 'TUN' : 'system proxy';
        return 'Connected · $mode';
      case VpnStatus.connecting:
        return 'Establishing tunnel…';
      case VpnStatus.disconnecting:
        return 'Tearing down tunnel…';
      case VpnStatus.disconnected:
        return 'Not connected';
      case VpnStatus.error:
        return error ?? 'Connection error';
    }
  }

  VpnState copyWith({
    VpnStatus? status,
    String? currentServer,
    String? currentEndpoint,
    int? latencyMs,
    int? downloadBps,
    int? uploadBps,
    int? totalDown,
    int? totalUp,
    DateTime? connectedSince,
    bool? usingHelper,
    bool? usingTun,
    String? error,
    bool clearError = false,
  }) {
    return VpnState(
      status: status ?? this.status,
      currentServer: currentServer ?? this.currentServer,
      currentEndpoint: currentEndpoint ?? this.currentEndpoint,
      latencyMs: latencyMs ?? this.latencyMs,
      downloadBps: downloadBps ?? this.downloadBps,
      uploadBps: uploadBps ?? this.uploadBps,
      totalDown: totalDown ?? this.totalDown,
      totalUp: totalUp ?? this.totalUp,
      connectedSince: connectedSince ?? this.connectedSince,
      usingHelper: usingHelper ?? this.usingHelper,
      usingTun: usingTun ?? this.usingTun,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class VpnController extends StateNotifier<VpnState> {
  VpnController(this._ref) : super(const VpnState());

  final Ref _ref;
  final _api = MihomoApi();
  final _proc = MihomoProcessManager();
  final _grpc = GrpcBridge();
  HelperClient? _helper;
  StreamSubscription<TrafficSample>? _trafficSub;

  /// Connect to the helper service. Returns false if it's unreachable.
  /// Sets [_helperElevated] as a side-effect so the connect flow can refuse
  /// TUN / killswitch when the helper isn't running with admin rights.
  bool _helperElevated = false;
  Future<bool> _probeHelper() async {
    final hc = HelperClient();
    try {
      final v = await hc.call('version', timeout: const Duration(seconds: 2));
      _helper = hc;
      _helperElevated = v['is_elevated'] == true;
      return true;
    } catch (_) {
      await hc.close();
      return false;
    }
  }

  Future<void> toggle() async {
    if (state.status == VpnStatus.connected) {
      await disconnect();
    } else if (state.status == VpnStatus.disconnected ||
        state.status == VpnStatus.error) {
      await connect();
    }
  }

  /// Probe the latency of every proxy in [names] via the Mihomo control plane.
  ///
  /// If the core is already up (user is connected) we just hit
  /// `/proxies/{name}/delay` against the running instance. Otherwise we spin
  /// up an ephemeral instance on the cached subscription config, run the
  /// probes in parallel, and tear it back down — without touching DNS,
  /// routes, the firewall, or the user-visible VPN state.
  Future<Map<String, int?>> probeLatencies(List<String> names) async {
    if (names.isEmpty) return const {};
    if (state.status == VpnStatus.connecting ||
        state.status == VpnStatus.disconnecting) {
      throw StateError('Дождитесь окончания текущей операции.');
    }

    final coreWasUp = await _api.isAlive();
    var startedHere = false;
    try {
      if (!coreWasUp) {
        await _startProbeInstance();
        startedHere = true;
      }
      final results = <String, int?>{};
      await Future.wait(names.map((n) async {
        try {
          results[n] = await _api.delay(name: n);
        } catch (_) {
          results[n] = null;
        }
      }));
      return results;
    } finally {
      if (startedHere) {
        await _proc.stop();
        await _grpc.teardown();
      }
    }
  }

  /// Best-effort lookup for the panel's selector group (e.g. `→ Remnawave`)
  /// so per-app rules can target the group rather than a single proxy and
  /// keep working when the user switches server.
  String? _resolveProxyGroup(String yaml) {
    final m = RegExp(r'^\s*-\s*name:\s*(.+?)\s*\n\s*type:\s*select',
            multiLine: true)
        .firstMatch(yaml);
    return m?.group(1)?.trim();
  }

  /// Polls Mihomo's `/configs` for up to 18 s waiting for the tun block to
  /// settle into `enable: true`. Mihomo's startup is `Start TUN listening`
  /// → 3× retry × 5 s = ~15 s, so we use a slightly longer ceiling.
  Future<bool> _waitForTunReady() async {
    final deadline = DateTime.now().add(const Duration(seconds: 18));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final cfg = await _api.getConfigs();
        final tun = cfg['tun'];
        if (tun is Map && tun['enable'] == true) return true;
      } catch (_) {/* core not ready yet */}
      await Future.delayed(const Duration(milliseconds: 600));
    }
    return false;
  }

  Future<void> _startProbeInstance() async {
    final repo = _ref.read(subscriptionRepositoryProvider);
    var yaml = await repo.cachedClashYaml() ?? '';
    if (yaml.isEmpty) {
      // No panel YAML cached — fall back to building one from the proxy list.
      final proxies = await repo.loadProxies();
      if (proxies.isEmpty) {
        throw StateError(
            'Подписка пуста — добавьте её на вкладке «Подписка».');
      }
      final profile = await _proc.profileDir();
      final tmpPath = p.join(profile.path, '.probe-generated.yaml');
      await ConfigWriter.writeConfig(
          path: tmpPath, proxies: proxies, tun: false);
      yaml = await File(tmpPath).readAsString();
    }
    yaml = ConfigPatcher.setMode(yaml, 'rule');
    yaml = ConfigPatcher.setController(yaml);
    yaml = ConfigPatcher.setTun(yaml, enable: false);

    final profile = await _proc.profileDir();
    // Funnel grpc proxies through the xray sidecar even during latency
    // probes — otherwise every grpc server reports infinity.
    yaml = await _grpc.setup(yaml, workDir: profile.path);
    final configPath = p.join(profile.path, 'probe.yaml');
    await File(configPath).writeAsString(yaml);
    await _proc.start(configPath: configPath);
  }

  Future<void> connect() async {
    state = state.copyWith(status: VpnStatus.connecting, clearError: true);
    try {
      final repo = _ref.read(subscriptionRepositoryProvider);
      final settings = _ref.read(settingsControllerProvider);
      final proxies = await repo.loadProxies();
      if (proxies.isEmpty) {
        throw StateError('No proxies in subscription. Add one first.');
      }

      // Resolve the config: prefer the panel-curated YAML, fall back to our
      // generated one. Either way we patch it with our routing preferences.
      var configYaml = await repo.cachedClashYaml() ?? '';
      if (configYaml.isEmpty) {
        final tmp = await _proc.profileDir();
        final tmpPath = p.join(tmp.path, '.generated.yaml');
        await ConfigWriter.writeConfig(
          path: tmpPath,
          proxies: proxies,
          tun: settings.tunMode,
        );
        configYaml = await File(tmpPath).readAsString();
      }
      configYaml = ConfigPatcher.setMode(configYaml, settings.routingMode);
      configYaml = ConfigPatcher.setController(configYaml);
      configYaml = ConfigPatcher.setTun(configYaml, enable: settings.tunMode);

      // Per-app scope: override the panel's `rules:` block with the user's
      // SplitRule list. Default action becomes DIRECT — anything the user
      // didn't list bypasses the tunnel.
      if (settings.scope == VpnScope.perApp) {
        final userRules = _ref.read(rulesControllerProvider);
        final body = RulesBuilder.build(
          rules: userRules,
          // Reference the panel-curated group when present, otherwise the
          // raw selected proxy name — either resolves to "via VPN" at
          // routing time and stays in sync with server selection.
          proxyTarget: _resolveProxyGroup(configYaml) ?? proxies.first.name,
          defaultTarget: 'DIRECT',
        );
        configYaml = ConfigPatcher.setRules(configYaml, body);
        // Force rule mode — global/direct would ignore the rules table.
        configYaml = ConfigPatcher.setMode(configYaml, 'rule');
      }

      final profile = await _proc.profileDir();
      // Spin up xray sidecar for any vless+grpc proxies in the config.
      // Mihomo's grpc transport is unary-only and the panel's xray server
      // drops those connections — see project memory
      // `project-mihomo-grpc-limitation`. After this call, grpc proxies in
      // the YAML have been rewritten as `type: socks5 → 127.0.0.1:<port>`
      // stubs that Mihomo will dial cleanly.
      configYaml = await _grpc.setup(configYaml, workDir: profile.path);
      final configPath = p.join(profile.path, 'config.yaml');
      await File(configPath).writeAsString(configYaml);

      // TUN requires admin → must go through the Helper. Plain proxy mode
      // can run as the current user (faster startup, no UAC).
      bool viaHelper = false;
      if (settings.tunMode || settings.killswitch) {
        viaHelper = await _probeHelper();
        if (!viaHelper) {
          throw StateError(
              'TUN-режим требует Helper Service. Запустите KissVPNHelper.exe '
              'от администратора или установите его как службу: '
              '`KissVPNHelper.exe install` (нужны права админа).');
        }
        if (!_helperElevated) {
          throw StateError(
              'Helper Service запущен без прав администратора — Mihomo '
              'не сможет поднять TUN-адаптер wintun и настроить маршруты. '
              'Перезапустите KissVPNHelper.exe от имени администратора либо '
              'переключите режим на Proxy.');
        }
      }

      if (viaHelper) {
        final corePath =
            p.join(p.dirname(Platform.resolvedExecutable), 'KissVPNCore.exe');
        await _helper!.call('start_vpn', params: {
          'core_path': corePath,
          'config_path': configPath,
          'work_dir': profile.path,
          'tun': settings.tunMode,
        });
        if (settings.killswitch) {
          await _helper!.call('apply_killswitch', params: {
            'enabled': true,
            'allow_executables': [
              corePath,
              Platform.resolvedExecutable,
            ],
          });
        }
      } else {
        await _proc.start(configPath: configPath);
      }

      // Honour the user's persisted server pick if it matches one in the
      // active subscription; otherwise default to the first entry.
      final savedName = _ref.read(serverSelectionProvider);
      final selected = proxies.firstWhere(
        (p) => p.name == savedName,
        orElse: () => proxies.first,
      );
      // Fan-out: set the chosen proxy in every Selector group that contains
      // it. Necessary because `mode: global` routes through the built-in
      // GLOBAL group (default DIRECT) while `mode: rule` routes through the
      // panel's `→ Remnawave` group — both need to flip to honour the
      // user's pick.
      try {
        await _api.selectProxyEverywhere(selected.name);
      } catch (_) {/* best-effort */}

      _trafficSub = _api.trafficStream().listen(
        (t) {
          state = state.copyWith(
            downloadBps: t.down,
            uploadBps: t.up,
            totalDown: state.totalDown + t.down,
            totalUp: state.totalUp + t.up,
          );
        },
        onError: (_) {/* status shown separately */},
      );

      // Detect whether TUN actually came up. Mihomo silently keeps running
      // when wintun fails (no kernel adapter, traffic leaks direct), so we
      // poll /configs after a brief grace window and fall back to proxy
      // mode if `tun.enable` is still false.
      var effectiveEngine = settings.engine;
      var tunReady = settings.engine != VpnEngine.tun;
      if (settings.engine == VpnEngine.tun) {
        tunReady = await _waitForTunReady();
        if (!tunReady) {
          effectiveEngine = VpnEngine.proxy;
        }
      }

      // Proxy-engine (or TUN-fallback) needs system proxy registry +
      // WinHTTP to actually catch app traffic. TUN-engine that successfully
      // came up doesn't need either — wintun intercepts at layer 3.
      if (effectiveEngine == VpnEngine.proxy) {
        await syncSystemProxy(connecting: true, engine: VpnEngine.proxy);
        if (viaHelper && _helper != null) {
          try {
            await _helper!.call('set_winhttp_proxy',
                params: {'host': '127.0.0.1', 'port': 7890});
          } catch (_) {/* best-effort, HKCU registry still active */}
        }
      }

      state = state.copyWith(
        status: VpnStatus.connected,
        currentServer: selected.name,
        currentEndpoint: '${selected.server}:${selected.port}',
        connectedSince: DateTime.now(),
        usingHelper: viaHelper,
        usingTun: tunReady && settings.engine == VpnEngine.tun,
        error: settings.engine == VpnEngine.tun && !tunReady
            ? 'TUN не поднялся (wintun не отвечает) — '
              'переключились на системный прокси.'
            : null,
      );
    } catch (e) {
      state = state.copyWith(status: VpnStatus.error, error: e.toString());
      await _proc.stop();
      await _grpc.teardown();
      try {
        await _helper?.call('stop_vpn');
      } catch (_) {/* best-effort */}
    }
  }

  Future<void> disconnect() async {
    state = state.copyWith(status: VpnStatus.disconnecting);
    await _trafficSub?.cancel();
    _trafficSub = null;

    // Restore the user's original Windows system proxy before tearing down
    // the core — that way no app is left pointed at a dead 7890 port.
    await syncSystemProxy(connecting: false, engine: VpnEngine.proxy);
    if (state.usingHelper && _helper != null) {
      try {
        await _helper!.call('reset_winhttp_proxy');
      } catch (_) {/* best-effort */}
    }

    if (state.usingHelper && _helper != null) {
      try {
        await _helper!.call('stop_vpn');
      } catch (_) {/* best-effort */}
      if (state.usingTun) {
        try {
          await _helper!.call('restore_dns');
          await _helper!.call('clear_routes');
        } catch (_) {/* best-effort */}
      }
      try {
        await _helper!.call('drop_killswitch');
      } catch (_) {/* best-effort */}
      await _helper?.close();
      _helper = null;
    } else {
      await _proc.stop();
    }

    // Sidecar must outlive Mihomo by a fraction so any in-flight tunnels
    // can flush — by the time we're here Mihomo is fully stopped.
    await _grpc.teardown();

    state = const VpnState();
  }

  @override
  void dispose() {
    _trafficSub?.cancel();
    _proc.stop();
    _grpc.teardown();
    _helper?.close();
    super.dispose();
  }
}

final vpnControllerProvider =
    StateNotifierProvider<VpnController, VpnState>((ref) => VpnController(ref));

/// Tiny helper for [Platform.isWindows] gating in widgets.
bool get isWindows => Platform.isWindows;
