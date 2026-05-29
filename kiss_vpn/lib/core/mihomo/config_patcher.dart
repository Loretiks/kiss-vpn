/// Patches a Mihomo (Clash.Meta) YAML config received from the panel with
/// our local preferences. We intentionally avoid a full YAML parse-and-emit
/// round-trip (which would canonicalise key order, drop comments and
/// reflow lists) — instead we operate on the raw text in idempotent steps.
class ConfigPatcher {
  /// Force a given dispatch [mode] (`rule` / `global` / `direct`).
  static String setMode(String yaml, String mode) =>
      _setScalar(yaml, 'mode', mode);

  /// Pin the local SOCKS+HTTP inbound to [port] (Mihomo default 7890).
  /// Used when the default is occupied by another VPN client.
  static String setMixedPort(String yaml, int port) =>
      _setScalar(yaml, 'mixed-port', '$port');

  /// Pin the REST controller to [host]:[port] with optional bearer [secret].
  static String setController(String yaml, {String host = '127.0.0.1', int port = 9090, String? secret}) {
    var out = _setScalar(yaml, 'external-controller', '$host:$port');
    if (secret != null && secret.isNotEmpty) {
      out = _setScalar(out, 'secret', '"$secret"');
    }
    return out;
  }

  /// Replace the entire `rules:` block with the supplied body. Used by
  /// the per-app scope where we override panel routing with the user's
  /// custom rules. [body] should already include the leading two-space
  /// indent on each line (see `RulesBuilder.build`).
  static String setRules(String yaml, String body) {
    final stripped = _removeBlock(yaml, 'rules');
    final trimmed = stripped.trimRight();
    return '$trimmed\n\nrules:\n$body\n';
  }

  /// Inject (or replace) a TUN inbound block. When [enable] is false we
  /// strip the block instead.
  static String setTun(String yaml, {required bool enable, String stack = 'system'}) {
    final stripped = _removeBlock(yaml, 'tun');
    if (!enable) return stripped;
    final block = '''
tun:
  enable: true
  stack: $stack
  dns-hijack:
    - any:53
  auto-route: true
  auto-detect-interface: true
  mtu: 1500
''';
    return _appendBlock(stripped, block);
  }

  // -------- internals ----------------------------------------------------

  /// Replace `key: <old>` with `key: <value>` if present; append otherwise.
  /// Only matches top-level keys (no leading whitespace).
  static String _setScalar(String yaml, String key, String value) {
    final pattern = RegExp('^$key:.*', multiLine: true);
    if (pattern.hasMatch(yaml)) {
      return yaml.replaceFirst(pattern, '$key: $value');
    }
    final ending = yaml.endsWith('\n') ? '' : '\n';
    return '$yaml$ending$key: $value\n';
  }

  /// Remove the top-level block starting with `key:` and everything indented
  /// underneath it (until the next top-level key or EOF).
  static String _removeBlock(String yaml, String key) {
    final lines = yaml.split('\n');
    final out = <String>[];
    var skipping = false;
    for (final line in lines) {
      if (skipping) {
        // A new top-level key (no leading whitespace, contains a colon)
        // ends the previous block.
        if (line.isNotEmpty && !line.startsWith(RegExp(r'[ \t#]')) && line.contains(':')) {
          skipping = false;
        } else {
          continue;
        }
      }
      if (line.startsWith('$key:')) {
        skipping = true;
        continue;
      }
      out.add(line);
    }
    return out.join('\n');
  }

  /// Append a YAML block (already including its own trailing newline) after
  /// the existing top-level keys.
  static String _appendBlock(String yaml, String block) {
    final trimmed = yaml.trimRight();
    return '$trimmed\n\n$block';
  }
}
