import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A single running process surfaced to the user when adding a split-tunnel
/// rule by picking from the currently running apps.
class RunningProcess {
  const RunningProcess({
    required this.name,
    required this.exeName,
    this.path,
    this.title,
    this.instances = 1,
  });

  /// Friendly display name (process name with `.exe` stripped — `Chrome`).
  final String name;

  /// `chrome.exe` — what we put into a `RuleKind.app` rule.
  final String exeName;

  /// Full path on disk when available (`C:\Program Files\Google\Chrome\…`).
  final String? path;

  /// Main window title — useful for distinguishing "Chrome — YouTube" from
  /// "Chrome — DevTools". Often empty for system / background apps.
  final String? title;

  /// How many child processes share this exe (Chrome spawns dozens —
  /// we collapse them and show this count as a hint).
  final int instances;

  RunningProcess copyWith({int? instances}) => RunningProcess(
        name: name,
        exeName: exeName,
        path: path,
        title: title,
        instances: instances ?? this.instances,
      );
}

class ProcessEnumerationError implements Exception {
  ProcessEnumerationError(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() =>
      cause == null ? message : '$message\nПричина: $cause';
}

/// Enumerates running processes on Windows via PowerShell (`Get-Process`).
///
/// We filter to entries that resolve to an executable path on disk (so
/// kernel pseudo-processes without an exe are skipped). Stdout is forced
/// to UTF-8 inside PowerShell to survive Cyrillic window titles on
/// Russian-locale machines where the default OEM code page mangles JSON.
class ProcessList {
  /// Wrap the user script in a header that pins console encoding to UTF-8,
  /// otherwise PowerShell encodes stdout in the system OEM code page
  /// (cp1251 on Russian Windows), which `dart:convert.utf8` cannot decode.
  static const _psScript = r"""
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$procs = Get-Process | Where-Object {
  ($_.Path -ne $null -and $_.Path -ne '') -or
  ($_.MainWindowHandle -ne $null -and $_.MainWindowHandle -ne 0)
} | ForEach-Object {
  $path = $null
  $title = $null
  try { $path = $_.Path } catch {}
  try { $title = $_.MainWindowTitle } catch {}
  [PSCustomObject]@{
    name = $_.ProcessName
    path = $path
    title = $title
  }
}
ConvertTo-Json $procs -Compress -Depth 3
""";

  /// Returns parsed processes. Throws [ProcessEnumerationError] when the
  /// script can't be run at all — callers should surface the message to
  /// the user instead of falling back to an empty list, so debugging is
  /// possible.
  static Future<List<RunningProcess>> enumerate({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!Platform.isWindows) return const [];

    late final ProcessResult r;
    try {
      r = await Process.run(
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', _psScript],
        // Don't force stdoutEncoding — PowerShell itself emits UTF-8 thanks
        // to the [Console]::OutputEncoding line, and Dart will pick up
        // those bytes as raw. We decode manually below.
        stdoutEncoding: null,
        stderrEncoding: null,
      ).timeout(timeout);
    } catch (e) {
      throw ProcessEnumerationError('Не удалось запустить PowerShell', e);
    }

    final stderrRaw = r.stderr is List<int>
        ? utf8.decode(r.stderr as List<int>, allowMalformed: true)
        : (r.stderr?.toString() ?? '');
    final stdoutRaw = r.stdout is List<int>
        ? utf8.decode(r.stdout as List<int>, allowMalformed: true)
        : (r.stdout?.toString() ?? '');

    if (r.exitCode != 0) {
      throw ProcessEnumerationError(
        'PowerShell завершился с кодом ${r.exitCode}',
        stderrRaw.isEmpty ? null : stderrRaw,
      );
    }
    final raw = stdoutRaw.trim();
    if (raw.isEmpty) {
      throw ProcessEnumerationError(
        'PowerShell вернул пустой ответ.',
        stderrRaw.isEmpty ? null : stderrRaw,
      );
    }

    dynamic parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (e) {
      throw ProcessEnumerationError(
        'Не удалось разобрать JSON-ответ PowerShell',
        e,
      );
    }
    final list = parsed is List ? parsed : [parsed];

    // Collapse duplicates by exe name (Chrome → many processes → one row).
    final byExe = <String, RunningProcess>{};
    for (final item in list) {
      if (item is! Map) continue;
      final psName = (item['name'] as String?)?.trim();
      final path = (item['path'] as String?)?.trim();
      if (psName == null || psName.isEmpty) continue;
      if (path == null || path.isEmpty) continue;
      final exe = path.split(RegExp(r'[\\/]')).last;
      final keyName = exe.toLowerCase();
      final title = (item['title'] as String?)?.trim();
      final existing = byExe[keyName];
      if (existing == null) {
        byExe[keyName] = RunningProcess(
          name: _displayName(psName),
          exeName: exe,
          path: path,
          title: (title == null || title.isEmpty) ? null : title,
        );
      } else {
        byExe[keyName] = existing.copyWith(instances: existing.instances + 1);
      }
    }

    final out = byExe.values.toList()
      ..sort((a, b) {
        // Apps with a window title first (they're usually what the user
        // actually wants to route), then alphabetical.
        final at = (a.title?.isNotEmpty ?? false) ? 0 : 1;
        final bt = (b.title?.isNotEmpty ?? false) ? 0 : 1;
        if (at != bt) return at - bt;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return out;
  }

  /// Process names are usually lowercase or mixed (`chrome`, `RiotClientUx`).
  /// Try to give them a tidy `Chrome` / `Riot Client Ux` display name.
  static String _displayName(String raw) {
    if (raw.contains(RegExp(r'[A-Z]')) && raw != raw.toUpperCase()) {
      return raw;
    }
    return raw.isEmpty ? raw : (raw[0].toUpperCase() + raw.substring(1));
  }
}
