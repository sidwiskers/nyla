import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/data/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('pending outbox stream grows on local mutation and falls on upload', () async {
    final expectation = expectLater(
      database.watchPendingMutationCount(),
      emitsInOrder(<Object>[0, 1, 0]),
    );

    await database.into(database.localMutations).insert(
          LocalMutationsCompanion.insert(
            opId: 'test-operation-01',
            entityId: 'day:21000',
            entityType: 'day',
            field: 'cramps',
            kind: 'set',
            hlc: '2100000000000:0:test-device',
            createdMs: 2100000000000,
          ),
        );
    await database.markMutationsUploaded(const <String>['test-operation-01']);

    await expectation;
  });
}
