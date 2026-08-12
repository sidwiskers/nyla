import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('PeriodEntry')
class Periods extends Table {
  TextColumn get id => text()();
  IntColumn get startDay => integer()();
  IntColumn get endDay => integer().nullable()();
  BoolColumn get excludeFromPrediction => boolean().withDefault(const Constant(false))();
  TextColumn get updatedHlc => text()();
  IntColumn get createdMs => integer()();
  IntColumn get updatedMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DayValueEntry')
class DayValues extends Table {
  IntColumn get day => integer()();
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get severity => integer().nullable()();
  TextColumn get updatedHlc => text()();
  IntColumn get updatedMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {day, key};
}

@DataClassName('DayNoteEntry')
class DayNotes extends Table {
  IntColumn get day => integer()();
  TextColumn get note => text()();
  TextColumn get updatedHlc => text()();
  IntColumn get updatedMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {day};
}

@DataClassName('CustomLogEntry')
class CustomLogs extends Table {
  TextColumn get key => text()();
  TextColumn get label => text()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get orderIndex => integer()();
  TextColumn get updatedHlc => text()();
  IntColumn get updatedMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DataClassName('PreferenceEntry')
class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DataClassName('LocalMutationEntry')
class LocalMutations extends Table {
  TextColumn get opId => text()();
  TextColumn get entityId => text()();
  TextColumn get entityType => text()();
  TextColumn get field => text()();
  TextColumn get kind => text()();
  TextColumn get valueJson => text().nullable()();
  TextColumn get hlc => text()();
  IntColumn get createdMs => integer()();
  BoolColumn get checkpointed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {opId};
}

@DataClassName('FieldClockEntry')
class FieldClocks extends Table {
  TextColumn get entityId => text()();
  TextColumn get field => text()();
  TextColumn get hlc => text()();

  @override
  Set<Column<Object>> get primaryKey => {entityId, field};
}

@DataClassName('SyncStateEntry')
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Periods,
    DayValues,
    DayNotes,
    CustomLogs,
    Preferences,
    LocalMutations,
    FieldClocks,
    SyncState,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  static Future<AppDatabase> open(String databaseKeyHex) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(databaseKeyHex)) {
      throw ArgumentError.value(databaseKeyHex, 'databaseKeyHex', 'Expected a 256-bit hex key');
    }
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, 'nyla.db'));
    final executor = NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        rawDb.execute('PRAGMA key = "x\'$databaseKeyHex\'";');
        final cipher = rawDb.select('PRAGMA cipher_version;');
        if (cipher.isEmpty) throw StateError('Encrypted SQLite provider is unavailable.');
        rawDb.execute('PRAGMA cipher_memory_security = ON;');
        rawDb.execute('PRAGMA foreign_keys = ON;');
        rawDb.execute('PRAGMA secure_delete = ON;');
        rawDb.execute('PRAGMA journal_mode = WAL;');
      },
    );
    return AppDatabase(executor);
  }

  @override
  int get schemaVersion => 1;

  Stream<List<PeriodEntry>> watchPeriodHistory() =>
      (select(periods)..orderBy([(row) => OrderingTerm.desc(row.startDay)])).watch();

  Stream<List<DayValueEntry>> watchDay(int epochDay) =>
      (select(dayValues)..where((row) => row.day.equals(epochDay))).watch();

  Future<String?> preference(String key) async =>
      (await (select(preferences)..where((row) => row.key.equals(key))).getSingleOrNull())?.value;

  Stream<String?> watchPreference(String key) =>
      (select(preferences)..where((row) => row.key.equals(key))).watchSingleOrNull().map((row) => row?.value);

  Future<void> setPreference(String key, String value) => into(preferences).insertOnConflictUpdate(
        PreferencesCompanion.insert(key: key, value: value, updatedMs: DateTime.now().millisecondsSinceEpoch),
      );
}
