import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/notification_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/storage/secure_vault.dart';
import 'core/sync/hlc_service.dart';
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
final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepository(ref.watch(databaseProvider)),
);
final notificationServiceProvider = FutureProvider<NotificationService>((ref) async {
  final service = NotificationService();
  await service.initialize();
  return service;
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
final notificationConfigProvider = StreamProvider<NotificationConfig>(
  (ref) => ref.watch(preferencesRepositoryProvider).watchNotificationConfig(),
);
