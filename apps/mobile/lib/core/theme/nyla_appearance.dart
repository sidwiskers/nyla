import 'package:flutter/material.dart';

enum NylaAppearance { system, light, dark }

extension NylaAppearanceThemeMode on NylaAppearance {
  ThemeMode get themeMode => switch (this) {
        NylaAppearance.system => ThemeMode.system,
        NylaAppearance.light => ThemeMode.light,
        NylaAppearance.dark => ThemeMode.dark,
      };

  String get label => switch (this) {
        NylaAppearance.system => 'System',
        NylaAppearance.light => 'Light',
        NylaAppearance.dark => 'Dark',
      };
}

NylaAppearance decodeNylaAppearance(String? value) => switch (value) {
      'light' => NylaAppearance.light,
      'dark' => NylaAppearance.dark,
      _ => NylaAppearance.system,
    };

String encodeNylaAppearance(NylaAppearance value) => value.name;
