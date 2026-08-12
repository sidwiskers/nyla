import 'package:sync_core/sync_core.dart';

import '../../data/database/app_database.dart';

class HlcService {
  HlcService(this.database, this.deviceId);

  static const _stateKey = 'hlc.last.v1';

  final AppDatabase database;
  final String deviceId;

  Future<String> next({int? nowMillis}) async {
    final previous = await _read();
    final next = nextLocalHlc(
      nodeId: deviceId,
      nowMillis: nowMillis ?? DateTime.now().millisecondsSinceEpoch,
      previous: previous,
    );
    await _write(next);
    return next.toString();
  }

  Future<void> observe(String remote, {int? nowMillis}) async {
    final next = observeRemoteHlc(
      nodeId: deviceId,
      nowMillis: nowMillis ?? DateTime.now().millisecondsSinceEpoch,
      previous: await _read(),
      remote: HybridLogicalClock.parse(remote),
    );
    await _write(next);
  }

  Future<HybridLogicalClock?> _read() async {
    final row = await (database.select(database.syncState)..where((entry) => entry.key.equals(_stateKey)))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      return HybridLogicalClock.parse(row.value);
    } on FormatException {
      throw StateError('Stored synchronization clock is corrupt.');
    }
  }

  Future<void> _write(HybridLogicalClock value) => database.into(database.syncState).insertOnConflictUpdate(
        SyncStateCompanion.insert(key: _stateKey, value: value.toString()),
      );
}
