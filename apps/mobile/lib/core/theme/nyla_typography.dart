import 'package:flutter/material.dart';

/// Nyla's signature type system.
///
/// Onest is the everyday voice: warm, clear and compact enough for health UI.
/// Newsreader is the emotional/editorial voice and stays intentionally rare so
/// buttons, logs, dates and factual explanations remain effortless to scan.
abstract final class NylaTypography {
  static const uiFamily = 'sans-serif-rounded';
  static const displayFamily = 'NylaDisplay';

  static const uiFallback = <String>['sans-serif', 'Roboto'];
  static const displayFallback = <String>['serif', 'Georgia'];

  /// Editorial hierarchy for page titles and a few deliberate hero moments.
  static TextStyle display(
    TextStyle? base, {
    double? size,
    double? height,
    double? letterSpacing,
    double? opticalSize,
    FontWeight? weight,
    Color? color,
  }) {
    final resolvedSize = size ?? base?.fontSize ?? 24;
    final resolvedOpticalSize =
        opticalSize ?? resolvedSize.clamp(16.0, 72.0).toDouble();
    return (base ?? const TextStyle()).copyWith(
      fontFamily: displayFamily,
      fontFamilyFallback: displayFallback,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: weight ?? FontWeight.w600,
      color: color,
      fontVariations: <FontVariation>[
        FontVariation('opsz', resolvedOpticalSize),
      ],
    );
  }

  /// A softer display treatment for Nyla's companion voice.
  ///
  /// It is deliberately calmer than [display]: smaller optical size, slightly
  /// looser tracking and medium weight keep longer caring sentences intimate
  /// rather than looking like marketing copy.
  static TextStyle companion(
    TextStyle? base, {
    double? size,
    double? height,
    double? letterSpacing,
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) {
    final resolvedSize = size ?? base?.fontSize ?? 24;
    return display(
      base,
      size: size,
      height: height,
      letterSpacing: letterSpacing ?? -0.12,
      opticalSize: resolvedSize.clamp(20.0, 40.0).toDouble(),
      weight: weight,
      color: color,
    );
  }
}
