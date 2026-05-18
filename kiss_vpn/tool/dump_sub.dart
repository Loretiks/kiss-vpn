// Dump full subscription YAML to inspect structure.
import 'dart:io';
import 'package:kiss_vpn/core/subscription/sub_fetcher.dart';

Future<void> main(List<String> args) async {
  final resp = await SubFetcher().fetch(args.first);
  stdout.writeln(resp.body);
}
