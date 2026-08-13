import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

import '../../data/database/app_database.dart';
import '../storage/secure_vault.dart';
import 'sync_endpoint.dart';
import 'sync_http_client.dart';
import 'sync_run_lock.dart';
import 'sync_service.dart';

/// Device-side durable scheduling for Nyla sync.
///
/// Cloudflare never initiates a sync. Android WorkManager only remembers that
/// this installation wants to run the normal local sync pipeline once a working
/// network is available.
final class NylaBackgroundSync {
  static const _uniqueName = 'nyla-private-sync-v1';
  static const _taskName = 'nyla.private_sync';

  static Future<void>? _initializing;

  static bool get supported => Platform.isAndroid;

  static Future<void> initialize() {
    if (!supported) return Future.value();
    return _initializing ??= _initializeOnce();
  }

  static Future<void> _initializeOnce() async {
    try {
      await Workmanager().initialize(nylaSyncCallbackDispatcher);
    } catch (_) {
      // A failed attempt must remain retryable on the next foreground trigger.
      _initializing = null;
      rethrow;
    }
  }

  /// Queue one durable reconciliation request.
  ///
  /// The task has one stable unique name. A newer trigger replaces an unfinished
  /// stale request instead of being ignored or appended as a chain. That gives
  /// Nyla one durable "reconcile this installation" intent while also closing
  /// the race where a local edit lands during the final moments of a worker.
  static Future<void> schedule({Duration delay = const Duration(seconds: 8)}) async {
    if (!supported || !SyncEndpoint.isConfigured) return;
    await initialize();
    await Workmanager().registerOneOffTask(
      _uniqueName,
      _taskName,
      initialDelay: delay,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  }

  static Future<void> cancelPending() async {
    if (!supported) return;
    await initialize();
    await Workmanager().cancelByUniqueName(_uniqueName);
  }

  static bool isTask(String taskName) => taskName == _taskName;
}

@pragma('vm:entry-point')
void nylaSyncCallbackDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    if (!NylaBackgroundSync.isTask(taskName)) return true;

    // Plugins used by this background isolate need a binary messenger before
    // secure storage/path-provider/database access.
    WidgetsFlutterBinding.ensureInitialized();

    // Local erase and foreground synchronization use the same cross-isolate
    // guard. Re-check all secrets after acquiring it so a stale queued worker
    // can never resurrect data after the user erased Nyla.
    return SyncRunLock().synchronized(() async {
      const vault = SecureVault();
      if (!SyncEndpoint.isConfigured || await vault.readSyncIdentity() == null) return true;

      final databaseKey = await vault.existingDatabaseKeyHex();
      final deviceId = await vault.existingDeviceId();
      if (databaseKey == null || deviceId == null) return true;

      AppDatabase? database;
      try {
        database = await AppDatabase.open(databaseKey);
        final service = SyncService(
          database: database,
          deviceId: deviceId,
          secureVault: vault,
        );
        final result = await service.syncNow();
        // If a local mutation became pending during this pass, ask WorkManager
        // for another attempt as a second line of defense. Foreground outbox
        // observation also replaces this worker with a fresh unique request.
        return result.pending == 0;
      } catch (error) {
        // `false` asks Android WorkManager to retry with exponential backoff.
        // Protocol/authentication failures fail closed instead of becoming an
        // endless background loop that only explicit user action can repair.
        return !_retryableBackgroundFailure(error);
      } finally {
        await database?.close();
      }
    });
  });
}

bool _retryableBackgroundFailure(Object error) {
  if (error is http.ClientException ||
      error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is HandshakeException) {
    return true;
  }
  if (error is! SyncTransportException) return false;

  if (error.message == 'sync_epoch_retry_exhausted') return true;
  final status = error.statusCode;
  return status == 408 || status == 425 || status == 429 || (status != null && status >= 500);
}
