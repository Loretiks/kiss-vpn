import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'github_updater.dart';

enum UpdatePhase { idle, checking, available, downloading, ready, installing, error }

class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.currentVersion = '',
    this.info,
    this.received = 0,
    this.total = 0,
    this.installer,
    this.error,
  });

  final UpdatePhase phase;
  final String currentVersion;
  final UpdateInfo? info;
  final int received;
  final int total;
  final File? installer;
  final String? error;

  double get progress => total > 0 ? received / total : 0;

  UpdateState copyWith({
    UpdatePhase? phase,
    String? currentVersion,
    UpdateInfo? info,
    int? received,
    int? total,
    File? installer,
    String? error,
    bool clearError = false,
  }) =>
      UpdateState(
        phase: phase ?? this.phase,
        currentVersion: currentVersion ?? this.currentVersion,
        info: info ?? this.info,
        received: received ?? this.received,
        total: total ?? this.total,
        installer: installer ?? this.installer,
        error: clearError ? null : (error ?? this.error),
      );
}

class UpdateController extends StateNotifier<UpdateState> {
  UpdateController(this._updater) : super(const UpdateState()) {
    _hydrate();
  }

  final GithubUpdater _updater;
  CancelToken? _cancel;

  Future<void> _hydrate() async {
    state = state.copyWith(currentVersion: await _updater.currentVersion());
  }

  /// Silent background check — used at app startup. Doesn't show any
  /// loading UI; on success flips state to `available`.
  Future<void> checkSilent() async {
    if (state.phase == UpdatePhase.downloading ||
        state.phase == UpdatePhase.installing) {
      return;
    }
    final info = await _updater.check();
    if (info == null) return;
    state = state.copyWith(phase: UpdatePhase.available, info: info);
  }

  /// User-initiated check — surfaces the "checking…" spinner and an error
  /// state if anything goes wrong.
  Future<void> check() async {
    state = state.copyWith(phase: UpdatePhase.checking, clearError: true);
    try {
      final info = await _updater.check();
      if (info == null) {
        state = state.copyWith(phase: UpdatePhase.idle);
        return;
      }
      state = state.copyWith(phase: UpdatePhase.available, info: info);
    } catch (e) {
      state = state.copyWith(phase: UpdatePhase.error, error: e.toString());
    }
  }

  Future<void> download() async {
    final info = state.info;
    if (info == null) return;
    _cancel = CancelToken();
    state = state.copyWith(
        phase: UpdatePhase.downloading,
        received: 0,
        total: info.installerSize,
        clearError: true);
    try {
      final file = await _updater.download(
        info,
        cancelToken: _cancel,
        onProgress: (got, t) {
          state = state.copyWith(received: got, total: t > 0 ? t : info.installerSize);
        },
      );
      state = state.copyWith(phase: UpdatePhase.ready, installer: file);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        state = state.copyWith(phase: UpdatePhase.available);
      } else {
        state = state.copyWith(phase: UpdatePhase.error, error: e.message ?? e.toString());
      }
    } catch (e) {
      state = state.copyWith(phase: UpdatePhase.error, error: e.toString());
    } finally {
      _cancel = null;
    }
  }

  void cancelDownload() {
    _cancel?.cancel('user-cancelled');
  }

  Future<void> install() async {
    final f = state.installer;
    if (f == null) return;
    state = state.copyWith(phase: UpdatePhase.installing);
    await _updater.installAndExit(f);
  }

  void dismiss() {
    state = state.copyWith(phase: UpdatePhase.idle, clearError: true);
  }
}

final githubUpdaterProvider = Provider<GithubUpdater>((_) => GithubUpdater());

final updateControllerProvider =
    StateNotifierProvider<UpdateController, UpdateState>((ref) {
  return UpdateController(ref.watch(githubUpdaterProvider));
});
