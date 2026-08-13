import 'dart:async';

import 'package:flutter/services.dart';

/// Small, deliberate tactile cues for meaningful Nyla interactions.
///
/// Haptics are best-effort and never sit on the UI critical path. A device that
/// delays or does not support tactile feedback must not delay the interaction.
abstract final class NylaHaptics {
  static Future<void> select() {
    unawaited(HapticFeedback.selectionClick());
    return Future<void>.value();
  }

  static Future<void> confirm() {
    unawaited(HapticFeedback.lightImpact());
    return Future<void>.value();
  }

  static Future<void> destructive() {
    unawaited(HapticFeedback.mediumImpact());
    return Future<void>.value();
  }
}
