import 'package:drift/drift.dart';
import 'package:sync_core/sync_core.dart';

import '../../data/database/app_database.dart';
import 'hlc_service.dart';

final class SyncMergeEngine {
  SyncMergeEngine(this.database, this.hlc);

  final AppDatabase database;
  final HlcService hlc;

  Future<bool> apply(SyncPlainOperation operation) async {
    final remoteClock = HybridLogicalClock.parse(operation.hlc);
    return database.transaction(() async {
      final tombstone = await (database.select(database.entityTombstones)
            ..where((row) => row.entityId.equals(operation.entityId)))
          .getSingleOrNull();
      if (tombstone != null) {
        final deletedAt = HybridLogicalClock.parse(tombstone.hlc);
        if (remoteClock.compareTo(deletedAt) <= 0) {
          await hlc.observe(operation.hlc);
          return false;
        }
      }

      if (operation.kind == 'delete') {
        // A device may have edited one field offline after another device
        // deleted the entity. Entity deletion is still an HLC register: an
        // older delete must not erase any field that is known to be newer.
        final clocks = await (database.select(database.fieldClocks)
              ..where((row) => row.entityId.equals(operation.entityId)))
            .get();
        for (final clock in clocks) {
          if (HybridLogicalClock.parse(clock.hlc).compareTo(remoteClock) > 0) {
            await hlc.observe(operation.hlc);
            return false;
          }
        }
        await _deleteEntity(operation);
        await database.into(database.entityTombstones).insertOnConflictUpdate(
              EntityTombstonesCompanion.insert(entityId: operation.entityId, hlc: operation.hlc),
            );
        await hlc.observe(operation.hlc);
        return true;
      }

      final fieldClock = await (database.select(database.fieldClocks)
            ..where((row) => row.entityId.equals(operation.entityId) & row.field.equals(operation.field)))
          .getSingleOrNull();
      if (fieldClock != null && remoteClock.compareTo(HybridLogicalClock.parse(fieldClock.hlc)) <= 0) {
        await hlc.observe(operation.hlc);
        return false;
      }

      switch (operation.entityType) {
        case 'day':
          await _applyDay(operation);
        case 'period':
          await _applyPeriod(operation);
        case 'custom_log':
          await _applyCustomLog(operation);
        default:
          throw SyncMergeException('Unknown entity type: ${operation.entityType}');
      }

      await database.into(database.fieldClocks).insertOnConflictUpdate(
            FieldClocksCompanion.insert(
              entityId: operation.entityId,
              field: operation.field,
              hlc: operation.hlc,
            ),
          );
      if (tombstone != null) {
        await (database.delete(database.entityTombstones)..where((row) => row.entityId.equals(operation.entityId))).go();
      }
      await hlc.observe(operation.hlc);
      return true;
    });
  }

