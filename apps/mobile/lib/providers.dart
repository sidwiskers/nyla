import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/notification_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/security/app_lock_service.dart';
import 'core/storage/secure_vault.dart';
import 'core/sync/hlc_service.dart';
import 'core/sync/sync_coordinator.dart';
import 'core/sync/sync_service.dart';
import 'core/theme/nyla_appearance.dart';
import 'data/database/app_database.dart';
import 'data/repositories/custom_log_repository.dart';
import 'data/repositories/cycle_pet_memory_repository.dart';
import 'data/repositories/cycle_repository.dart';
import 'data/repositories/day_log_repository.dart';
import 'data/repositories/preferences_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) => throw StateError('Database has not been bootstrapped.'));
final deviceIdProvider = Provider<String>((ref) => throw StateError('Device identity has not been bootstrapped.'));
final secureVaultProvider = Provider<SecureVault>((ref) => const SecureVault());
final initialAppearanceProvider = Provider<NylaAppearance>((ref) => NylaAppearance.system);
final appLockServiceProvider = Provider<AppLockService>(
  (ref) => AppLockService(vault: ref.watch(secureVaultProvider)),
);
final resetLocalDataProvider = Provider<Future<void> Function()>(
  (ref) => throw StateError('Local reset has not been bootstrapped.'),
);

