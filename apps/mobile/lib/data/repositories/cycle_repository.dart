import 'dart:convert';
import 'dart:math';

import 'package:cycle_engine/cycle_engine.dart';
import 'package:drift/drift.dart';

import '../../core/sync/hlc_service.dart';
import '../database/app_database.dart';

class CycleRepository {
  CycleRepository(this.database, this.hlc);

  final AppDatabase database;
  final HlcService hlc;

  Stream<List<PeriodEntry>> watchPeriods() => database.watchPeriodHistory();

  Stream<PredictionResult> watchPrediction() => watchPeriods().map((rows) {
        final records = rows
            .map(
              (row) => PeriodRecord(
                start: LocalDay(row.startDay),
                end: row.endDay == null ? null : LocalDay(row.endDay!),
                excludeFromPrediction: row.excludeFromPrediction,
              ),
            )
            .toList();
        return const CyclePredictor().predict(records);
      });

  Future<void> recordPeriod({required LocalDay start, LocalDay? end, String? id}) async {
    if (end != null && end.epochDay < start.epochDay) {
      throw ArgumentError('Period end cannot be before its start.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final entityId = id ?? _id();

    await database.transaction(() async {
      final clock = await hlc.next(nowMillis: now);
      await database.into(database.periods).insertOnConflictUpdate(
            PeriodsCompanion.insert(
              id: entityId,
              startDay: start.epochDay,
              endDay: Value(end?.epochDay),
              updatedHlc: clock,
              createdMs: now,
              updatedMs: now,
            ),
          );
      await _mutation(entityId, 'period', 'start_day', 'set', start.epochDay, clock, now);
      if (end != null) await _mutation(entityId, 'period', 'end_day', 'set', end.epochDay, clock, now);
    });
  }

  Future<void> setPredictionExcluded(String id, bool excluded) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.transaction(() async {
      final clock = await hlc.next(nowMillis: now);
      await (database.update(database.periods)..where((row) => row.id.equals(id))).write(
        PeriodsCompanion(
          excludeFromPrediction: Value(excluded),
          updatedHlc: Value(clock),
          updatedMs: Value(now),
        ),
      );
      await _mutation(id, 'period', 'exclude_from_prediction', 'set', excluded, clock, now);
    });
  }

  Future<void> _mutation(
    String entityId,
    String entityType,
    String field,
    String kind,
    Object? value,
    String clock,
    int now,
  ) async {
    await database.into(database.localMutations).insert(
          LocalMutationsCompanion.insert(
            opId: _id(),
            entityId: entityId,
            entityType: entityType,
            field: field,
            kind: kind,
            valueJson: Value(value == null ? null : jsonEncode(value)),
            hlc: clock,
            createdMs: now,
          ),
        );
    await database.into(database.fieldClocks).insertOnConflictUpdate(
          FieldClocksCompanion.insert(entityId: entityId, field: field, hlc: clock),
        );
  }

  String _id() => base64UrlEncode(
        List<int>.generate(16, (_) => Random.secure().nextInt(256), growable: false),
      ).replaceAll('=', '');
}
