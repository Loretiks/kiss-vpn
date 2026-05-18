import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Prevent multiple instances of Kiss VPN running side-by-side.
///
/// Uses an exclusive lock on a file inside %APPDATA%\KissVPN — if the file is
/// already locked, another instance is running.
class SingleInstance {
  // Held for the lifetime of the process — closing it releases the file lock.
  // ignore: unused_field
  static RandomAccessFile? _lock;

  static Future<bool> acquire() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final lockFile = File(p.join(dir.path, 'kiss_vpn.lock'));
      await lockFile.create(recursive: true);
      final raf = await lockFile.open(mode: FileMode.write);
      try {
        await raf.lock(FileLock.exclusive);
        _lock = raf;
        return true;
      } catch (_) {
        await raf.close();
        return false;
      }
    } catch (_) {
      // If we can't even create the lock, allow startup but log it later.
      return true;
    }
  }
}
