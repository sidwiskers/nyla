import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/core/sync/hlc_service.dart';
import 'package:nyla/data/database/app_database.dart';
import 'package:nyla/data/repositories/custom_log_repository.dart';

void main() {
  late AppDatabase database;
  late CustomLogRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = CustomLogRepository(database, HlcService(database, 'custom-log-device-01'));
  });

  tearDown(() => database.close());

  test('custom log creation emits complete sync definition and normalizes its label', () async {
    final key = await repository.create('  Leg   aches  ');
    final row = (await repository.watchAll().first).single;
    expect(row.key, key);
    expect(row.label, 'Leg aches');
    expect(row.archived, isFalse);

    final operations = await database.pendingMutations();
    expect(operations, hasLength(3));
    expect(operations.every((operation) => operation.entityType == 'custom_log'), isTrue);
    expect(operations.map((operation) => operation.field), containsAll(['label', 'archived', 'order_index']));
  });

  test('custom log labels are unique and archive preserves the definition', () async {
    final key = await repository.create('Leg aches');
    await expectLater(repository.create(' leg ACHES '), throwsArgumentError);

    await repository.setArchived(key, true);
    await repository.rename(key, 'Leg tension');
    final row = (await repository.watchAll().first).single;
    expect(row.archived, isTrue);
    expect(row.label, 'Leg tension');
  });
}
