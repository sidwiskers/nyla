import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/nyla_theme.dart';
import 'navigation/router.dart';
import 'providers.dart';

class NylaApp extends ConsumerWidget {
  const NylaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(cyclePredictionProvider, (_, __) => unawaited(_refreshNotifications(ref)));
    ref.listen(notificationConfigProvider, (_, __) => unawaited(_refreshNotifications(ref)));

    return MaterialApp.router(
      title: 'Nyla',
      debugShowCheckedModeBanner: false,
      theme: NylaTheme.light,
      routerConfig: nylaRouter,
    );
  }

  Future<void> _refreshNotifications(WidgetRef ref) async {
    final config = ref.read(notificationConfigProvider).value;
    if (config == null) return;
    final prediction = ref.read(cyclePredictionProvider).value?.prediction;
    final service = await ref.read(notificationServiceProvider.future);
    await service.reschedule(config: config, prediction: prediction);
  }
}
