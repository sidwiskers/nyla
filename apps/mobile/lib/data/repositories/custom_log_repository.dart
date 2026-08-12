import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:sync_core/sync_core.dart';

import '../../core/sync/hlc_service.dart';
import '../database/app_database.dart';

class CustomLogRepository {
  CustomLogRepository(this.database, this.hlc);

  final AppDatabase database;
  final HlcService hlc;

  Stream<List<CustomLogEntry>> watchAll() =>
      (database.select(database.customLogs)
            ..orderBy([
              (row) => OrderingTerm.asc(row.archived),
              (row) => OrderingTerm.asc(row.orderIndex),
              (row) => OrderingTerm.asc(row.label),
            ]))
          .watch();

  Future<String> create(String label) async {
    final clean = _validateLabel(label);
    await _ensureUnique(clean);
    final rows = await database.select(database.customLogs).get();
    final orderIndex = rows.isEmpty ? 0 : rows.map((row) => row.orderIndex).reduce(max) + 1;
    final key = 'custom_${_randomId()}';
    final now = DateTime.now().millisecondsSinceEpoch;

    await database.transaction(() async {
      final labelClock = await hlc.next(nowMillis: now);
      final archivedClock = await hlc.next(nowMillis: now);
      final orderClock = await hlc.next(nowMillis: now);
      await database.into(database.customLogs).insert(
            CustomLogsCompanion.insert(
              key: key,
              label: clean,
              orderIndex: orderIndex,
              updatedHlc: orderClock,
              updatedMs: now,
            ),
          );
      await _mutation(key, 'label', clean, labelClock, now);
      await _mutation(key, 'archived', false, archivedClock, now);
      await _mutation(key, 'order_index', orderIndex, orderClock, now);
    });
    return key;
  }

  Future<void> rename(String key, String label) async {
    final clean = _validateLabel(label);
    final current = await _row(key);
    if (current == null) throw StateError('Custom log no longer exists.');
    if (current.label == clean) return;
    await _ensureUnique(clean, exceptKey: key);
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.transaction(() async {
      final clock = await hlc.next(nowMillis: now);
      await (database.update(database.customLogs)..where((row) => row.key.equals(key))).write(
        CustomLogsCompanion(label: Value(clean), updatedHlc: Value(clock), updatedMs: Value(now)),
      );
      await _mutation(key, 'label', clean, clock, now);
    });
  }

  Future<void> setArchived(String key, bool archived) async {
    final current = await _row(key);
    if (current == null) throw StateError('Custom log no longer exists.');
    if (current.archived == archived) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.transaction(() async {
      final clock = await hlc.next(nowMillis: now);
      await (database.update(database.customLogs)..where((row) => row.key.equals(key))).write(
        CustomLogsCompanion(archived: Value(archived), updatedHlc: Value(clock), updatedMs: Value(now)),
      );
      await _mutation(key, 'archived', archived, clock, now);
    });
  }

  Future<CustomLogEntry?> _row(String key) =>
      (database.select(database.customLogs)..where((row) => row.key.equals(key))).getSingleOrNull();

  String _validateLabel(String label) {
    final clean = label.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) throw ArgumentError('Give this log a name.');
    if (clean.length > 40) throw ArgumentError('Custom log names can be up to 40 characters.');
    return clean;
  }

  Future<void> _ensureUnique(String label, {String? exceptKey}) async {
    final rows = await database.select(database.customLogs).get();
    final normalized = label.toLowerCase();
    if (rows.any((row) => row.key != exceptKey && row.label.toLowerCase() == normalized)) {
      throw ArgumentError('You already have a log with that name.');
    }
  }

  Future<void> _mutation(String key, String field, Object value, String clock, int now) async {
    await database.into(database.localMutations).insert(
          LocalMutationsCompanion.insert(
            opId: _randomId(),
            entityId: key,
            entityType: 'custom_log',
            field: field,
            kind: 'set',
            valueJson: Value(jsonEncode(value)),
            hlc: clock,
            createdMs: now,
          ),
        );
    await database.into(database.fieldClocks).insertOnConflictUpdate(
          FieldClocksCompanion.insert(entityId: key, field: field, hlc: clock),
        );
  }

  String _randomId() => base64UrlNoPadding(
        List<int>.generate(16, (_) => Random.secure().nextInt(256), growable: false),
      );
}
