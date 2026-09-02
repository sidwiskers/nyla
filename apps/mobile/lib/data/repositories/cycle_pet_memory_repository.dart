import 'dart:async';
import 'dart:convert';

import '../database/app_database.dart';

class CyclePetMemory {
  const CyclePetMemory({
    this.daysPetted = 0,
    this.lastPettedDay,
  });

  static const maxBondDays = 14;

  final int daysPetted;
  final int? lastPettedDay;

  double get familiarity =>
      daysPetted.clamp(0, maxBondDays).toDouble() / maxBondDays;

  bool wasPettedRecently(int today) {
    final last = lastPettedDay;
    if (last == null) return false;
    final age = today - last;
    return age >= 0 && age <= 1;
  }

  CyclePetMemory recordPet(int day) => CyclePetMemory(
        // Relationship grows by days met, not by repeatedly rubbing the pet in
        // one session. There is intentionally no streak, score or maintenance
        // mechanic for the user to worry about.
        daysPetted: lastPettedDay == day
            ? daysPetted
            : (daysPetted + 1).clamp(0, maxBondDays).toInt(),
        lastPettedDay: day,
      );

  String encode() => jsonEncode({
        'days_petted': daysPetted,
        'last_petted_day': lastPettedDay,
      });

  static CyclePetMemory decode(String? raw) {
    if (raw == null || raw.isEmpty) return const CyclePetMemory();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const CyclePetMemory();
      final days = decoded['days_petted'];
      final last = decoded['last_petted_day'];
      return CyclePetMemory(
        daysPetted:
            days is int ? days.clamp(0, maxBondDays).toInt() : 0,
        lastPettedDay: last is int ? last : null,
      );
    } catch (_) {
      return const CyclePetMemory();
    }
  }
}

class CyclePetMemoryRepository {
  CyclePetMemoryRepository(this.database);

  static const _key = 'companion.pet.memory.v1';

  final AppDatabase database;
  Future<void> _writeTail = Future<void>.value();

  Stream<CyclePetMemory> watch() =>
      database.watchPreference(_key).map(CyclePetMemory.decode);

  Future<CyclePetMemory> current() async =>
      CyclePetMemory.decode(await database.preference(_key));

  Future<void> recordPet(int day) {
    final next = _writeTail.then(
      (_) => _recordPetNow(day),
      onError: (_) => _recordPetNow(day),
    );
    _writeTail = next;
    return next;
  }

  Future<void> _recordPetNow(int day) async {
    final memory = await current();
    await database.setPreference(_key, memory.recordPet(day).encode());
  }
}
