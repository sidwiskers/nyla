import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/sync/hlc_service.dart';
import '../database/app_database.dart';

class DayLogRepository {
  DayLogRepository(this.database, this.hlc);

  final AppDatabase database;
  final HlcService hlc;

  Stream<List<DayValueEntry>> watchDay(int epochDay) => database.watchDay(epochDay);

  Stream<List<DayValueEntry>> watchAll() => database.watchAllDayValues();

  Future<void> setValue({
    required int epochDay,
    required String key,
    required String value,
    int? severity,
  }) async {
    if (key.isEmpty || key.length > 64 || value.length > 128) throw ArgumentError('Invalid log value.');
    if (severity != null && (severity < 0 || severity > 4)) throw ArgumentError('Severity must be 0–4.');

    final now = DateTime.now().millisecondsSinceEpoch;
    final entityId = 'day:$epochDay';

    await database.transaction(() async {
      final clock = await hlc.next(nowMillis: now);
      await database.into(database.dayValues).insertOnConflictUpdate(
            DayValuesCompanion.insert(
              day: epochDay,
              key: key,
              value: value,
              severity: Value(severity),
              updatedHlc: clock,
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
              hlc: clock,
              createdMs: now,
            ),
          );
      await database.into(database.fieldClocks).insertOnConflictUpdate(
            FieldClocksCompanion.insert(entityId: entityId, field: key, hlc: clock),
          );
    });
  }

  Future<void> setNote({required int epochDay, required String note}) async {
    if (note.length > 4000) throw ArgumentError('A daily note can contain at most 4000 characters.');
    final now = DateTime.now().millisecondsSinceEpoch;
    final entityId = 'day:$epochDay';
    await database.transaction(() async {
      final clock = await hlc.next(nowMillis: now);
      if (note.trim().isEmpty) {
        await (database.delete(database.dayNotes)..where((row) => row.day.equals(epochDay))).go();
      } else {
        await database.into(database.dayNotes).insertOnConflictUpdate(
              DayNotesCompanion.insert(day: Value(epochDay), note: note.trim(), updatedHlc: clock, updatedMs: now),
            );
      }
      await database.into(database.localMutations).insert(
            LocalMutationsCompanion.insert(
              opId: _id(),
              entityId: entityId,
              entityType: 'day',
              field: 'note',
              kind: note.trim().isEmpty ? 'unset' : 'set',
              valueJson: Value(note.trim().isEmpty ? null : jsonEncode(note.trim())),
              hlc: clock,
              createdMs: now,
            ),
          );
      await database.into(database.fieldClocks).insertOnConflictUpdate(
            FieldClocksCompanion.insert(entityId: entityId, field: 'note', hlc: clock),
          );
    });
  }

  Future<String?> noteForDay(int epochDay) async =>
      (await (database.select(database.dayNotes)..where((row) => row.day.equals(epochDay))).getSingleOrNull())?.note;

  Future<void> clearValue({required int epochDay, required String key}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entityId = 'day:$epochDay';
    await database.transaction(() async {
      final clock = await hlc.next(nowMillis: now);
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
              hlc: clock,
              createdMs: now,
            ),
          );
      await database.into(database.fieldClocks).insertOnConflictUpdate(
            FieldClocksCompanion.insert(entityId: entityId, field: key, hlc: clock),
          );
    });
  }

  String _id() => base64UrlEncode(
        List<int>.generate(16, (_) => Random.secure().nextInt(256), growable: false),
      ).replaceAll('=', '');
}