  Future<void> _applyDay(SyncPlainOperation operation) async {
    if (!operation.entityId.startsWith('day:')) throw const SyncMergeException('Malformed day entity ID.');
    final day = int.tryParse(operation.entityId.substring(4));
    if (day == null) throw const SyncMergeException('Malformed day entity ID.');

    if (operation.field == 'note') {
      if (operation.kind == 'unset') {
        await (database.delete(database.dayNotes)..where((row) => row.day.equals(day))).go();
        return;
      }
      if (operation.kind != 'set' || operation.value is! String) {
        throw const SyncMergeException('Malformed note operation.');
      }
      await database.into(database.dayNotes).insertOnConflictUpdate(
            DayNotesCompanion.insert(
              day: Value(day),
              note: operation.value! as String,
              updatedHlc: operation.hlc,
              updatedMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      return;
    }

    if (operation.kind == 'unset') {
      await (database.delete(database.dayValues)
            ..where((row) => row.day.equals(day) & row.key.equals(operation.field)))
          .go();
      return;
    }
    if (operation.kind != 'set' || operation.value is! Map<String, dynamic>) {
      throw const SyncMergeException('Malformed day-value operation.');
    }
    final value = operation.value! as Map<String, dynamic>;
    final stored = value['value'];
    final severity = value['severity'];
    if (stored is! String || (severity != null && severity is! int)) {
      throw const SyncMergeException('Malformed day-value payload.');
    }
    await database.into(database.dayValues).insertOnConflictUpdate(
          DayValuesCompanion.insert(
            day: day,
            key: operation.field,
            value: stored,
            severity: Value(severity as int?),
            updatedHlc: operation.hlc,
            updatedMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> _applyPeriod(SyncPlainOperation operation) async {
    final current = await (database.select(database.periods)..where((row) => row.id.equals(operation.entityId)))
        .getSingleOrNull();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (operation.kind == 'unset') {
      if (operation.field != 'end_day' || current == null) {
        throw const SyncMergeException('Unsupported period unset operation.');
      }
      await (database.update(database.periods)..where((row) => row.id.equals(operation.entityId))).write(
        PeriodsCompanion(endDay: const Value(null), updatedHlc: Value(operation.hlc), updatedMs: Value(now)),
      );
      return;
    }
    if (operation.kind != 'set') throw const SyncMergeException('Unsupported period operation.');

    switch (operation.field) {
      case 'start_day':
        if (operation.value is! int) throw const SyncMergeException('Invalid period start day.');
        if (current == null) {
          await database.into(database.periods).insert(
                PeriodsCompanion.insert(
                  id: operation.entityId,
                  startDay: operation.value! as int,
                  updatedHlc: operation.hlc,
                  createdMs: now,
                  updatedMs: now,
                ),
              );
        } else {
          await (database.update(database.periods)..where((row) => row.id.equals(operation.entityId))).write(
            PeriodsCompanion(
              startDay: Value(operation.value! as int),
              updatedHlc: Value(operation.hlc),
              updatedMs: Value(now),
            ),
          );
        }
      case 'end_day':
        if (operation.value is! int || current == null) throw const SyncMergeException('Invalid period end day.');
        await (database.update(database.periods)..where((row) => row.id.equals(operation.entityId))).write(
          PeriodsCompanion(
            endDay: Value(operation.value! as int),
            updatedHlc: Value(operation.hlc),
            updatedMs: Value(now),
          ),
        );
      case 'exclude_from_prediction':
        if (operation.value is! bool || current == null) {
          throw const SyncMergeException('Invalid prediction-exclusion operation.');
        }
        await (database.update(database.periods)..where((row) => row.id.equals(operation.entityId))).write(
          PeriodsCompanion(
            excludeFromPrediction: Value(operation.value! as bool),
            updatedHlc: Value(operation.hlc),
            updatedMs: Value(now),
          ),
        );
      default:
        throw SyncMergeException('Unknown period field: ${operation.field}');
    }
  }

  Future<void> _applyCustomLog(SyncPlainOperation operation) async {
    if (!operation.entityId.startsWith('custom_')) {
      throw const SyncMergeException('Malformed custom-log entity ID.');
    }
    if (operation.kind != 'set') throw const SyncMergeException('Unsupported custom-log operation.');
    final current = await (database.select(database.customLogs)
          ..where((row) => row.key.equals(operation.entityId)))
        .getSingleOrNull();
    final now = DateTime.now().millisecondsSinceEpoch;

    switch (operation.field) {
      case 'label':
        if (operation.value is! String || (operation.value! as String).trim().isEmpty) {
          throw const SyncMergeException('Invalid custom-log label.');
        }
        final label = (operation.value! as String).trim();
        if (current == null) {
          await database.into(database.customLogs).insert(
                CustomLogsCompanion.insert(
                  key: operation.entityId,
                  label: label,
                  orderIndex: 0,
                  updatedHlc: operation.hlc,
                  updatedMs: now,
                ),
              );
        } else {
          await (database.update(database.customLogs)..where((row) => row.key.equals(operation.entityId))).write(
            CustomLogsCompanion(label: Value(label), updatedHlc: Value(operation.hlc), updatedMs: Value(now)),
          );
        }
      case 'archived':
        if (operation.value is! bool || current == null) {
          throw const SyncMergeException('Invalid custom-log archive operation.');
        }
        await (database.update(database.customLogs)..where((row) => row.key.equals(operation.entityId))).write(
          CustomLogsCompanion(
            archived: Value(operation.value! as bool),
            updatedHlc: Value(operation.hlc),
            updatedMs: Value(now),
          ),
        );
      case 'order_index':
        if (operation.value is! int || current == null) {
          throw const SyncMergeException('Invalid custom-log order operation.');
        }
        await (database.update(database.customLogs)..where((row) => row.key.equals(operation.entityId))).write(
          CustomLogsCompanion(
            orderIndex: Value(operation.value! as int),
            updatedHlc: Value(operation.hlc),
            updatedMs: Value(now),
          ),
        );
      default:
        throw SyncMergeException('Unknown custom-log field: ${operation.field}');
    }
  }

  Future<void> _deleteEntity(SyncPlainOperation operation) async {
    switch (operation.entityType) {
      case 'day':
        if (!operation.entityId.startsWith('day:')) throw const SyncMergeException('Malformed day entity ID.');
        final day = int.tryParse(operation.entityId.substring(4));
        if (day == null) throw const SyncMergeException('Malformed day entity ID.');
        await (database.delete(database.dayValues)..where((row) => row.day.equals(day))).go();
        await (database.delete(database.dayNotes)..where((row) => row.day.equals(day))).go();
      case 'period':
        await (database.delete(database.periods)..where((row) => row.id.equals(operation.entityId))).go();
      case 'custom_log':
        await (database.delete(database.customLogs)..where((row) => row.key.equals(operation.entityId))).go();
      default:
        throw SyncMergeException('Unknown entity type: ${operation.entityType}');
    }
  }
}

final class SyncMergeException implements Exception {
  const SyncMergeException(this.message);

  final String message;

  @override
  String toString() => 'SyncMergeException: $message';
}
