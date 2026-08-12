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

  Future<String> recordPeriod({required LocalDay start, LocalDay? end, String? id}) async {
    _validateDates(start, end);

    // Repeated taps on "period started" must not create duplicate cycles. If
    // the same start already exists, enrich its end date when one was supplied.
    final sameStart = await (database.select(database.periods)..where((row) => row.startDay.equals(start.epochDay)))
        .getSingleOrNull();
    if (sameStart != null) {
      if (end != null && sameStart.endDay != end.epochDay) {
        await updatePeriod(id: sameStart.id, start: start, end: end);
      }
      return sameStart.id;
    }

    // Marking a day already contained by a completed recorded period is also a
    // no-op. Corrections belong in period history where the dates are explicit.
    final history = await database.select(database.periods).get();
    for (final row in history) {
      final recordedEnd = row.endDay ?? row.startDay;
      if (start.epochDay >= row.startDay && start.epochDay <= recordedEnd) return row.id;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final entityId = id ?? _id();

    await database.transaction(() async {
      final startClock = await hlc.next(nowMillis: now);
      final endClock = end == null ? null : await hlc.next(nowMillis: now);
      await database.into(database.periods).insert(
            PeriodsCompanion.insert(
              id: entityId,
              startDay: start.epochDay,
              endDay: Value(end?.epochDay),
              updatedHlc: endClock ?? startClock,
              createdMs: now,
              updatedMs: now,
            ),
          );
      await _mutation(entityId, 'period', 'start_day', 'set', start.epochDay, startClock, now);
      if (end != null) await _mutation(entityId, 'period', 'end_day', 'set', end.epochDay, endClock!, now);
    });
    return entityId;
  }

  Future<void> updatePeriod({required String id, required LocalDay start, LocalDay? end}) async {
    _validateDates(start, end);
    final current = await (database.select(database.periods)..where((row) => row.id.equals(id))).getSingleOrNull();
    if (current == null) throw StateError('Period record no longer exists.');

    final startChanged = current.startDay != start.epochDay;
    final endChanged = current.endDay != end?.epochDay;
    if (!startChanged && !endChanged) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await database.transaction(() async {
      String? latestClock;
      if (startChanged) {
        latestClock = await hlc.next(nowMillis: now);
        await _mutation(id, 'period', 'start_day', 'set', start.epochDay, latestClock, now);
      }
      if (endChanged) {
        latestClock = await hlc.next(nowMillis: now);
        await _mutation(
          id,
          'period',
          'end_day',
          end == null ? 'unset' : 'set',
          end?.epochDay,
          latestClock,
          now,
        );
      }
      await (database.update(database.periods)..where((row) => row.id.equals(id))).write(
        PeriodsCompanion(
          startDay: Value(start.epochDay),
          endDay: Value(end?.epochDay),
          updatedHlc: Value(latestClock!),
          updatedMs: Value(now),
        ),
      );
    });
  }

  Future<void> deletePeriod(String id) async {
    final current = await (database.select(database.periods)..where((row) => row.id.equals(id))).getSingleOrNull();
    if (current == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.transaction(() async {
      final clock = await hlc.next(nowMillis: now);
      await (database.delete(database.periods)..where((row) => row.id.equals(id))).go();
      await database.into(database.localMutations).insert(
            LocalMutationsCompanion.insert(
              opId: _id(),
              entityId: id,
              entityType: 'period',
              field: '_entity',
              kind: 'delete',
              hlc: clock,
              createdMs: now,
            ),
          );
      await database.into(database.entityTombstones).insertOnConflictUpdate(
            EntityTombstonesCompanion.insert(entityId: id, hlc: clock),
          );
    });
  }

  Future<void> setPredictionExcluded(String id, bool excluded) async {
    final current = await (database.select(database.periods)..where((row) => row.id.equals(id))).getSingleOrNull();
    if (current == null) throw StateError('Period record no longer exists.');
    if (current.excludeFromPrediction == excluded) return;

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

  void _validateDates(LocalDay start, LocalDay? end) {
    if (end != null && end.epochDay < start.epochDay) {
      throw ArgumentError('Period end cannot be before its start.');
    }
    if (end != null && end.epochDay - start.epochDay > 30) {
      throw ArgumentError('A single period record cannot span more than 31 days.');
    }
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
