import 'dart:async';

import '../../data/database/app_database.dart';
import 'background_sync.dart';
import 'sync_run_lock.dart';
import 'sync_service.dart';

typedef SyncBackgroundScheduler = Future<void> Function({Duration delay});

/// Turns local activity into sync attempts without changing sync semantics.
///
/// The encrypted protocol remains entirely inside [SyncService]. This class is
/// only policy: persist an Android retry request first, then opportunistically
/// reconcile while Nyla is already open. Failures stay silent for automatic
/// work because the local database is authoritative and durable scheduling is
/// an availability enhancement rather than a precondition for local writes.
final class SyncCoordinator {
  SyncCoordinator({
    required this.service,
    required this.database,
    SyncBackgroundScheduler? scheduleBackground,
    Future<void> Function()? cancelBackground,
    SyncRunLock? runLock,
  })  : _scheduleBackground = scheduleBackground ?? NylaBackgroundSync.schedule,
        _cancelBackground = cancelBackground ?? NylaBackgroundSync.cancelPending,
        _runLock = runLock ?? SyncRunLock();

  static const _editDebounce = Duration(milliseconds: 1200);
  static const _foregroundSafetyDelay = Duration(seconds: 20);

  final SyncService service;
  final AppDatabase database;
  final SyncBackgroundScheduler _scheduleBackground;
  final Future<void> Function() _cancelBackground;
  final SyncRunLock _runLock;

  Timer? _editTimer;
  Future<SyncRunResult>? _activeRun;

  /// Called when the unlocked app becomes usable.
  ///
  /// Queue the crash/offline-safe request before attempting the fast foreground
  /// reconciliation. A scheduler failure never blocks the direct sync attempt.
  Future<void> onForeground() async {
    if (!await _canSync()) return;
    await _tryEnsureDurable(delay: _foregroundSafetyDelay);
    unawaited(_runAutomatic());
  }

  /// Called after the local outbox grows.
  ///
  /// Local persistence already happened before this signal. Durable work is
  /// requested immediately; the foreground attempt is lightly debounced so a
  /// few taps in one logging session naturally upload as one batch.
  Future<void> onLocalMutation() async {
    if (!await _canSync()) return;
    await _tryEnsureDurable();
    _editTimer?.cancel();
    _editTimer = Timer(_editDebounce, () => unawaited(_runAutomatic()));
  }

  /// Called before the foreground sync lifecycle is unmounted.
  Future<void> onBackground() async {
    final hadDebouncedAttempt = _editTimer?.isActive ?? false;
    _editTimer?.cancel();
    _editTimer = null;
    if (!await _canSync()) return;
    if (hadDebouncedAttempt || await database.pendingMutationCount() > 0) {
      await _tryEnsureDurable();
    }
  }

  Future<SyncRunResult> runNow() => _runSingleFlight();

  void dispose() {
    _editTimer?.cancel();
    _editTimer = null;
  }

  Future<void> _runAutomatic() async {
    _editTimer = null;
    if (!await _canSync()) return;
    try {
      await _runSingleFlight();
      await _settleDurableRequest();
    } catch (_) {
      // Local writes never depend on this succeeding. A successfully queued
      // WorkManager request remains available for connectivity/transient retry.
    }
  }

  Future<SyncRunResult> _runSingleFlight() {
    final active = _activeRun;
    if (active != null) return active;

    late final Future<SyncRunResult> run;
    run = _runLock.synchronized(service.syncNow).whenComplete(() {
      if (identical(_activeRun, run)) _activeRun = null;
    });
    _activeRun = run;
    return run;
  }

  Future<bool> _canSync() async =>
      service.endpointConfigured && await service.identity() != null;

  Future<void> _tryEnsureDurable({
    Duration delay = const Duration(seconds: 8),
  }) async {
    try {
      // WorkManager's unique KEEP policy is the durable source of truth. It is
      // deliberately safe to request the same work repeatedly: Android keeps a
      // single unfinished worker and a completed worker never leaves stale
      // in-memory state that could suppress a later request.
      await _scheduleBackground(delay: delay);
    } catch (_) {
      // Android/OEM scheduler failures degrade to foreground/manual sync only;
      // they must never surface as a failed health-data edit.
    }
  }

  Future<void> _settleDurableRequest() async {
    // Cancel first, then re-read the outbox. This closes the race where a new
    // mutation arrives while a successful foreground run is finishing: anything
    // still pending after cancellation gets a fresh durable request.
    try {
      await _cancelBackground();
    } catch (_) {
      // Leaving an already-queued idempotent worker is harmless. It will run the
      // same serialized reconciliation and find nothing to upload if up to date.
      return;
    }
    if (await _canSync() && await database.pendingMutationCount() > 0) {
      await _tryEnsureDurable();
    }
  }
}
