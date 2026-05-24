import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// JSON-RPC 2.0 client for the Kiss VPN Helper Service.
///
/// Talks to `\\.\pipe\KissVPN.Helper` via Win32 CreateFile + ReadFile +
/// WriteFile. Dart's [File] API doesn't open Windows named pipes, so we drop
/// to FFI here. Reads are polled (non-blocking via PeekNamedPipe) on a Timer
/// — avoids the need for OVERLAPPED I/O or a reader isolate, and keeps the
/// implementation single-threaded which sidesteps a class of Dart/FFI
/// interop bugs around blocking syscalls in spawned isolates.
class HelperClient {
  HelperClient({this.pipeName = 'KissVPN.Helper'});

  final String pipeName;
  int _handle = INVALID_HANDLE_VALUE;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _nextId = 1;
  Timer? _poller;
  final List<int> _accum = [];
  bool _closed = false;

  String get _pipePath => r'\\.\pipe\' + pipeName;

  bool get isConnected =>
      _handle != INVALID_HANDLE_VALUE && _handle != 0 && !_closed;

  Future<void> connect() async {
    if (isConnected) return;

    final namePtr = _pipePath.toNativeUtf16();
    try {
      final h = CreateFile(
        namePtr,
        GENERIC_READ | GENERIC_WRITE,
        0,
        nullptr,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        0,
      );
      if (h == INVALID_HANDLE_VALUE) {
        final err = GetLastError();
        throw HelperError(
          method: 'connect',
          code: err,
          message: 'CreateFile($_pipePath) failed (Win32 error $err)',
        );
      }
      _handle = h;
    } finally {
      free(namePtr);
    }

    _poller = Timer.periodic(const Duration(milliseconds: 25), (_) => _drain());
  }

  void _drain() {
    if (!isConnected) return;
    final available = calloc<Uint32>();
    try {
      final peek = PeekNamedPipe(
        _handle,
        nullptr,
        0,
        nullptr,
        available,
        nullptr,
      );
      if (peek == 0) {
        // Pipe broken / closed.
        _closed = true;
        _poller?.cancel();
        _poller = null;
        if (_handle != INVALID_HANDLE_VALUE && _handle != 0) {
          CloseHandle(_handle);
          _handle = INVALID_HANDLE_VALUE;
        }
        return;
      }
      final n = available.value;
      if (n == 0) return;

      final buf = malloc.allocate<Uint8>(n);
      final read = calloc<Uint32>();
      try {
        final ok = ReadFile(_handle, buf, n, read, nullptr);
        if (ok == 0) return;
        final readN = read.value;
        for (var i = 0; i < readN; i++) {
          final b = buf[i];
          if (b == 0x0A) {
            if (_accum.isNotEmpty) {
              _dispatchLine(utf8.decode(_accum, allowMalformed: true));
              _accum.clear();
            }
          } else if (b != 0x0D) {
            _accum.add(b);
          }
        }
      } finally {
        free(buf);
        free(read);
      }
    } finally {
      free(available);
    }
  }

  void _dispatchLine(String line) {
    if (line.isEmpty) return;
    Map<String, dynamic> obj;
    try {
      obj = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final id = obj['id'];
    if (id is int) {
      final c = _pending.remove(id);
      c?.complete(obj);
    }
  }

  Future<Map<String, dynamic>> call(
    String method, {
    Map<String, dynamic>? params,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!isConnected) await connect();

    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    final payload = '${jsonEncode({
          'jsonrpc': '2.0',
          'method': method,
          if (params != null) 'params': params,
          'id': id,
        })}\n';

    _writeAll(utf8.encode(payload));

    final response = await completer.future.timeout(timeout, onTimeout: () {
      _pending.remove(id);
      throw TimeoutException(
          'Helper call $method timed out after ${timeout.inSeconds}s');
    });

    if (response['error'] is Map) {
      final err = response['error'] as Map<String, dynamic>;
      throw HelperError(
        code: (err['code'] as num?)?.toInt() ?? -1,
        message: (err['message'] as String?) ?? 'unknown helper error',
        method: method,
      );
    }
    return (response['result'] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  void _writeAll(List<int> bytes) {
    final buf = malloc.allocate<Uint8>(bytes.length);
    try {
      buf.asTypedList(bytes.length).setAll(0, bytes);
      final written = calloc<Uint32>();
      try {
        final ok = WriteFile(_handle, buf, bytes.length, written, nullptr);
        if (ok == 0) {
          final err = GetLastError();
          throw HelperError(
            method: 'write',
            code: err,
            message: 'WriteFile failed (Win32 error $err)',
          );
        }
      } finally {
        free(written);
      }
    } finally {
      free(buf);
    }
  }

  Future<void> close() async {
    _closed = true;
    _poller?.cancel();
    _poller = null;
    for (final c in _pending.values) {
      c.completeError(StateError('HelperClient closed'));
    }
    _pending.clear();
    if (_handle != INVALID_HANDLE_VALUE && _handle != 0) {
      CloseHandle(_handle);
      _handle = INVALID_HANDLE_VALUE;
    }
  }
}

class HelperError implements Exception {
  HelperError({required this.code, required this.message, required this.method});
  final int code;
  final String message;
  final String method;

  @override
  String toString() => 'HelperError($method): $message (code=$code)';
}
