import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/core/sync/hlc_service.dart';
import 'package:nyla/core/sync/sync_merge.dart';
import 'package:nyla/data/database/app_database.dart';
import 'package:sync_core/sync_core.dart';

void main() {
  late AppDatabase database;
  late SyncMergeEngine merge;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    merge = SyncMergeEngine(database, HlcService(database, 'receiver-device-01'));
  });

  tearDown(() async {
    await database.close();
  });

  SyncPlainOperation dayValue({
    required String opId,
    required String hlc,
    required String value,
    int severity = 1,
  }) => SyncPlainOperation(
        opId: opId,
        entityId: 'day:21000',
        entityType: 'day',
        field: 'cramps',
        hlc: hlc,
        kind: 'set',
        value: <String, Object?>{'value': value, 'severity': severity},
      );

  test('newer field operation wins and stale replay is ignored', () async {
    final newer = dayValue(
      opId: 'operation-newer-01',
      hlc: '2000:0:remote-device-02',
      value: 'strong',
      severity: 3,
    );
    final older = dayValue(
      opId: 'operation-older-01',
      hlc: '1000:0:remote-device-01',
      value: 'mild',
      severity: 1,
    );

    expect(await merge.apply(newer), isTrue);
    expect(await merge.apply(older), isFalse);

    final values = await database.watchDay(21000).first;
    expect(values, hasLength(1));
    expect(values.single.value, 'strong');
    expect(values.single.severity, 3);
  });

  test('a newer delete tombstones an entity and blocks older resurrection', () async {
    expect(
      await merge.apply(
        dayValue(
          opId: 'operation-value-01',
          hlc: '1000:0:remote-device-01',
          value: 'moderate',
          severity: 2,
        ),
      ),
      isTrue,
    );

    final deletion = SyncPlainOperation(
      opId: 'operation-delete-01',
      entityId: 'day:21000',
      entityType: 'day',
      field: '_entity',
      hlc: '3000:0:remote-device-02',
      kind: 'delete',
      value: null,
    );
    expect(await merge.apply(deletion), isTrue);
    expect(await database.watchDay(21000).first, isEmpty);

    expect(
      await merge.apply(
        dayValue(
          opId: 'operation-stale-01',
          hlc: '2000:0:remote-device-03',
          value: 'strong',
          severity: 3,
        ),
      ),
      isFalse,
    );
    expect(await database.watchDay(21000).first, isEmpty);
  });

  test('custom log definitions materialize field by field in causal order', () async {
    final operations = [
      const SyncPlainOperation(
        opId: 'custom-label-01',
        entityId: 'custom_example_01',
        entityType: 'custom_log',
        field: 'label',
        hlc: '1000:0:remote-device-01',
        kind: 'set',
        value: 'Leg aches',
      ),
      const SyncPlainOperation(
        opId: 'custom-archived-01',
        entityId: 'custom_example_01',
        entityType: 'custom_log',
        field: 'archived',
        hlc: '1000:1:remote-device-01',
        kind: 'set',
        value: false,
      ),
      const SyncPlainOperation(
        opId: 'custom-order-01',
        entityId: 'custom_example_01',
        entityType: 'custom_log',
        field: 'order_index',
        hlc: '1000:2:remote-device-01',
        kind: 'set',
        value: 3,
      ),
    ];

    for (final operation in operations) {
      expect(await merge.apply(operation), isTrue);
    }
    final row = await database.select(database.customLogs).getSingle();
    expect(row.label, 'Leg aches');
    expect(row.archived, isFalse);
    expect(row.orderIndex, 3);
  });

  test('an older entity delete cannot erase a newer offline field edit', () async {
    expect(
      await merge.apply(
        dayValue(
          opId: 'operation-newer-field-01',
          hlc: '4000:0:remote-device-03',
          value: 'strong',
          severity: 3,
        ),
      ),
      isTrue,
    );

    final staleDeletion = SyncPlainOperation(
      opId: 'operation-stale-delete-01',
      entityId: 'day:21000',
      entityType: 'day',
      field: '_entity',
      hlc: '3000:0:remote-device-02',
      kind: 'delete',
      value: null,
    );
    expect(await merge.apply(staleDeletion), isFalse);

    final values = await database.watchDay(21000).first;
    expect(values, hasLength(1));
    expect(values.single.value, 'strong');
    expect(
      await (database.select(database.entityTombstones)
            ..where((row) => row.entityId.equals('day:21000')))
          .getSingleOrNull(),
      isNull,
    );
  });

  test('a field operation newer than a tombstone deterministically restores the entity', () async {
    final deletion = SyncPlainOperation(
      opId: 'operation-delete-02',
      entityId: 'day:21000',
      entityType: 'day',
      field: '_entity',
      hlc: '3000:0:remote-device-02',
      kind: 'delete',
      value: null,
    );
    expect(await merge.apply(deletion), isTrue);

    expect(
      await merge.apply(
        dayValue(
          opId: 'operation-restore-01',
          hlc: '4000:0:remote-device-03',
          value: 'mild',
          severity: 1,
        ),
      ),
      isTrue,
    );

    final values = await database.watchDay(21000).first;
    expect(values.single.value, 'mild');
    expect(
      await (database.select(database.entityTombstones)
            ..where((row) => row.entityId.equals('day:21000')))
          .getSingleOrNull(),
      isNull,
    );
  });
}