final hlcServiceProvider = Provider<HlcService>(
  (ref) => HlcService(ref.watch(databaseProvider), ref.watch(deviceIdProvider)),
);
final cycleRepositoryProvider = Provider<CycleRepository>(
  (ref) => CycleRepository(ref.watch(databaseProvider), ref.watch(hlcServiceProvider)),
);
final dayLogRepositoryProvider = Provider<DayLogRepository>(
  (ref) => DayLogRepository(ref.watch(databaseProvider), ref.watch(hlcServiceProvider)),
);
final customLogRepositoryProvider = Provider<CustomLogRepository>(
  (ref) => CustomLogRepository(ref.watch(databaseProvider), ref.watch(hlcServiceProvider)),
);
final cyclePetMemoryRepositoryProvider = Provider<CyclePetMemoryRepository>(
  (ref) => CyclePetMemoryRepository(ref.watch(databaseProvider)),
);
final cyclePetMemoryProvider = StreamProvider<CyclePetMemory>(
  (ref) => ref.watch(cyclePetMemoryRepositoryProvider).watch(),
);
final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    database: ref.watch(databaseProvider),
    deviceId: ref.watch(deviceIdProvider),
    secureVault: ref.watch(secureVaultProvider),
  ),
);
final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final coordinator = SyncCoordinator(
    service: ref.watch(syncServiceProvider),
    database: ref.watch(databaseProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
final pendingSyncMutationCountProvider = StreamProvider<int>(
  (ref) => ref.watch(databaseProvider).watchPendingMutationCount(),
);
final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepository(ref.watch(databaseProvider)),
);
final appearanceProvider = StreamProvider<NylaAppearance>(
  (ref) => ref.watch(preferencesRepositoryProvider).watchAppearance(),
);
final effectiveAppearanceProvider = Provider<NylaAppearance>((ref) {
  final streamed = ref.watch(appearanceProvider);
  final current = streamed.value;
  if (current != null) return current;
  return ref.watch(initialAppearanceProvider);
});
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

/// Compatibility provider for the original four-window companion model. New
/// product surfaces should prefer [cyclePhaseContextProvider].
final cycleExperienceProvider = Provider.family<AsyncValue<CycleExperience?>, int>(
  (ref, epochDay) {
    final periods = ref.watch(periodHistoryProvider);
    final prediction = ref.watch(cyclePredictionProvider);
    if (periods.isLoading) return const AsyncLoading();
    if (periods.hasError) return AsyncError(periods.error!, periods.stackTrace!);

    final records = _periodRecords(periods.value ?? const <PeriodEntry>[]);
    return AsyncData(
      const CycleExperienceEngine().describe(
        today: LocalDay(epochDay),
        records: records,
        prediction: prediction.value?.prediction,
      ),
    );
  },
);

final cyclePhaseContextProvider = Provider.family<AsyncValue<CyclePhaseContext?>, int>(
  (ref, epochDay) {
    final periods = ref.watch(periodHistoryProvider);
    final prediction = ref.watch(cyclePredictionProvider);
    final values = ref.watch(dayValuesProvider(epochDay));
    if (periods.isLoading) return const AsyncLoading();
    if (periods.hasError) return AsyncError(periods.error!, periods.stackTrace!);

    // Today's flow/mucus observations can strengthen the interpretation, but
    // they are optional evidence. Do not make the phase card wait or disappear
    // while the local day stream is still opening (or if that optional stream
    // fails independently).
    final rows = values.value ?? const <DayValueEntry>[];
    return AsyncData(
      const CyclePhaseEngine().describe(
        today: LocalDay(epochDay),
        records: _periodRecords(periods.value ?? const <PeriodEntry>[]),
        prediction: prediction.value?.prediction,
        signals: _daySignals(rows),
      ),
    );
  },
);

final customLogsProvider = StreamProvider<List<CustomLogEntry>>(
  (ref) => ref.watch(customLogRepositoryProvider).watchAll(),
);
final symptomPatternsProvider = Provider<AsyncValue<List<SymptomPattern>>>((ref) {
  final periods = ref.watch(periodHistoryProvider);
  final values = ref.watch(allDayValuesProvider);
  if (periods.isLoading || values.isLoading) return const AsyncLoading();
  if (periods.hasError) return AsyncError(periods.error!, periods.stackTrace!);
  if (values.hasError) return AsyncError(values.error!, values.stackTrace!);

  final starts = (periods.value ?? const <PeriodEntry>[])
      .map((row) => LocalDay(row.startDay))
      .toList(growable: false);
  return AsyncData(
    const SymptomPatternAnalyzer().analyze(
      periodStarts: starts,
      observations: _patternObservations(values.value ?? const <DayValueEntry>[]),
    ),
  );
});
final notificationConfigProvider = StreamProvider<NotificationConfig>(
  (ref) => ref.watch(preferencesRepositoryProvider).watchNotificationConfig(),
);

List<PeriodRecord> _periodRecords(List<PeriodEntry> rows) => rows
    .map(
      (row) => PeriodRecord(
        start: LocalDay(row.startDay),
        end: row.endDay == null ? null : LocalDay(row.endDay!),
        excludeFromPrediction: row.excludeFromPrediction,
      ),
    )
    .toList(growable: false);

CycleDaySignals _daySignals(List<DayValueEntry> rows) {
  DayValueEntry? flow;
  DayValueEntry? discharge;
  for (final row in rows) {
    if (row.key == 'flow') flow = row;
    if (row.key == 'discharge') discharge = row;
  }

  final bleeding = switch (flow?.value) {
    'light' || 'medium' || 'heavy' => true,
    'none' => false,
    _ => null,
  };
  final mucus = switch (discharge?.value) {
    'watery' || 'stretchy' => CervicalMucusSignal.estrogenic,
    'creamy' => CervicalMucusSignal.creamy,
    'dry' || 'sticky' => CervicalMucusSignal.dryOrSticky,
    _ => CervicalMucusSignal.unknown,
  };
  return CycleDaySignals(bleeding: bleeding, cervicalMucus: mucus);
}

List<BinaryObservation> _patternObservations(List<DayValueEntry> rows) {
  const severityKeys = {
    'cramps',
    'headache',
    'bloating',
    'nausea',
    'dizziness',
    'back_pain',
    'breast_tenderness',
  };
  final observations = <BinaryObservation>[];
  final moodByDay = <int, Set<String>>{};
  final skinByDay = <int, Set<String>>{};

  void add(DayValueEntry row, String key, bool present) {
    observations.add(
      BinaryObservation(day: LocalDay(row.day), key: key, present: present),
    );
  }

  for (final row in rows) {
    if (severityKeys.contains(row.key) && row.severity != null) {
      add(row, row.key, row.severity! > 0);
      continue;
    }

    switch (row.key) {
      case 'energy':
        add(row, 'energy.low', row.value == 'very_low' || row.value == 'low');
        add(row, 'energy.high', row.value == 'high' || row.value == 'very_high');
        continue;
      case 'sleep':
        add(row, 'sleep.poor', row.value == 'very_poor' || row.value == 'poor');
        continue;
      case 'appetite':
        add(row, 'appetite.higher', row.value == 'higher' || row.value == 'cravings');
        add(row, 'appetite.cravings', row.value == 'cravings');
        continue;
      case 'discharge':
        add(row, 'discharge.estrogenic', row.value == 'watery' || row.value == 'stretchy');
        add(row, 'discharge.dry', row.value == 'dry' || row.value == 'sticky');
        continue;
      case 'digestion':
        add(row, 'digestion.constipation', row.value == 'constipation');
        add(row, 'digestion.loose_stool', row.value == 'loose_stool');
        add(row, 'digestion.gassy', row.value == 'gassy');
        continue;
      case 'flow':
        add(row, 'flow.heavy', row.value == 'heavy');
        continue;
      default:
        if (row.key.startsWith('mood.')) {
          moodByDay.putIfAbsent(row.day, () => <String>{}).add(row.key.substring(5));
        } else if (row.key.startsWith('skin.')) {
          skinByDay.putIfAbsent(row.day, () => <String>{}).add(row.key.substring(5));
        }
    }
  }

  // A multi-choice group only provides explicit absences on days when at least
  // one choice was saved. Completely unlogged/cleared days remain unknown.
  const moodFeatures = ['sensitive', 'low', 'irritable', 'anxious', 'overwhelmed', 'happy'];
  for (final entry in moodByDay.entries) {
    for (final feature in moodFeatures) {
      observations.add(
        BinaryObservation(
          day: LocalDay(entry.key),
          key: 'mood.$feature',
          present: entry.value.contains(feature),
        ),
      );
    }
  }
  const skinFeatures = ['breakout', 'oily', 'dry', 'sensitive'];
  for (final entry in skinByDay.entries) {
    for (final feature in skinFeatures) {
      observations.add(
        BinaryObservation(
          day: LocalDay(entry.key),
          key: 'skin.$feature',
          present: entry.value.contains(feature),
        ),
      );
    }
  }

  return observations;
}
