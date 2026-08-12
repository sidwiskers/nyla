import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/core/sync/hlc_service.dart';
import 'package:nyla/core/sync/sync_checkpoint.dart';
import 'package:nyla/core/sync/sync_merge.dart';
import 'package:nyla/data/database/app_database.dart';
import 'package:sync_core/sync_core.dart';

void main() {
  SyncPlainOperation operation({
    required String op,
    required String entity,
    required String type,
    required String field,
    required String hlc,
    required String kind,
    Object? value,
  }) =>
      SyncPlainOperation(
        opId: op,
        entityId: entity,
        entityType: type,
        field: field,
        hlc: hlc,
        kind: kind,
        value: value,
      );

  test('checkpoint materializes full state but preserves newer offline target fields', () async {
    final source = AppDatabase(NativeDatabase.memory());
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(target.close);
    final sourceMerge = SyncMergeEngine(source, HlcService(source, 'source-checkpoint-device'));
    final targetMerge = SyncMergeEngine(target, HlcService(target, 'target-checkpoint-device'));

    await sourceMerge.apply(
      operation(
        op: 'source-cramps-001',
        entity: 'day:21000',
        type: 'day',
        field: 'cramps',
        hlc: '2000:0:source-device',
        kind: 'set',
        value: <String, Object?>{'value': 'moderate', 'severity': 2},
      ),
    );
    await sourceMerge.apply(
      operation(
        op: 'source-flow-00001',
        entity: 'day:21000',
        type: 'day',
        field: 'flow',
        hlc: '2100:0:source-device',
        kind: 'set',
        value: <String, Object?>{'value': 'medium', 'severity': 2},
      ),
    );
    await targetMerge.apply(
      operation(
        op: 'target-cramps-001',
        entity: 'day:21000',
        type: 'day',
        field: 'cramps',
        hlc: '3000:0:target-device',
        kind: 'set',
        value: <String, Object?>{'value': 'strong', 'severity': 3},
      ),
    );

    final bytes = await SyncCheckpointCodec(source, sourceMerge).encode(baseCursor: 91);
    final applied = await SyncCheckpointCodec(target, targetMerge).apply(compressed: bytes, expectedBaseCursor: 91);
    expect(applied, 1);

    final values = await target.watchDay(21000).first;
    final byKey = {for (final row in values) row.key: row};
    expect(byKey['cramps']?.value, 'strong');
    expect(byKey['flow']?.value, 'medium');
  });

  test('checkpoint orders required period anchor before fields even when its HLC is newer', () async {
    final source = AppDatabase(NativeDatabase.memory());
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(target.close);
    final sourceMerge = SyncMergeEngine(source, HlcService(source, 'source-period-device'));
    final targetMerge = SyncMergeEngine(target, HlcService(target, 'target-period-device'));

    await sourceMerge.apply(
      operation(
        op: 'period-start-old01',
        entity: 'period_checkpoint_01',
        type: 'period',
        field: 'start_day',
        hlc: '1000:0:source-device',
        kind: 'set',
        value: 21000,
      ),
    );
    await sourceMerge.apply(
      operation(
        op: 'period-end-value01',
        entity: 'period_checkpoint_01',
        type: 'period',
        field: 'end_day',
        hlc: '2000:0:source-device',
        kind: 'set',
        value: 21004,
      ),
    );
    await sourceMerge.apply(
      operation(
        op: 'period-start-new01',
        entity: 'period_checkpoint_01',
        type: 'period',
        field: 'start_day',
        hlc: '3000:0:source-device',
        kind: 'set',
        value: 21001,
      ),
    );

    final bytes = await SyncCheckpointCodec(source, sourceMerge).encode(baseCursor: 120);
    await SyncCheckpointCodec(target, targetMerge).apply(compressed: bytes, expectedBaseCursor: 120);
    final period = await target.select(target.periods).getSingle();
    expect(period.startDay, 21001);
    expect(period.endDay, 21004);
  });

  test('checkpoint carries tombstones so stale material is removed', () async {
    final source = AppDatabase(NativeDatabase.memory());
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(target.close);
    final sourceMerge = SyncMergeEngine(source, HlcService(source, 'source-delete-device'));
    final targetMerge = SyncMergeEngine(target, HlcService(target, 'target-delete-device'));

    final oldValue = operation(
      op: 'old-day-value-0001',
      entity: 'day:22000',
      type: 'day',
      field: 'headache',
      hlc: '1000:0:source-device',
      kind: 'set',
      value: <String, Object?>{'value': 'mild', 'severity': 1},
    );
    await sourceMerge.apply(oldValue);
    await targetMerge.apply(oldValue);
    await sourceMerge.apply(
      operation(
        op: 'delete-day-000001',
        entity: 'day:22000',
        type: 'day',
        field: '_entity',
        hlc: '2500:0:source-device',
        kind: 'delete',
      ),
    );

    final bytes = await SyncCheckpointCodec(source, sourceMerge).encode(baseCursor: 44);
    await SyncCheckpointCodec(target, targetMerge).apply(compressed: bytes, expectedBaseCursor: 44);
    expect(await target.watchDay(22000).first, isEmpty);
    expect(await target.select(target.entityTombstones).getSingle(), isNotNull);
  });
}
