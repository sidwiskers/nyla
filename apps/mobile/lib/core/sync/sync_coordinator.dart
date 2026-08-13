import 'dart:async';

import '../../data/database/app_database.dart';
import 'background_sync.dart';
import 'sync_service.dart';

typedef _ScheduleBackground = Future<void> Function({Duration delay});

/// Turns local activity into sync attempts without changing sync semantics.
///
/// The encrypted protocol remains entirely inside [SyncService]. This class is
/// only policy: persist an Android retry request first, then opportunistically
/// reconcile while Nyla is already open. Failures stay silent for automatic
/// work because the local database is authoritative and the durable request is
/// left for WorkManager to retry.
final class SyncCoordinator {
  SyncCoordinator({
    required this.service,
    required this.database,
    _ScheduleBackground? scheduleBackground,
    Future<void> Function()? cancelBackground,
  })  : _scheduleBackground = scheduleBackground ?? NylaBackgroundSync.schedule,
        _cancelBackground = cancelBackground ?? NylaBackgroundSync.cancelPending;

  static const _editDebounce = Duration(milliseconds: 1200);
  static const _foregroundSafetyDelay = Duration(seconds: 20);

  final SyncService service;
  final AppDatabase database;
  final _ScheduleBackground _scheduleBackground;
  final Future<void> Function() _cancelBackground;

  Timer? _editTimer;
  Future<SyncRunResult>? _activeRun;
  bool _durableQueued = false;

  /// Called when the unlocked app becomes usable.
  ///
  /// Queue the crash/offline-safe request before attempting the fast foreground
  /// reconciliation. If the direct run succeeds the redundant queued work is
  /// removed safely and re-created only if a newer mutation is still pending.
  Future<void> onForeground() async {
    if (!await _canSync()) return;
    await _ensureDurable(delay: _foregroundSafetyDelay, force: true);
    unawaited(_runAutomatic());
  }

  /// Called after the local outbox grows.
  ///
  /// Local persistence already happened before this signal. The durable work is
  /// queued immediately; the foreground attempt is lightly debounced so a few
  /// taps in one logging session are naturally uploaded as one batch.
  Future<void> onLocalMutation() async {
    if (!await _canSync()) return;
    await _ensureDurable();
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
      await _ensureDurable(force: true);
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
      // Local writes never depend on this succeeding. The durable WorkManager
      // request remains queued and handles connectivity/transient retries.
    }
  }

  Future<SyncRunResult> _runSingleFlight() {
    final active = _activeRun;
    if (active != null) return active;

    late final Future<SyncRunResult> run;
    run = service.syncNow().whenComplete(() {
      if (identical(_activeRun, run)) _activeRun = null;
    });
    _activeRun = run;
    return run;
  }

  Future<bool> _canSync() async =>
      service.endpointConfigured && await service.identity() != null;

  Future<void> _ensureDurable({
    Duration delay = const Duration(seconds: 8),
    bool force = false,
  }) async {
    if (_durableQueued && !force) return;
    await _scheduleBackground(delay: delay);
    _durableQueued = true;
  }

  Future<void> _settleDurableRequest() async {
    // Cancel first, then re-read the outbox. This ordering closes the race where
    // a new mutation arrives while a successful foreground run is finishing:
    // anything still pending after cancellation gets a fresh durable request.
    await _cancelBackground();
    _durableQueued = false;
    if (await _canSync() && await database.pendingMutationCount() > 0) {
      await _ensureDurable();
    }
  }
}
