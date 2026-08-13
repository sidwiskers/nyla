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
  BoolColumn get uploaded => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {opId};
}

@DataClassName('EntityTombstoneEntry')
class EntityTombstones extends Table {
  TextColumn get entityId => text()();
  TextColumn get hlc => text()();

  @override
  Set<Column<Object>> get primaryKey => {entityId};
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
    EntityTombstones,
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
    final file = await _databaseFile();
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
        // Foreground repositories and a WorkManager isolate may briefly share
        // this WAL database. Wait for the active writer instead of surfacing an
        // incidental SQLITE_BUSY to a health-data edit or remote merge.
        rawDb.execute('PRAGMA busy_timeout = 5000;');
      },
    );
    return AppDatabase(executor);
  }

  /// Removes the encrypted local database and every SQLite sidecar.
  ///
  /// Callers must close the active database and destroy its encryption key
  /// before invoking this. WAL/SHM/journal files are included so a requested
  /// local erase does not leave readable database pages behind.
  static Future<void> deleteLocalFiles() async {
    final file = await _databaseFile();
    for (final path in <String>[
      file.path,
      '${file.path}-wal',
      '${file.path}-shm',
      '${file.path}-journal',
    ]) {
      final candidate = File(path);
      if (await candidate.exists()) await candidate.delete();
    }
  }

  static Future<File> _databaseFile() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File(p.join(directory.path, 'nyla.db'));
  }

  @override
  int get schemaVersion => 1;

  Stream<List<PeriodEntry>> watchPeriodHistory() =>
      (select(periods)..orderBy([(row) => OrderingTerm.desc(row.startDay)])).watch();

  Stream<List<DayValueEntry>> watchDay(int epochDay) =>
      (select(dayValues)..where((row) => row.day.equals(epochDay))).watch();

  Stream<List<DayValueEntry>> watchAllDayValues() => select(dayValues).watch();

  Future<List<LocalMutationEntry>> pendingMutations({int limit = 128}) =>
      (select(localMutations)
            ..where((row) => row.uploaded.equals(false))
            ..orderBy([(row) => OrderingTerm.asc(row.createdMs), (row) => OrderingTerm.asc(row.opId)])
            ..limit(limit))
          .get();

  Future<void> markMutationsUploaded(Iterable<String> opIds) async {
    final ids = opIds.toList(growable: false);
    if (ids.isEmpty) return;
    await (update(localMutations)..where((row) => row.opId.isIn(ids))).write(
      const LocalMutationsCompanion(uploaded: Value(true)),
    );
  }

  Future<int> pendingMutationCount() async {
    final count = localMutations.opId.count();
    final query = selectOnly(localMutations)
      ..addColumns([count])
      ..where(localMutations.uploaded.equals(false));
    return (await query.map((row) => row.read(count) ?? 0).getSingle());
  }

  Stream<int> watchPendingMutationCount() {
    final count = localMutations.opId.count();
    final query = selectOnly(localMutations)
      ..addColumns([count])
      ..where(localMutations.uploaded.equals(false));
    return query.watchSingle().map((row) => row.read(count) ?? 0).distinct();
  }

  Future<String?> preference(String key) async =>
      (await (select(preferences)..where((row) => row.key.equals(key))).getSingleOrNull())?.value;

  Stream<String?> watchPreference(String key) =>
      (select(preferences)..where((row) => row.key.equals(key))).watchSingleOrNull().map((row) => row?.value);

  Future<void> setPreference(String key, String value) => into(preferences).insertOnConflictUpdate(
        PreferencesCompanion.insert(key: key, value: value, updatedMs: DateTime.now().millisecondsSinceEpoch),
      );
}
