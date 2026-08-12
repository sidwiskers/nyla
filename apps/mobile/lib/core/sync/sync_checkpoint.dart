import 'dart:convert';
import 'dart:io';

import 'package:sync_core/sync_core.dart';

import '../../data/database/app_database.dart';
import 'sync_merge.dart';

/// Serializes the materialized sync state into a compact checkpoint and merges
/// it back through the normal field-level CRDT rules.
///
/// Checkpoints intentionally contain no device credentials, recovery material,
/// preferences or pending local operations. Field clocks and tombstones are
/// represented as ordinary sync operations so a newer offline local edit is
/// never overwritten by an older checkpoint value.
final class SyncCheckpointCodec {
  const SyncCheckpointCodec(this.database, this.merge);

  static const int maxCompressedBytes = 8 * 1024 * 1024;
  static const int maxClearBytes = 64 * 1024 * 1024;

  final AppDatabase database;
  final SyncMergeEngine merge;

  Future<List<int>> encode({required int baseCursor}) async {
    if (baseCursor < 0) throw const FormatException('Invalid checkpoint cursor');

    final periods = await database.select(database.periods).get();
    final dayValues = await database.select(database.dayValues).get();
    final dayNotes = await database.select(database.dayNotes).get();
    final customLogs = await database.select(database.customLogs).get();
    final fieldClocks = await database.select(database.fieldClocks).get();
    final tombstones = await database.select(database.entityTombstones).get();

    final clocks = <String, Map<String, String>>{};
    for (final row in fieldClocks) {
      (clocks[row.entityId] ??= <String, String>{})[row.field] = row.hlc;
    }
    final deleted = {for (final row in tombstones) row.entityId: row.hlc};
    final operations = <_CheckpointOperation>[];

    for (final row in periods) {
      if (deleted.containsKey(row.id)) continue;
      final fields = clocks[row.id] ?? const <String, String>{};
      operations.add(
        _CheckpointOperation(
          entityId: row.id,
          entityType: 'period',
          field: 'start_day',
          hlc: fields['start_day'] ?? row.updatedHlc,
          kind: 'set',
          value: row.startDay,
        ),
      );
      final endClock = fields['end_day'];
      if (endClock != null) {
        operations.add(
          _CheckpointOperation(
            entityId: row.id,
            entityType: 'period',
            field: 'end_day',
            hlc: endClock,
            kind: row.endDay == null ? 'unset' : 'set',
            value: row.endDay,
          ),
        );
      } else if (row.endDay != null) {
        operations.add(
          _CheckpointOperation(
            entityId: row.id,
            entityType: 'period',
            field: 'end_day',
            hlc: row.updatedHlc,
            kind: 'set',
            value: row.endDay,
          ),
        );
      }
      final excludedClock = fields['exclude_from_prediction'];
      if (excludedClock != null) {
        operations.add(
          _CheckpointOperation(
            entityId: row.id,
            entityType: 'period',
            field: 'exclude_from_prediction',
            hlc: excludedClock,
            kind: 'set',
            value: row.excludeFromPrediction,
          ),
        );
      }
    }

    final dayValueByField = <String, DayValueEntry>{};
    for (final row in dayValues) {
      final entity = 'day:${row.day}';
      if (deleted.containsKey(entity)) continue;
      dayValueByField['$entity\u0000${row.key}'] = row;
      if (clocks[entity]?[row.key] == null) {
        operations.add(
          _CheckpointOperation(
            entityId: entity,
            entityType: 'day',
            field: row.key,
            hlc: row.updatedHlc,
            kind: 'set',
            value: <String, Object?>{'value': row.value, 'severity': row.severity},
          ),
        );
      }
    }
    final noteByEntity = <String, DayNoteEntry>{};
    for (final row in dayNotes) {
      final entity = 'day:${row.day}';
      if (deleted.containsKey(entity)) continue;
      noteByEntity[entity] = row;
      if (clocks[entity]?['note'] == null) {
        operations.add(
          _CheckpointOperation(
            entityId: entity,
            entityType: 'day',
            field: 'note',
            hlc: row.updatedHlc,
            kind: 'set',
            value: row.note,
          ),
        );
      }
    }
    for (final entry in clocks.entries) {
      final entity = entry.key;
      if (!entity.startsWith('day:') || deleted.containsKey(entity)) continue;
      for (final field in entry.value.entries) {
        if (field.key == 'note') {
          final note = noteByEntity[entity];
          operations.add(
            _CheckpointOperation(
              entityId: entity,
              entityType: 'day',
              field: 'note',
              hlc: field.value,
              kind: note == null ? 'unset' : 'set',
              value: note?.note,
            ),
          );
        } else {
          final value = dayValueByField['$entity\u0000${field.key}'];
          operations.add(
            _CheckpointOperation(
              entityId: entity,
              entityType: 'day',
              field: field.key,
              hlc: field.value,
              kind: value == null ? 'unset' : 'set',
              value: value == null
                  ? null
                  : <String, Object?>{'value': value.value, 'severity': value.severity},
            ),
          );
        }
      }
    }

    for (final row in customLogs) {
      if (deleted.containsKey(row.key)) continue;
      final fields = clocks[row.key] ?? const <String, String>{};
      operations.add(
        _CheckpointOperation(
          entityId: row.key,
          entityType: 'custom_log',
          field: 'label',
          hlc: fields['label'] ?? row.updatedHlc,
          kind: 'set',
          value: row.label,
        ),
      );
      operations.add(
        _CheckpointOperation(
          entityId: row.key,
          entityType: 'custom_log',
          field: 'archived',
          hlc: fields['archived'] ?? row.updatedHlc,
          kind: 'set',
          value: row.archived,
        ),
      );
      operations.add(
        _CheckpointOperation(
          entityId: row.key,
          entityType: 'custom_log',
          field: 'order_index',
          hlc: fields['order_index'] ?? row.updatedHlc,
          kind: 'set',
          value: row.orderIndex,
        ),
      );
    }

    for (final tombstone in tombstones) {
      operations.add(
        _CheckpointOperation(
          entityId: tombstone.entityId,
          entityType: _entityType(tombstone.entityId),
          field: '_entity',
          hlc: tombstone.hlc,
          kind: 'delete',
          value: null,
        ),
      );
    }

    operations.sort(_compareOperations);
    final json = jsonEncode(<String, Object>{
      'v': 1,
      'base_cursor': baseCursor,
      'operations': [
        for (var index = 0; index < operations.length; index++) operations[index].toJson(baseCursor, index),
      ],
    });
    final clear = utf8.encode(json);
    if (clear.length > maxClearBytes) throw const SyncCheckpointException('checkpoint_too_large');
    final compressed = gzip.encode(clear);
    if (compressed.length > maxCompressedBytes) throw const SyncCheckpointException('checkpoint_too_large');
    return compressed;
  }

