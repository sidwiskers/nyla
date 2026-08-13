import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/core/theme/nyla_appearance.dart';
import 'package:nyla/core/theme/nyla_theme.dart';

void main() {
  group('Nyla appearance', () {
    test('round-trips every supported preference', () {
      for (final value in NylaAppearance.values) {
        expect(decodeNylaAppearance(encodeNylaAppearance(value)), value);
      }
    });

    test('unknown or absent values safely follow the system', () {
      expect(decodeNylaAppearance(null), NylaAppearance.system);
      expect(decodeNylaAppearance(''), NylaAppearance.system);
      expect(decodeNylaAppearance('future-mode'), NylaAppearance.system);
    });

    test('maps to Flutter theme modes exactly', () {
      expect(NylaAppearance.system.themeMode, ThemeMode.system);
      expect(NylaAppearance.light.themeMode, ThemeMode.light);
      expect(NylaAppearance.dark.themeMode, ThemeMode.dark);
    });
  });

  group('Nyla themes', () {
    test('publish complete light and dark semantic palettes', () {
      expect(NylaTheme.light.brightness, Brightness.light);
      expect(NylaTheme.dark.brightness, Brightness.dark);

      final light = NylaTheme.light.extension<NylaPalette>();
      final dark = NylaTheme.dark.extension<NylaPalette>();
      expect(light, isNotNull);
      expect(dark, isNotNull);
      expect(light!.canvas, isNot(dark!.canvas));
      expect(light.ink, isNot(dark.ink));
    });

    test('primary reading surfaces retain strong contrast', () {
      final light = NylaTheme.light.extension<NylaPalette>()!;
      final dark = NylaTheme.dark.extension<NylaPalette>()!;

      expect(_contrast(light.ink, light.canvas), greaterThanOrEqualTo(7));
      expect(_contrast(light.ink, light.surface), greaterThanOrEqualTo(7));
      expect(_contrast(dark.ink, dark.canvas), greaterThanOrEqualTo(7));
      expect(_contrast(dark.ink, dark.surface), greaterThanOrEqualTo(7));
      expect(_contrast(dark.mutedInk, dark.canvas), greaterThanOrEqualTo(4.5));
    });

    test('semantic palette participates in theme interpolation', () {
      final halfway = ThemeData.lerp(NylaTheme.light, NylaTheme.dark, 0.5);
      final palette = halfway.extension<NylaPalette>();
      expect(palette, isNotNull);
      expect(palette!.canvas, isNot(NylaPalette.light.canvas));
      expect(palette.canvas, isNot(NylaPalette.dark.canvas));
    });
  });
}

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}
