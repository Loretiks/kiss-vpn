// Smoke test for the Helper Service JSON-RPC pipe.
// Assumes KissVPNHelper.exe is running and listening on \\.\pipe\KissVPN.Helper.
//
// Run:
//   dart run tool/helper_smoke.dart

import 'dart:io';

import 'package:kiss_vpn/core/ipc/helper_client.dart';

Future<void> main() async {
  final hc = HelperClient();
  try {
    await hc.connect();
    stdout.writeln('connected to ${hc.isConnected}');

    final ping = await hc.call('ping');
    stdout.writeln('ping → $ping');

    final version = await hc.call('version');
    stdout.writeln('version → $version');

    final status = await hc.call('core_status');
    stdout.writeln('core_status → $status');

    try {
      final unknown = await hc.call('does_not_exist');
      stdout.writeln('unexpectedly succeeded: $unknown');
    } on HelperError catch (e) {
      stdout.writeln('expected error: $e');
    }
  } finally {
    await hc.close();
  }
}
