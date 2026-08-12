import 'package:flutter/services.dart';

/// Small, deliberate tactile cues for meaningful Nyla interactions.
///
/// Selection feedback stays subtle. Confirmation is reserved for actions that
/// change or save something; destructive actions use a slightly firmer cue.
abstract final class NylaHaptics {
  static Future<void> select() => HapticFeedback.selectionClick();

  static Future<void> confirm() => HapticFeedback.lightImpact();

  static Future<void> destructive() => HapticFeedback.mediumImpact();
}
