import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/core/export/data_export_service.dart';
import 'package:nyla/core/sync/hlc_service.dart';
import 'package:nyla/data/database/app_database.dart';
import 'package:nyla/data/repositories/cycle_repository.dart';
import 'package:nyla/data/repositories/day_log_repository.dart';
import 'package:cycle_engine/cycle_engine.dart';

void main() {
  test('export contains user health data but never synchronization secrets', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final hlc = HlcService(database, 'export-device-0001');

    await CycleRepository(database, hlc).recordPeriod(
      id: 'period-export-0001',
      start: const LocalDay(21000),
      end: const LocalDay(21004),
    );
    await DayLogRepository(database, hlc).setValue(
      epochDay: 21000,
      key: 'flow',
      value: 'medium',
      severity: 2,
    );
    await database.setPreference('notification.config.v1', '{"privacy":"private"}');
    await database.into(database.syncState).insert(
          SyncStateCompanion.insert(key: 'secret-looking-state', value: 'must-not-export'),
        );

    final decoded = jsonDecode(await DataExportService(database).buildJson()) as Map<String, dynamic>;
    expect(decoded['format'], 'nyla-export');
    expect(decoded['version'], 1);
    expect(decoded['periods'], hasLength(1));
    expect(decoded['day_values'], hasLength(1));
    expect((decoded['privacy'] as Map<String, dynamic>)['contains_sync_keys'], isFalse);
    expect(decoded.toString(), isNot(contains('must-not-export')));
    expect(decoded.containsKey('sync_state'), isFalse);
    expect(decoded.containsKey('local_mutations'), isFalse);
  });
}
