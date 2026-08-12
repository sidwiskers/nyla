import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/core/sync/sync_order.dart';
import 'package:nyla/data/database/app_database.dart';

void main() {
  test('operations sharing a storage timestamp upload in HLC causal order', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    for (final row in const [
      ('op-z', 'period-1', 'end_day', '1000:2:device-a'),
      ('op-a', 'period-1', 'exclude_from_prediction', '1000:10:device-a'),
      ('op-m', 'period-1', 'start_day', '1000:1:device-a'),
    ]) {
      await database.into(database.localMutations).insert(
            LocalMutationsCompanion.insert(
              opId: row.$1,
              entityId: row.$2,
              entityType: 'period',
              field: row.$3,
              kind: 'set',
              valueJson: const Value('1'),
              hlc: row.$4,
              createdMs: 1000,
            ),
          );
    }

    final ordered = orderPendingMutations(await database.pendingMutations());
    expect(ordered.map((entry) => entry.field), ['start_day', 'end_day', 'exclude_from_prediction']);
  });
}
