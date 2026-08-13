import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Cross-isolate/process guard for work that must not overlap a sync run.
///
/// WorkManager executes Dart in a separate isolate, so an in-memory mutex is
/// insufficient. A tiny advisory lock file keeps foreground sync, background
/// sync, device-key rotation and local erasure mutually exclusive without
/// holding a SQLite transaction open across network I/O.
final class SyncRunLock {
  SyncRunLock({Future<Directory> Function()? directoryProvider})
      : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static final Object _zoneKey = Object();
  final Future<Directory> Function() _directoryProvider;

  Future<T> synchronized<T>(Future<T> Function() action) async {
    // A guarded operation may call another guarded SyncService method. Keep
    // that re-entrant within the same isolate while the outer file lock is held.
    if (Zone.current[_zoneKey] == true) return action();

    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final handle = await File('${directory.path}/nyla.sync.lock').open(mode: FileMode.append);
    await handle.lock(FileLock.exclusive);
    try {
      return await runZoned<Future<T>>(
        action,
        zoneValues: <Object, Object>{_zoneKey: true},
      );
    } finally {
      await handle.unlock();
      await handle.close();
    }
  }
}
