import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Cross-isolate/process guard for work that must not overlap a sync run.
///
/// POSIX advisory file locks are process-scoped on platforms Dart targets, so
/// two Flutter isolates in the same Android process cannot safely use separate
/// file descriptors as a mutex. Instead, a tiny dedicated SQLite database holds
/// an exclusive transaction for the lifetime of the guarded action. SQLite
/// arbitrates that lock per connection, including connections in one process,
/// and releases it automatically if an isolate/process dies.
///
/// The guard database contains no Nyla data or secrets. It exists only to own a
/// crash-safe operating-system-backed lock independent of the health database,
/// which is important because local erasure also needs this guard.
final class SyncRunLock {
  SyncRunLock({Future<Directory> Function()? directoryProvider})
      : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static final Object _zoneKey = Object();
  static const _retryDelay = Duration(milliseconds: 50);
  final Future<Directory> Function() _directoryProvider;

  Future<T> synchronized<T>(Future<T> Function() action) async {
    // A guarded operation may call another guarded method. Re-enter within the
    // same isolate instead of trying to acquire a second SQLite connection.
    if (Zone.current[_zoneKey] == true) return action();

    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final guard = sqlite3.open('${directory.path}/nyla.sync.guard.db');
    var acquired = false;
    try {
      // Keep each native wait short so a foreground isolate remains responsive
      // while another isolate owns the guard. The async loop then yields before
      // trying again. There is intentionally no overall timeout: erasure must
      // wait for an in-flight sync rather than race it.
      guard.execute('PRAGMA busy_timeout = 250;');
      while (!acquired) {
        try {
          guard.execute('BEGIN EXCLUSIVE;');
          acquired = true;
        } on SqliteException catch (error) {
          if (error.resultCode != SqlError.SQLITE_BUSY &&
              error.resultCode != SqlError.SQLITE_LOCKED) {
            rethrow;
          }
          await Future<void>.delayed(_retryDelay);
        }
      }

      return await runZoned<Future<T>>(
        action,
        zoneValues: <Object, Object>{_zoneKey: true},
      );
    } finally {
      if (acquired && !guard.autocommit) {
        // Nothing is ever written to the guard DB, so rollback is the clearest
        // way to release the transaction without creating journaled state.
        guard.execute('ROLLBACK;');
      }
      guard.close();
    }
  }
}
