import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

class DayLogRepository {
  DayLogRepository(this.database, this.deviceId);

  final AppDatabase database;
  final String deviceId;

  Stream<List<DayValueEntry>> watchDay(int epochDay) => database.watchDay(epochDay);

  Future<void> setValue({
    required int epochDay,
    required String key,
    required String value,
    int? severity,
  }) async {
    if (key.isEmpty || key.length > 64 || value.length > 128) throw ArgumentError('Invalid log value.');
    if (severity != null && (severity < 0 || severity > 4)) throw ArgumentError('Severity must be 0–4.');

    final now = DateTime.now().millisecondsSinceEpoch;
    final hlc = '$now:0:$deviceId';
    final entityId = 'day:$epochDay';

    await database.transaction(() async {
      await database.into(database.dayValues).insertOnConflictUpdate(
            DayValuesCompanion.insert(
              day: epochDay,
              key: key,
              value: value,
              severity: Value(severity),
              updatedHlc: hlc,
              updatedMs: now,
            ),
          );
      await database.into(database.localMutations).insert(
            LocalMutationsCompanion.insert(
              opId: _id(),
              entityId: entityId,
              entityType: 'day',
              field: key,
              kind: 'set',
              valueJson: Value(jsonEncode({'value': value, 'severity': severity})),
              hlc: hlc,
              createdMs: now,
            ),
          );
      await database.into(database.fieldClocks).insertOnConflictUpdate(
            FieldClocksCompanion.insert(entityId: entityId, field: key, hlc: hlc),
          );
    });
  }

  Future<void> clearValue({required int epochDay, required String key}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hlc = '$now:0:$deviceId';
    final entityId = 'day:$epochDay';
    await database.transaction(() async {
      await (database.delete(database.dayValues)
            ..where((row) => row.day.equals(epochDay) & row.key.equals(key)))
          .go();
      await database.into(database.localMutations).insert(
            LocalMutationsCompanion.insert(
              opId: _id(),
              entityId: entityId,
              entityType: 'day',
              field: key,
              kind: 'unset',
              hlc: hlc,
              createdMs: now,
            ),
          );
      await database.into(database.fieldClocks).insertOnConflictUpdate(
            FieldClocksCompanion.insert(entityId: entityId, field: key, hlc: hlc),
          );
    });
  }

  String _id() => base64UrlEncode(
        List<int>.generate(16, (_) => Random.secure().nextInt(256), growable: false),
      ).replaceAll('=', '');
}
