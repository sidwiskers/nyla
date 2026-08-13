import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';

/// Nyla uses a quiet humanist sans for interface reading and a restrained
/// editorial face only where hierarchy benefits from it.
abstract final class NylaTypography {
  static const uiFamily = 'sans-serif-rounded';
  static const displayFamily = 'NylaDisplay';

  static const uiFallback = <String>['sans-serif', 'Roboto'];
  static const displayFallback = <String>['serif', 'Georgia'];

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
    return (base ?? const TextStyle()).copyWith(
      fontFamily: displayFamily,
      fontFamilyFallback: displayFallback,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: weight ?? FontWeight.w600,
      color: color,
      fontVariations: <FontVariation>[
        FontVariation('opsz', opticalSize ?? resolvedSize.clamp(16, 72)),
      ],
    );
  }
}
