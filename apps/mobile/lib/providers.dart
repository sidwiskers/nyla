import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/notification_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/storage/secure_vault.dart';
import 'core/sync/hlc_service.dart';
import 'core/sync/sync_service.dart';
import 'data/database/app_database.dart';
import 'data/repositories/cycle_repository.dart';
import 'data/repositories/day_log_repository.dart';
import 'data/repositories/preferences_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) => throw StateError('Database has not been bootstrapped.'));
final deviceIdProvider = Provider<String>((ref) => throw StateError('Device identity has not been bootstrapped.'));
final secureVaultProvider = Provider<SecureVault>((ref) => const SecureVault());

final hlcServiceProvider = Provider<HlcService>(
  (ref) => HlcService(ref.watch(databaseProvider), ref.watch(deviceIdProvider)),
);
final cycleRepositoryProvider = Provider<CycleRepository>(
  (ref) => CycleRepository(ref.watch(databaseProvider), ref.watch(hlcServiceProvider)),
);
final dayLogRepositoryProvider = Provider<DayLogRepository>(
  (ref) => DayLogRepository(ref.watch(databaseProvider), ref.watch(hlcServiceProvider)),
);
final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    database: ref.watch(databaseProvider),
    deviceId: ref.watch(deviceIdProvider),
    secureVault: ref.watch(secureVaultProvider),
  ),
);
final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepository(ref.watch(databaseProvider)),
);
final notificationServiceProvider = FutureProvider<NotificationService>((ref) async {
  final service = NotificationService();
  await service.initialize();
  return service;
});
final notificationNavigationProvider = StreamProvider<String>((ref) async* {
  final service = await ref.watch(notificationServiceProvider.future);
  final initial = service.takeInitialLaunchRoute();
  if (initial != null) yield initial;
  yield* service.navigationRoutes;
});

final periodHistoryProvider = StreamProvider<List<PeriodEntry>>(
  (ref) => ref.watch(cycleRepositoryProvider).watchPeriods(),
);
final cyclePredictionProvider = StreamProvider<PredictionResult>(
  (ref) => ref.watch(cycleRepositoryProvider).watchPrediction(),
);
final dayValuesProvider = StreamProvider.family<List<DayValueEntry>, int>(
  (ref, day) => ref.watch(dayLogRepositoryProvider).watchDay(day),
);
final allDayValuesProvider = StreamProvider<List<DayValueEntry>>(
  (ref) => ref.watch(dayLogRepositoryProvider).watchAll(),
);
final symptomPatternsProvider = Provider<AsyncValue<List<SymptomPattern>>>((ref) {
  final periods = ref.watch(periodHistoryProvider);
  final values = ref.watch(allDayValuesProvider);
  if (periods.isLoading || values.isLoading) return const AsyncLoading();
  if (periods.hasError) return AsyncError(periods.error!, periods.stackTrace!);
  if (values.hasError) return AsyncError(values.error!, values.stackTrace!);

  const eligibleKeys = {
    'cramps',
    'headache',
    'bloating',
    'nausea',
    'dizziness',
    'back_pain',
    'breast_tenderness',
  };
  final observations = <BinaryObservation>[];
  for (final row in values.value ?? const <DayValueEntry>[]) {
    if (!eligibleKeys.contains(row.key) || row.severity == null) continue;
    observations.add(
      BinaryObservation(day: LocalDay(row.day), key: row.key, present: row.severity! > 0),
    );
  }
  final starts = (periods.value ?? const <PeriodEntry>[])
      .map((row) => LocalDay(row.startDay))
      .toList(growable: false);
  return AsyncData(
    const SymptomPatternAnalyzer().analyze(periodStarts: starts, observations: observations),
  );
});
final notificationConfigProvider = StreamProvider<NotificationConfig>(
  (ref) => ref.watch(preferencesRepositoryProvider).watchNotificationConfig(),
);
