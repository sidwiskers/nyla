import 'package:cycle_engine/cycle_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/core/sync/hlc_service.dart';
import 'package:nyla/data/database/app_database.dart';
import 'package:nyla/data/repositories/cycle_repository.dart';
import 'package:nyla/data/repositories/day_log_repository.dart';

void main() {
  late AppDatabase database;
  late HlcService hlc;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    hlc = HlcService(database, 'test-device-node-01');
  });

  tearDown(() async {
    await database.close();
  });

  test('daily values and notes are persisted with field-granular sync mutations', () async {
    final repository = DayLogRepository(database, hlc);

    await repository.setValue(
      epochDay: 21000,
      key: 'cramps',
      value: 'moderate',
      severity: 2,
    );
    await repository.setNote(epochDay: 21000, note: '  Needed a heating pad.  ');

    final values = await database.watchDay(21000).first;
    expect(values, hasLength(1));
    expect(values.single.key, 'cramps');
    expect(values.single.value, 'moderate');
    expect(values.single.severity, 2);
    expect(await repository.noteForDay(21000), 'Needed a heating pad.');

    final pending = await database.pendingMutations();
    expect(pending, hasLength(2));
    expect(pending.map((entry) => entry.field), containsAll(<String>['cramps', 'note']));
    expect(pending.every((entry) => entry.entityId == 'day:21000'), isTrue);

    await repository.clearValue(epochDay: 21000, key: 'cramps');
    expect(await database.watchDay(21000).first, isEmpty);

    final afterClear = await database.pendingMutations();
    expect(afterClear, hasLength(3));
    expect(afterClear.last.field, 'cramps');
    expect(afterClear.last.kind, 'unset');
  });

  test('period recording validates dates and emits independent period fields', () async {
    final repository = CycleRepository(database, hlc);

    await repository.recordPeriod(
      id: 'period-test-0001',
      start: const LocalDay(21000),
      end: const LocalDay(21004),
    );

    final periods = await repository.watchPeriods().first;
    expect(periods, hasLength(1));
    expect(periods.single.startDay, 21000);
    expect(periods.single.endDay, 21004);

    final pending = await database.pendingMutations();
    expect(pending, hasLength(2));
    expect(pending.map((entry) => entry.field), containsAll(<String>['start_day', 'end_day']));

    expect(
      () => repository.recordPeriod(
        start: const LocalDay(21010),
        end: const LocalDay(21009),
      ),
      throwsArgumentError,
    );
  });
}