  Future<int> apply({required List<int> compressed, required int expectedBaseCursor}) async {
    if (compressed.length > maxCompressedBytes) throw const SyncCheckpointException('checkpoint_too_large');
    late final List<int> clear;
    try {
      clear = gzip.decode(compressed);
    } catch (_) {
      throw const SyncCheckpointException('invalid_checkpoint_compression');
    }
    if (clear.length > maxClearBytes) throw const SyncCheckpointException('checkpoint_too_large');

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(clear));
    } catch (_) {
      throw const SyncCheckpointException('invalid_checkpoint');
    }
    if (decoded is! Map<String, dynamic> || decoded['v'] != 1 || decoded['base_cursor'] != expectedBaseCursor) {
      throw const SyncCheckpointException('invalid_checkpoint');
    }
    final rawOperations = decoded['operations'];
    if (rawOperations is! List) throw const SyncCheckpointException('invalid_checkpoint');

    var applied = 0;
    for (final raw in rawOperations) {
      if (raw is! Map<String, dynamic>) throw const SyncCheckpointException('invalid_checkpoint');
      final operation = _decodeOperation(raw);
      if (await merge.apply(operation)) applied += 1;
    }
    return applied;
  }

  SyncPlainOperation _decodeOperation(Map<String, dynamic> raw) {
    try {
      return SyncPlainOperation.decode(utf8.encode(jsonEncode(raw)));
    } catch (_) {
      throw const SyncCheckpointException('invalid_checkpoint_operation');
    }
  }

  static int _compareOperations(_CheckpointOperation left, _CheckpointOperation right) {
    final entity = left.entityId.compareTo(right.entityId);
    if (entity != 0) return entity;
    final priority = _fieldPriority(left).compareTo(_fieldPriority(right));
    if (priority != 0) return priority;
    return left.field.compareTo(right.field);
  }

  static int _fieldPriority(_CheckpointOperation operation) {
    if (operation.kind == 'delete') return 9;
    return switch (operation.entityType) {
      'period' => switch (operation.field) {
          'start_day' => 0,
          'end_day' => 1,
          'exclude_from_prediction' => 2,
          _ => 5,
        },
      'custom_log' => switch (operation.field) {
          'label' => 0,
          'archived' => 1,
          'order_index' => 2,
          _ => 5,
        },
      _ => 0,
    };
  }

  static String _entityType(String entityId) {
    if (entityId.startsWith('day:')) return 'day';
    if (entityId.startsWith('custom_')) return 'custom_log';
    return 'period';
  }
}

final class _CheckpointOperation {
  const _CheckpointOperation({
    required this.entityId,
    required this.entityType,
    required this.field,
    required this.hlc,
    required this.kind,
    required this.value,
  });

  final String entityId;
  final String entityType;
  final String field;
  final String hlc;
  final String kind;
  final Object? value;

  Map<String, Object?> toJson(int baseCursor, int index) => <String, Object?>{
        'v': 1,
        'op': 'checkpoint_${baseCursor}_$index',
        'entity': entityId,
        'entity_type': entityType,
        'field': field,
        'hlc': hlc,
        'kind': kind,
        'value': value,
      };
}

final class SyncCheckpointException implements Exception {
  const SyncCheckpointException(this.message);

  final String message;

  @override
  String toString() => 'SyncCheckpointException: $message';
}
