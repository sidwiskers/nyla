import 'dart:convert';

import '../../data/database/app_database.dart';

final class DataExportService {
  const DataExportService(this.database);

  final AppDatabase database;

  Future<String> buildJson() async {
    final periods = await database.select(database.periods).get();
    final dayValues = await database.select(database.dayValues).get();
    final dayNotes = await database.select(database.dayNotes).get();
    final customLogs = await database.select(database.customLogs).get();
    final preferences = await database.select(database.preferences).get();

    final payload = <String, Object?>{
      'format': 'nyla-export',
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'privacy': <String, Object?>{
        'contains_sync_keys': false,
        'contains_device_credentials': false,
        'note': 'This user-requested export is readable JSON. Protect it like any other health record.',
      },
      'periods': [
        for (final row in periods)
          <String, Object?>{
            'id': row.id,
            'start_day': row.startDay,
            'end_day': row.endDay,
            'exclude_from_prediction': row.excludeFromPrediction,
            'created_ms': row.createdMs,
            'updated_ms': row.updatedMs,
          },
      ],
      'day_values': [
        for (final row in dayValues)
          <String, Object?>{
            'day': row.day,
            'key': row.key,
            'value': row.value,
            'severity': row.severity,
            'updated_ms': row.updatedMs,
          },
      ],
      'day_notes': [
        for (final row in dayNotes)
          <String, Object?>{
            'day': row.day,
            'note': row.note,
            'updated_ms': row.updatedMs,
          },
      ],
      'custom_logs': [
        for (final row in customLogs)
          <String, Object?>{
            'key': row.key,
            'label': row.label,
            'archived': row.archived,
            'order_index': row.orderIndex,
            'updated_ms': row.updatedMs,
          },
      ],
      'preferences': <String, Object?>{
        for (final row in preferences) row.key: row.value,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
