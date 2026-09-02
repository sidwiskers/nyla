import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/data/database/app_database.dart';
import 'package:nyla/data/repositories/cycle_pet_memory_repository.dart';

void main() {
  test('pet memory grows by distinct days rather than repeated strokes', () {
    const empty = CyclePetMemory();
    final first = empty.recordPet(100);
    final sameDay = first.recordPet(100).recordPet(100);
    final nextDay = sameDay.recordPet(101);

    expect(first.daysPetted, 1);
    expect(sameDay.daysPetted, 1);
    expect(nextDay.daysPetted, 2);
    expect(nextDay.lastPettedDay, 101);
    expect(nextDay.wasPettedRecently(102), isTrue);
    expect(nextDay.wasPettedRecently(103), isFalse);
  });

  test('pet memory decoding is defensive and familiarity is bounded', () {
    expect(CyclePetMemory.decode('not-json').daysPetted, 0);
    expect(CyclePetMemory.decode('{"days_petted":999}').daysPetted, 14);
    expect(CyclePetMemory.decode('{"days_petted":-5}').daysPetted, 0);
    expect(
      const CyclePetMemory(daysPetted: 14).familiarity,
      1,
    );
  });

  test('repository serializes rapid pet writes without inflating one day', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = CyclePetMemoryRepository(database);

    await Future.wait([
      repository.recordPet(200),
      repository.recordPet(200),
      repository.recordPet(201),
    ]);

    final memory = await repository.current();
    expect(memory.daysPetted, 2);
    expect(memory.lastPettedDay, 201);
  });

  test('bond growth caps without creating a maintenance mechanic', () {
    var memory = const CyclePetMemory();
    for (var day = 1; day <= 40; day++) {
      memory = memory.recordPet(day);
    }

    expect(memory.daysPetted, CyclePetMemory.maxBondDays);
    expect(memory.familiarity, 1);
    expect(memory.lastPettedDay, 40);
  });
}
